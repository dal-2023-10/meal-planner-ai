"""
メニュージェネレーター（単一ファイル版）
Gemini APIを使用して、ユーザーの条件に合わせた料理メニューを自動生成するツリプトです。
"""

import os
import sys
import json
import pandas as pd
import pandas_gbq 
from datetime import datetime, timezone
from dotenv import load_dotenv
# from shared.gemini_processor import GeminiOptions, GeminiProcessor


import os, json, pandas as pd
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, asdict
from dotenv import load_dotenv
from google import generativeai as genai        
from google.generativeai import GenerationConfig  
import logging

# ロギングの設定
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────
# 1. モデル向けパラメータを "全部入り" で保持する dataclass
# ─────────────────────────────────────────────
@dataclass
class GeminiOptions:
    # ── GenerationConfig パラメータ ─────────────────────────
    temperature: float = 0.7
    top_p: float = 0.8
    top_k: int = 40
    candidate_count: int = 1
    max_output_tokens: int = 2048
    stop_sequences: Optional[List[str]] = None
    presence_penalty: float = 0.0
    frequency_penalty: float = 0.0

    # ── 追加オプション ──────────────────────────────────────
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
# 2. メインクラス
# ─────────────────────────────────────────────
class GeminiProcessor:
    def __init__(
        self,
        api_key_env: str = "GOOGLE_API_KEY",
        # model_name: str = "models/gemini-2.0-flash",
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

    # ────────────────────────
    # DataFrame → Gemini 呼び出し
    # ────────────────────────
    def process_dataframe(
        self,
        df: pd.DataFrame,
        system_prompt_col: str = "systemprompt",
        human_prompt_col: str = "humanprompt",
        output_col: str = "output",
    ) -> pd.DataFrame:

        if not {system_prompt_col, human_prompt_col}.issubset(df.columns):
            raise ValueError("必要なカラムがありません")

        res = df.copy()
        res[output_col] = None

        for idx, row in res.iterrows():
            try:
                chat = self.model.start_chat(history=[])
                # 行に専用 system-prompt があれば上書き
                if pd.notna(row[system_prompt_col]):
                    chat.send_message(row[system_prompt_col])
                reply = chat.send_message(str(row[human_prompt_col]))
                res.at[idx, output_col] = reply.text
            except Exception as e:
                res.at[idx, output_col] = json.dumps({"error": str(e)})
        return res


# スキーマ定義
RESPONSE_SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "MealPlan",
    "type": "object",
    "properties": {
        "title": { "type": "string" },
        "cuisine": { "type": "string" },
        "total_time_min": {
            "type": "integer",
            "minimum": 0
        },
        "nutrition": { "$ref": "#/$defs/nutrition" },
        "ingredients": {
            "type": "array",
            "items": { "$ref": "#/$defs/ingredient" }
        },
        "instructions": {
            "type": "array",
            "items": { "type": "string" },
            "minItems": 1
        },
        "notes": { "type": "string" }
    },
    "required": [
        "title",
        "cuisine",
        "total_time_min",
        "nutrition",
        "ingredients",
        "instructions"
    ],
    "additionalProperties": False,

    "$defs": {
        "nutrition": {
            "type": "object",
            "properties": {
                "kcal":       { "type": "number", "minimum": 0 },
                "protein_g":  { "type": "number", "minimum": 0 },
                "fat_g":      { "type": "number", "minimum": 0 },
                "carb_g":     { "type": "number", "minimum": 0 },
                "salt_g":     { "type": "number", "minimum": 0 }
            },
            "required": ["kcal", "protein_g", "fat_g", "carb_g", "salt_g"],
            "additionalProperties": False
        },

        "ingredient": {
            "type": "object",
            "properties": {
                "name":     { "type": "string" },
                "quantity": { "type": "string" },
                "unit":     { "type": "string" }
            },
            "required": ["name", "quantity", "unit"],
            "additionalProperties": False
        }
    }
}

# システムプロンプト
SYSTEM_PROMPT = """
あなたは「パーソナル栄養プランナーAI」です。
以下の条件に従って、献立をJSON形式で出力してください。

【役割】
- 目的: ユーザーの食事目標を最小の手間で達成する献立を作成する。

【必須条件】
1. 栄養基準を満たす（後述のnutrition_targets）
2. 禁止食材／アレルゲンを含まない（後述のfood_restrictions）
3. 在庫優先: 冷蔵庫在庫（後述のinventory）を優先的に消費
4. 調理時間と調理器具制約（後述のtime_limit, equipment）を守る
5. 指定ジャンル（後述のcuisine_genres）を守る

【出力形式】
必ず以下のJSON形式で出力してください（コードブロックは不要）：
{{
    "title": "メニュー名",
    "cuisine": "和食",
    "total_time_min": 25,  // 整数値で分単位
    "nutrition": {{
        "kcal": 560,       // 数値（kcal）
        "protein_g": 30,   // 数値（g）
        "fat_g": 20,       // 数値（g）
        "carb_g": 45,      // 数値（g）
        "salt_g": 2.5      // 数値（g）
    }},
    "instructions": [
        "手順1",
        "手順2"
    ],
    "ingredients": [
        {{
            "name": "鶏胸肉",
            "quantity": "200",
            "unit": "g"
        }},
        {{
            "name": "塩麹",
            "quantity": "大さじ1.5",
            "unit": ""
        }},
        {{
            "name": "ほうれん草",
            "quantity": "100",
            "unit": "g"
        }}
    ]
}}

注意事項：
- nutritionの値は必ず数値型で出力（単位は含めない）
- ingredientsは必ずオブジェクトの配列として出力
- total_time_minは必ず整数値で出力
"""

def setup_environment() -> None:
    """
    環境変数の設定とチェック
    """
    # .envファイルの読み込み
    load_dotenv()

    # 必須環境変数のチェック
    required_vars = [
        'GOOGLE_API_KEY',
        'GOOGLE_CLOUD_PROJECT',
        'BIGQUERY_DATASET',
    ]
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    if missing_vars:
        raise ValueError(f"以下の環境変数が設定されていません: {', '.join(missing_vars)}")

def create_processor() -> GeminiProcessor:
    """
    GeminiProcessorのインスタンスを作成

    Returns
    -------
    GeminiProcessor
        設定済みのGeminiProcessorインスタンス
    """
    schema_tool = {"type": "response_schema", "schema": RESPONSE_SCHEMA}

    opts = GeminiOptions(
        temperature=float(os.getenv('GEMINI_TEMPERATURE', '0.3')),
        max_output_tokens=int(os.getenv('GEMINI_MAX_OUTPUT_TOKENS', '10000')),
        tools=None
        # tools=[schema_tool]  # スキーマツールを設定
    )

    return GeminiProcessor(options=opts)

def load_bigquery_data() -> pd.DataFrame:
    """
    BigQueryからデータを読み込む

    Returns
    -------
    tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]
        (demo, fridge_items, recipe_ingredients)のタプル
    """
    project_name = os.getenv('GOOGLE_CLOUD_PROJECT')
    dataset_name = os.getenv('BIGQUERY_DATASET')

    # テーブル名の設定
    demo_table = f'{project_name}.{dataset_name}.demo'
    # fridge_items_table = f'{project_name}.{dataset_name}.fridge_items'
    # recipe_ingredients_table = f'{project_name}.{dataset_name}.recipe_ingredients'

    # サブクエリで最新のcreated_atだけ取得
    demo_query = f"""
        SELECT *
        FROM `{demo_table}`
        WHERE created_at = (
            SELECT MAX(created_at)
            FROM `{demo_table}`
        )
    """
    # fridge_items_query = f"SELECT * FROM `{fridge_items_table}`"
    # recipe_ingredients_query = f"SELECT * FROM `{recipe_ingredients_table}`"

    # データの読み込み（pandas_gbqを使用）
    demo = pandas_gbq.read_gbq(
        demo_query.replace('\n', ' ').replace('\u3000', ''),
        project_id=project_name,
        dialect='standard'
    )
    # fridge_items = pandas_gbq.read_gbq(
    #     fridge_items_query.replace('\n', ' ').replace('\u3000', ''),
    #     project_id=project_name,
    #     dialect='standard'
    # )
    # recipe_ingredients = pandas_gbq.read_gbq(
    #     recipe_ingredients_query.replace('\n', ' ').replace('\u3000', ''),
    #     project_id=project_name,
    #     dialect='standard'
    # )

    return demo #  ,fridge_items, recipe_ingredients

def generate_menu(processor: GeminiProcessor, human_prompt: str) -> pd.DataFrame:
    """
    メニューを生成する

    Parameters
    ----------
    processor : GeminiProcessor
        GeminiProcessorインスタンス
    human_prompt : str
        ユーザープロンプト

    Returns
    -------
    pd.DataFrame
        生成されたメニュー情報を含むDataFrame
    """
    data = {
        "human_prompt": [human_prompt],
        "system_prompt": [SYSTEM_PROMPT]
    }
    df = pd.DataFrame(data)

    # Gemini API 呼び出し
    result_df = processor.process_dataframe(
        df,
        human_prompt_col="human_prompt",
        system_prompt_col="system_prompt",
        output_col="output"
    )

    return result_df

def parse_menu_json(raw_json: str | dict) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    メニューJSONを
    ├ header_df      : タイトル／ジャンル／調理時間
    ├ nutrition_df   : 栄養値
    ├ ingredients_df : 材料（name, quantity, unit）
    └ instructions_df: 手順（step, text）
    という4つのDataFrameに分解して返す

    Parameters
    ----------
    raw_json : str | dict
        メニューJSON（文字列または辞書）

    Returns
    -------
    tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]
        (header_df, nutrition_df, ingredients_df, instructions_df)のタプル
    """
    data = raw_json if isinstance(raw_json, dict) else json.loads(raw_json)

    # ヘッダー情報
    header_df = pd.DataFrame([{
        "title":           data["title"],
        "cuisine":         data["cuisine"],
        "total_time_min":  data["total_time_min"],
    }])

    # 栄養情報（すでにオブジェクト形式）
    nutrition_df = pd.DataFrame([data["nutrition"]])

    # 材料情報
    ingredients_df = pd.DataFrame(data["ingredients"])

    # 手順
    instructions_df = pd.DataFrame({
        "step": range(1, len(data["instructions"])+1),
        "text": data["instructions"]
    })

    return header_df, nutrition_df, ingredients_df, instructions_df

def save_to_bigquery(
    header_df: pd.DataFrame,
    nutrition_df: pd.DataFrame,
    ingredients_df: pd.DataFrame,
    instructions_df: pd.DataFrame,
    user_id: str = None
) -> None:
    """
    生成したメニューをBigQueryに保存する

    Parameters
    ----------
    header_df : pd.DataFrame
        メニュー基本情報
    nutrition_df : pd.DataFrame
        栄養情報
    ingredients_df : pd.DataFrame
        材料情報
    instructions_df : pd.DataFrame
        調理手順
    user_id : str, optional
        ユーザーID, by default None (環境変数から取得)
    """
    project_name = os.getenv('GOOGLE_CLOUD_PROJECT')
    dataset_name = os.getenv('BIGQUERY_DATASET')
    user_id = user_id or os.getenv('DEFAULT_USER_ID', 'user_001')

    # 現在時刻（UTC）
    now = datetime.now(timezone.utc)

    # メニューテーブル用のデータ作成
    menu_data = {
        "menu_id": [f"menu_{now.strftime('%Y%m%d_%H%M%S')}"],
        "user_id": [user_id],
        "created_at": [now],
        **header_df.iloc[0].to_dict(),
        **nutrition_df.iloc[0].to_dict()
    }
    menu_df = pd.DataFrame(menu_data)

    # 材料テーブル用のデータ作成
    ingredients_data = ingredients_df.copy()
    ingredients_data["menu_id"] = menu_df["menu_id"].iloc[0]
    ingredients_data["created_at"] = now

    # 手順テーブル用のデータ作成
    instructions_data = instructions_df.copy()
    instructions_data["menu_id"] = menu_df["menu_id"].iloc[0]
    instructions_data["created_at"] = now

    # BigQueryテーブル名
    menu_table = f"{project_name}.{dataset_name}.menus"
    ingredients_table = f"{project_name}.{dataset_name}.menu_ingredients"
    instructions_table = f"{project_name}.{dataset_name}.menu_instructions"

    # データの保存
    pandas_gbq.to_gbq(menu_df, menu_table, project_id=project_name, if_exists="append")
    pandas_gbq.to_gbq(ingredients_data, ingredients_table, project_id=project_name, if_exists="append")
    pandas_gbq.to_gbq(instructions_data, instructions_table, project_id=project_name, if_exists="append")

def update_inventory(
    ingredients_df: pd.DataFrame,
    user_id: str = None
) -> None:
    """
    材料在庫を更新する

    Parameters
    ----------
    ingredients_df : pd.DataFrame
        使用した材料情報
    user_id : str, optional
        ユーザーID, by default None (環境変数から取得)
    """
    project_name = os.getenv('GOOGLE_CLOUD_PROJECT')
    dataset_name = os.getenv('BIGQUERY_DATASET')
    user_id = user_id or os.getenv('DEFAULT_USER_ID', 'user_001')

    # 現在時刻（UTC）
    now = datetime.now(timezone.utc)

    # 在庫更新履歴テーブル用のデータ作成
    inventory_updates = []
    for _, row in ingredients_df.iterrows():
        # 数値に変換可能な数量のみ処理
        try:
            quantity = float(str(row["quantity"]).replace("g", "").replace("ml", ""))
            inventory_updates.append({
                "user_id": user_id,
                "ingredient_name": row["name"],
                "quantity_change": -quantity,  # 使用した分を減らす
                "unit": row["unit"],
                "created_at": now
            })
        except (ValueError, TypeError):
            continue  # 数値に変換できない場合はスキップ

    if inventory_updates:
        inventory_df = pd.DataFrame(inventory_updates)
        inventory_table = f"{project_name}.{dataset_name}.inventory_updates"
        pandas_gbq.to_gbq(inventory_df, inventory_table, project_id=project_name, if_exists="append")


from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
) # テスト用のCORSを許可

setup_environment()
processor = create_processor()

class MenuRequest(BaseModel):
    prompt: str

@app.post("/generate")
def generate_menu_endpoint(req: MenuRequest):
    """
    メイン処理
    """
    try:
        # データ読み込み
        demo = load_bigquery_data()
        num_people = len(demo)

        # ユーザーごとの属性まとめ
        people_desc = []
        for _, row in demo.iterrows():
            dstyle = row.get("dietary_style", "")
            gender = row.get("gender", "")
            age = row.get("age", "")
            line = f"・性別: {gender}、年齢: {age}"
            if pd.notna(dstyle) and dstyle:
                line += f"、食事スタイル: {dstyle}"
            people_desc.append(line)
        people_block = "\n".join(people_desc)

        # プロンプト生成
        human_prompt = f"""
        以下の条件で {num_people}人分のメニューを生成してください：
        ## 対象者の情報
        {people_block}

        ## その他の条件：
        - 調理時間は30分以内
        - 栄養バランスを考慮
        """

        # Gemini呼び出し
        result_df = generate_menu(processor, human_prompt)
        header_df, nutrition_df, ingredients_df, instructions_df = parse_menu_json(result_df.loc[0, "output"])
        # # 結果の表示
        # print("\n=== 生成されたメニュー ===")
        # print("\n基本情報:")
        # print(header_df)
        # print("\n栄養情報:")
        # print(nutrition_df)
        # print("\n材料:")
        # print(ingredients_df)
        # print("\n調理手順:")
        # print(instructions_df)
        
        return {
            "header": header_df.to_dict(orient="records"),
            "nutrition": nutrition_df.to_dict(orient="records"),
            "ingredients": ingredients_df.to_dict(orient="records"),
            "instructions": instructions_df.to_dict(orient="records"),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))