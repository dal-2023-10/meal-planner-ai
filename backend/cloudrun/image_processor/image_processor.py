# gemini_processor.py
import os, json, pandas as pd
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, asdict
from dotenv import load_dotenv
from google import generativeai as genai        
from google.generativeai import GenerationConfig  

from PIL import Image
from io import BytesIO
import firebase_admin
from firebase_admin import credentials, storage

import pandas_gbq 
from datetime import datetime, timezone

# ─────────────────────────────────────────────
# 1. モデル向けパラメータを "全部入り" で保持する dataclass
# ─────────────────────────────────────────────
# ─────────────────────────────────────────────
# 1. モデル向けパラメータを "全部入り" で保持する dataclass
# ─────────────────────────────────────────────

@dataclass
class GeminiOptions_image:
    # ── GenerationConfig パラメータ ─────────────────────────
    temperature: float = 0.0
    top_p: float = 1.0
    top_k: int = 1
    candidate_count: int = 1
    max_output_tokens: int = 65535
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
            temperature=self.temperature,
            top_p=self.top_p,
            top_k=self.top_k,
            candidate_count=self.candidate_count,
            max_output_tokens=self.max_output_tokens,
            stop_sequences=self.stop_sequences or None,
            presence_penalty=self.presence_penalty or None,
            frequency_penalty=self.frequency_penalty or None,
        )
    
# ─────────────────────────────────────────────
# 2. メインクラス
# ─────────────────────────────────────────────
class ImageProcessor:
    def __init__(
        self,
        api_key_env: str = "GOOGLE_API_KEY",
        model_name: str = "models/gemini-2.5-flash-lite-preview-06-17",
        options: GeminiOptions_image = GeminiOptions_image(),  
        project_id: Optional[str] = "",
        firebase_cred_path: str = None,
        firebase_bucket: str = None
    ):
        load_dotenv()
        # Google APIキーの取得
        api_key = os.getenv(api_key_env)
        if not api_key:
            raise ValueError(f"{api_key_env} が設定されていません")
        genai.configure(api_key=api_key)

        # Firebase認証情報の取得
        self.firebase_cred_path = firebase_cred_path or os.getenv('FIREBASE_CRED_PATH')
        self.firebase_bucket = firebase_bucket or os.getenv('FIREBASE_STORAGE_BUCKET')

        if not self.firebase_cred_path or not self.firebase_bucket:
            raise ValueError("Firebase認証情報が設定されていません。FIREBASE_CRED_PATH と FIREBASE_STORAGE_BUCKET を環境変数に設定してください。")

        # Firebaseの初期化
        if not firebase_admin._apps:  # Firebase SDKが初期化されていない場合のみ初期化
            cred = credentials.Certificate(self.firebase_cred_path)
            firebase_admin.initialize_app(cred, {
                'storageBucket': self.firebase_bucket
            })
        self.bucket = storage.bucket()

        # safety_settingsを更新
        self.safety_settings = [
            {
                "category": "HARM_CATEGORY_HARASSMENT",
                "threshold": "BLOCK_ONLY_HIGH",
            },
            {
                "category": "HARM_CATEGORY_HATE_SPEECH",
                "threshold": "BLOCK_ONLY_HIGH",
            },
            {
                "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "threshold": "BLOCK_ONLY_HIGH",
            },
            {
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "threshold": "BLOCK_ONLY_HIGH",
            },
        ]

        # モデルの初期化
        self.model = genai.GenerativeModel(
            model_name=model_name,
            generation_config=options.to_generation_config(),
            safety_settings=self.safety_settings,
        )
        self.options = options
        self.project_id = project_id
        self.prompt = """
画像から商品情報を抽出してください。チラシに記載されている商品情報を以下の形式で出力してください：

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
- 値が不明な場合は空文字列を使用してください
- 上記のJSON形式以外の文章は含めないでください
"""
    
    # ─────────────────────────────────────────────
    # 1. 画像取得関連のメソッド
    # ─────────────────────────────────────────────
    def get_latest_image_path(self, prefix: str = "", target_date: str = None) -> Optional[str]:
        """
        FireStorageから最新の画像ファイルのパスを取得する

        Args:
            prefix (str): 検索対象のフォルダパス（例: "images/"）
            target_date (str): 対象日付（YYYY-MM-DD形式）。指定しない場合は最新の画像を返す

        Returns:
            Optional[str]: 最新の画像ファイルのパス。見つからない場合はNone
        """
        try:
            # 指定されたパスのファイルをリスト化
            blobs = self.bucket.list_blobs(prefix=prefix)
            
            # 更新日時でソートして最新のファイルを取得
            latest_blob = None
            latest_time = None
            
            for blob in blobs:
                # 画像ファイルの拡張子をチェック
                if any(blob.name.lower().endswith(ext) for ext in ['.jpg', '.jpeg', '.png', '.gif']):
                    # ファイル名から日付を抽出
                    filename = blob.name.split('/')[-1]
                    if target_date:
                        if not filename.startswith(target_date):
                            continue
                    
                    if latest_time is None or blob.updated > latest_time:
                        latest_blob = blob
                        latest_time = blob.updated
            
            if latest_blob:
                return latest_blob.name
            
            return None
        except Exception as e:
            print(f"Error getting latest image path from FireStorage: {e}")
            return None

    def get_latest_image(self, prefix: str = "", target_date: str = None) -> Optional[Image.Image]:
        """
        FireStorageから最新の画像を取得する

        Args:
            prefix (str): 検索対象のフォルダパス（例: "images/"）
            target_date (str): 対象日付（YYYY-MM-DD形式）。指定しない場合は最新の画像を返す

        Returns:
            Optional[Image.Image]: 最新の画像のPILオブジェクト。失敗時はNone
        """
        latest_path = self.get_latest_image_path(prefix, target_date)
        if latest_path:
            return self.get_image_from_storage(latest_path)
        return None

    def get_image_from_storage(self, image_path: str) -> Optional[Image.Image]:
        """
        FireStorageから画像を取得し、PIL.Imageオブジェクトとして返す

        Args:
            image_path (str): FireStorage内の画像パス

        Returns:
            Optional[Image.Image]: 取得した画像のPILオブジェクト。失敗時はNone
        """
        try:
            blob = self.bucket.blob(image_path)
            if not blob.exists():
                print(f"Error: Image not found at path: {image_path}")
                return None

            image_bytes = blob.download_as_bytes()
            image = Image.open(BytesIO(image_bytes)).convert("RGB")
            return image
        except Exception as e:
            print(f"Error loading image from FireStorage: {str(e)}")
            return None

    # ─────────────────────────────────────────────
    # 2. 画像処理関連のメソッド
    # ─────────────────────────────────────────────
    def pil_image_to_gemini_part(self, image: Image.Image) -> dict:
        """
        PIL Image を Gemini に渡せるバイナリ形式に変換

        Args:
            image (Image.Image): 変換する画像

        Returns:
            dict: Gemini APIに渡すための形式に変換された画像データ
        """
        buf = BytesIO()
        image.save(buf, format='JPEG')
        byte_data = buf.getvalue()
        return {
            "mime_type": "image/jpeg",
            "data": byte_data
        }
    
    # ─────────────────────────────────────────────
    # 3. 画像認識関連のメソッド
    # ─────────────────────────────────────────────
    def Image_recognition(self, prompt: str = "", image: Optional[Image.Image] = None) -> Optional[dict]:
        if not prompt:
            prompt = self.prompt

        if image is None:
            image = self.get_latest_image()
            if image is None:
                print("画像の取得に失敗しました")
                return None

        try:
            # 画像をGemini用のフォーマットに変換
            image_part = self.pil_image_to_gemini_part(image)

            # generation_configを更新
            generation_config = GenerationConfig(
                temperature=0.1,  # より決定論的な出力のために温度を下げる
                top_p=1,
                top_k=1,
                max_output_tokens=65535,
                candidate_count=1
            )

            try:
                response = self.model.generate_content(
                    contents=[
                        image_part,
                        prompt
                    ],
                    generation_config=generation_config,
                    stream=False  # ストリーミングを無効化
                )

                # レスポンスを処理する前に待機
                if hasattr(response, 'resolve'):
                    response.resolve()

                # レスポンスの検証
                if not response.candidates:
                    print("応答が空でした")
                    return None

                # finish_reasonのチェック
                if hasattr(response.candidates[0], 'finish_reason'):
                    finish_reason = response.candidates[0].finish_reason
                    if finish_reason == 2:  # SAFETY
                        print(f"安全性チェックにより応答が制限されました（finish_reason: {finish_reason}）")
                        return None

                # レスポンスの内容を確認
                if not hasattr(response, 'text'):
                    print("応答にテキストが含まれていません")
                    if hasattr(response, 'prompt_feedback'):
                        print("Prompt Feedback:", response.prompt_feedback)
                    return None

                response_text = response.text
                if not response_text:
                    print("応答テキストが空です")
                    return None

            #    print("API Response:", response_text)  # デバッグ用

                # JSONとしてパース
                try:
                    # 余分なテキストを削除してJSONを抽出
                    json_text = response_text
                    if "```json" in json_text:
                        json_text = json_text.split("```json")[1]
                    if "```" in json_text:
                        json_text = json_text.split("```")[0]
                    json_text = json_text.strip()

#                    print("Cleaned JSON text:", json_text[:100] + "...") # デバッグ用に最初の100文字を表示
                    self.response = json.loads(json_text)
#                    print("Successfully parsed JSON with", len(self.response), "items") # デバッグ用
                except json.JSONDecodeError as e:
                    print(f"JSONのパースに失敗しました: {str(e)}")
                    print("Response text was:", response_text)
                    return None

                # レスポンスの構造を確認
                if not isinstance(self.response, list):
                    print("レスポンスが配列形式ではありません")
                    return None

                # 各オブジェクトの構造を確認
                required_keys = ["商品", "数量", "値段", "特売日"]
                for item in self.response:
                    if not all(key in item for key in required_keys):
                        print("商品情報に必要なキーが含まれていません")
                        print("Received keys:", list(item.keys()))
                        return None

                # DataFrameに変換
                df = pd.DataFrame(self.response)

                # Bigqueryに保存
                try:
                    project_name = os.getenv('GOOGLE_CLOUD_PROJECT')
                    dataset_name = os.getenv('BIGQUERY_DATASET')
                    flyer_table = f"{project_name}.{dataset_name}.flyer_data"
                    # データの保存
                    pandas_gbq.to_gbq(df, flyer_table, project_id=project_name, if_exists="replace")
                except Exception as e:
                    print(f"Bigqueryに保存中にエラーが発生しました: {str(e)}")
                    return None

                return self.response

            except Exception as e:
                print(f"API呼び出し中にエラーが発生しました: {str(e)}")
                if 'response' in locals():
                    print("Response details:", response)
                return None

        except Exception as e:
            print(f"画像認識中にエラーが発生しました: {str(e)}")
            return None
        
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

load_dotenv()
class ImageRequest(BaseModel):
    prompt: str

@app.post("/flyer_image_processor")
def flyer_image_processor(req: ImageRequest):
    try:
        # ImageProcessorのインスタンスを作成
        image_processor = ImageProcessor()
        image_processor.Image_recognition()
        return None
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))





        
        
