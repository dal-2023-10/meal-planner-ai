import os
import json
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from dotenv import load_dotenv
from google import generativeai as genai
from google.generativeai import GenerationConfig
from PIL import Image
from io import BytesIO
import firebase_admin
from firebase_admin import credentials, storage
import pandas as pd
import pandas_gbq
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import base64

# ─────────────────────────────────────────────
# 1. Gemini生成設定
# ─────────────────────────────────────────────
@dataclass
class GeminiOptions:
    temperature: float = 0.7
    top_p: float = 0.8
    top_k: int = 40
    candidate_count: int = 1
    max_output_tokens: int = 40000
    stop_sequences: Optional[List[str]] = None
    presence_penalty: float = 0.0
    frequency_penalty: float = 0.0
    system_instruction: Optional[str] = None
    safety_settings: Optional[List[Dict[str, Any]]] = None
    tools: Optional[List[Dict[str, Any]]] = None
    response_mime_type: Optional[str] = "application/json"
    response_schema: Optional[Dict[str, Any]] = None

    def to_generation_config(self) -> GenerationConfig:
        return GenerationConfig(
            temperature        = self.temperature,
            top_p              = self.top_p,
            top_k              = self.top_k,
            candidate_count    = self.candidate_count,
            max_output_tokens  = self.max_output_tokens,
            stop_sequences     = self.stop_sequences or None,
            presence_penalty   = self.presence_penalty or None,
            frequency_penalty  = self.frequency_penalty or None,
            response_mime_type = self.response_mime_type or None,
            response_schema    = self.response_schema or None,
        )

# ─────────────────────────────────────────────
# 2. チラシ画像→商品リスト（Gemini+Firebase）
# ─────────────────────────────────────────────
class ImageProcessor:
    def __init__(
        self,
        api_key_env: str = "GOOGLE_API_KEY",
        model_name: str = "models/gemini-2.5-flash-preview-05-20",
        options: GeminiOptions = GeminiOptions(),
        firebase_cred_path: str = None,
        firebase_bucket: str = None
    ):
        load_dotenv()
        api_key = os.getenv(api_key_env)
        if not api_key:
            raise ValueError(f"{api_key_env} が設定されていません")
        genai.configure(api_key=api_key)

        # Firebase認証
        self.firebase_cred_path = firebase_cred_path or os.getenv('FIREBASE_CRED_PATH')
        self.firebase_bucket = firebase_bucket or os.getenv('FIREBASE_STORAGE_BUCKET')
        if not self.firebase_cred_path or not self.firebase_bucket:
            raise ValueError("Firebase認証情報が設定されていません")
        if not firebase_admin._apps:
            cred = credentials.Certificate(self.firebase_cred_path)
            firebase_admin.initialize_app(cred, {'storageBucket': self.firebase_bucket})
        self.bucket = storage.bucket()

        self.options = options
        # モデル
        self.model = genai.GenerativeModel(
            model_name=model_name,
            generation_config=options.to_generation_config(),
            safety_settings=[
                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"},
            ],
        )
        self.prompt = """
画像から**料理に使える食品に関する商品情報のみ**を抽出してください。チラシに記載されている商品情報を以下の形式で出力してください：

[
    {
        "商品": "商品名",
        "数量": "個数",
        "値段": "金額",
        "特売日": "日付"
    },
    ...
]

注意：
- 商品名、数量、値段、特売日の情報のみを抽出してください
- 上記のJSON形式以外の文章は含めないでください
"""

    def get_latest_image(self, prefix: str = "") -> Optional[Image.Image]:
        blobs = list(self.bucket.list_blobs(prefix=prefix))
        if not blobs:
            return None
        # 更新日時でソートして最新を選ぶ
        blobs.sort(key=lambda b: b.updated, reverse=True)
        for blob in blobs:
            if blob.name.lower().endswith(('.jpg', '.jpeg', '.png', '.gif')):
                image_bytes = blob.download_as_bytes()
                return Image.open(BytesIO(image_bytes)).convert("RGB")
        return None

    def pil_image_to_gemini_part(self, image: Image.Image) -> dict:
        buf = BytesIO()
        image.save(buf, format='JPEG')
        byte_data = buf.getvalue()
        return {"mime_type": "image/jpeg", "data": byte_data}

    def recognize_flyer(self) -> list[dict]:
        image = self.get_latest_image()
        if image is None:
            raise Exception("画像が取得できませんでした（Firebaseストレージを確認）")
        image_part = self.pil_image_to_gemini_part(image)
        response = self.model.generate_content(
            contents=[image_part, self.prompt],
            generation_config=self.options.to_generation_config()
        )
        text = getattr(response, "text", None)
        if not text:
            raise Exception("Gemini APIから応答がありません")
        # 不要なテキストを除去し、JSONパース
        json_text = text
        if "```json" in json_text:
            json_text = json_text.split("```json")[1]
        if "```" in json_text:
            json_text = json_text.split("```")[0]
        json_text = json_text.strip()
        try:
            items = json.loads(json_text)
        except Exception as e:
            raise Exception(f"JSON parse error: {str(e)}\ntext: {json_text}")
        for item in items:
            for key in ["商品", "数量", "値段", "特売日"]:
                if key not in item:
                    raise Exception(f"必須キー({key})がJSONにありません")
        return items

# ─────────────────────────────────────────────
# 3. Geminiメニュー生成関連
# ─────────────────────────────────────────────
SYSTEM_PROMPT = """
あなたは「パーソナル栄養プランナーAI」です。
ユーザーの指定する条件に従って、献立をJSON形式で出力してください。

出力例：
{
    "title": "メニュー名",
    "cuisine": "和食",
    "total_time_min": 25,
    "nutrition": {
        "kcal": 560,
        "protein_g": 30,
        "fat_g": 20,
        "carb_g": 45,
        "salt_g": 2.5
    },
    "instructions": [
        "手順1",
        "手順2"
    ],
    "ingredients": [
        {
            "name": "鶏胸肉",
            "quantity": "200",
            "unit": "g"
        },
        {
            "name": "塩麹",
            "quantity": "大さじ1.5",
            "unit": ""
        },
        {
            "name": "ほうれん草",
            "quantity": "100",
            "unit": "g"
        }
    ]
}

注意事項：
- nutritionの値は必ず数値型で出力
- ingredientsは必ず配列で出力
- total_time_minは整数値で出力
"""

def setup_environment() -> None:
    load_dotenv()
    for v in ['GOOGLE_API_KEY', 'GOOGLE_CLOUD_PROJECT', 'BIGQUERY_DATASET']:
        if not os.getenv(v):
            raise ValueError(f"{v} が設定されていません")

def create_processor() -> 'GeminiProcessor':
    opts = GeminiOptions(
        temperature=float(os.getenv('GEMINI_TEMPERATURE', '0.3')),
        max_output_tokens=int(os.getenv('GEMINI_MAX_OUTPUT_TOKENS', '10000')),
        tools=None
    )
    return GeminiProcessor(options=opts)

class GeminiProcessor:
    def __init__(
        self,
        api_key_env: str = "GOOGLE_API_KEY",
        model_name: str = "models/gemini-2.5-flash-preview-05-20",
        options: GeminiOptions = GeminiOptions(),
        project_id: Optional[str] = None,
    ):
        load_dotenv()
        api_key = os.getenv(api_key_env)
        if not api_key:
            raise ValueError(f"{api_key_env} が設定されていません")
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel(
            model_name=model_name,
            generation_config=options.to_generation_config(),
            safety_settings=options.safety_settings,
            system_instruction=options.system_instruction,
            tools=options.tools,
        )
        self.options = options
        self.project_id = project_id

    def process_dataframe(
        self,
        df: pd.DataFrame,
        system_prompt_col: str = "system_prompt",
        human_prompt_col: str = "human_prompt",
        output_col: str = "output",
    ) -> pd.DataFrame:
        if not {system_prompt_col, human_prompt_col}.issubset(df.columns):
            raise ValueError("必要なカラムがありません")
        res = df.copy()
        res[output_col] = None
        for idx, row in res.iterrows():
            try:
                chat = self.model.start_chat(history=[])
                if pd.notna(row[system_prompt_col]):
                    chat.send_message(row[system_prompt_col])
                reply = chat.send_message(str(row[human_prompt_col]))
                res.at[idx, output_col] = reply.text
            except Exception as e:
                res.at[idx, output_col] = json.dumps({"error": str(e)})
        return res

def load_bigquery_data() -> pd.DataFrame:
    project_name = os.getenv('GOOGLE_CLOUD_PROJECT')
    dataset_name = os.getenv('BIGQUERY_DATASET')
    demo_table = f'{project_name}.{dataset_name}.Demo_Remake'
    demo_query = f"""
        SELECT *
        FROM `{demo_table}`
        WHERE created_at = (
            SELECT MAX(created_at)
            FROM `{demo_table}`
        )
    """
    demo = pandas_gbq.read_gbq(
        demo_query.replace('\n', ' ').replace('\u3000', ''),
        project_id=project_name,
        dialect='standard'
    )
    return demo

def generate_menu(processor: GeminiProcessor, human_prompt: str) -> pd.DataFrame:
    data = {
        "human_prompt": [human_prompt],
        "system_prompt": [SYSTEM_PROMPT]
    }
    df = pd.DataFrame(data)
    result_df = processor.process_dataframe(
        df,
        human_prompt_col="human_prompt",
        system_prompt_col="system_prompt",
        output_col="output"
    )
    return result_df

def parse_menu_json(raw_json: str | dict) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    data = raw_json if isinstance(raw_json, dict) else json.loads(raw_json)
    header_df = pd.DataFrame([{
        "title":           data["title"],
        "cuisine":         data["cuisine"],
        "total_time_min":  data["total_time_min"],
    }])
    nutrition_df = pd.DataFrame([data["nutrition"]])
    ingredients_df = pd.DataFrame(data["ingredients"])
    instructions_df = pd.DataFrame({
        "step": range(1, len(data["instructions"])+1),
        "text": data["instructions"]
    })
    return header_df, nutrition_df, ingredients_df, instructions_df

def generate_food_image(recipe_title: str, ingredient_list: list[str]) -> str:
    GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
    genai.configure(api_key=GOOGLE_API_KEY)
    ingredient_text = ", ".join(ingredient_list)
    prompt = (
        f"High quality food photograph, {recipe_title}, ingredients: {ingredient_text}, beautiful plating, Japanese cuisine, "
        "shot from above, natural lighting, plain background, no watermark, no text, no logo. "
        "Respond ONLY with a PNG image as base64, NO description, NO explanation, NO text."
    )
    model = genai.GenerativeModel(model_name="gemini-2.0-flash-preview-image-generation")
    response = model.generate_content(
        prompt,
        generation_config={
            "response_modalities": ["TEXT", "IMAGE"]
        }
    )
    image_base64 = None
    for part in response.candidates[0].content.parts:
        if isinstance(part, dict):
            inline_data = part.get("inline_data")
            if inline_data and isinstance(inline_data, dict) and "data" in inline_data:
                image_bytes = inline_data["data"]
                if isinstance(image_bytes, bytes):
                    image_base64 = base64.b64encode(image_bytes).decode('utf-8')
                else:
                    image_base64 = image_bytes
                break
        elif hasattr(part, "inline_data") and getattr(part, "inline_data") is not None:
            image_bytes = part.inline_data.data
            if isinstance(image_bytes, bytes):
                image_base64 = base64.b64encode(image_bytes).decode('utf-8')
            else:
                image_base64 = image_bytes
            break
    if not image_base64:
        raise Exception("No image found in the response.")
    return image_base64

# ─────────────────────────────────────────────
# 4. FastAPI サーバ
# ─────────────────────────────────────────────
app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

setup_environment()
processor = create_processor()

class DummyRequest(BaseModel):
    pass

@app.post("/generate_menu_from_flyer")
def generate_menu_from_flyer(_: DummyRequest):
    try:
        # 1. チラシから商品抽出
        flyer_processor = ImageProcessor()
        product_list = flyer_processor.recognize_flyer()
        product_names = [item['商品'] for item in product_list if '商品' in item]
        product_block = "\n".join(f"- {name}" for name in product_names)

        # 2. デモグラ取得
        demo = load_bigquery_data()
        num_people = len(demo)
        people_desc = []
        for _, row in demo.iterrows():
            gender = row.get("gender", "")
            age = row.get("age", "")
            dstyle = row.get("dietary_style", "")
            feeling = row.get("feeling", "")
            cooking_time = row.get("cooking_time", "")
            # 1行ずつ情報をまとめる
            line = f"・性別: {gender}、年齢: {age}"
            if pd.notna(dstyle) and dstyle:
                line += f"、食事スタイル: {dstyle}"
            if pd.notna(feeling) and feeling:
                line += f"、気分・要望: {feeling}"
            if pd.notna(cooking_time) and cooking_time:
                line += f"、希望調理時間: {cooking_time}"
            people_desc.append(line)
        people_block = "\n".join(people_desc)

        # 3. プロンプト作成
        human_prompt = f"""
        以下の条件で {num_people}人分のメニューを生成してください：

        ## 対象者の情報
        {people_block}

        ## 近くのスーパーの商品リスト
        {product_block}

        ## その他の条件
        - 栄養バランスを考慮すること
        - 可能な範囲で近くのスーパーの商品リストを使用してレシピを作ること
        """

        # 4. Gemini呼び出し
        result_df = generate_menu(processor, human_prompt)
        header_df, nutrition_df, ingredients_df, instructions_df = parse_menu_json(result_df.loc[0, "output"])

        # 5. 画像生成
        ingredient_names = [row["name"] for _, row in ingredients_df.iterrows()]
        recipe_title = header_df.iloc[0]["title"]
        image_base64 = generate_food_image(recipe_title, ingredient_names)

        # 6. 返却
        return {
            "header": header_df.to_dict(orient="records"),
            "nutrition": nutrition_df.to_dict(orient="records"),
            "ingredients": ingredients_df.to_dict(orient="records"),
            "instructions": instructions_df.to_dict(orient="records"),
            "image_base64": image_base64,
            "demo": demo.to_dict(orient="records"),
            "flyer_products": product_list
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
