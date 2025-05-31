# gemini_processor.py
import os, json, pandas as pd
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, asdict
from dotenv import load_dotenv
from google import generativeai as genai        
from google.generativeai import GenerationConfig  

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