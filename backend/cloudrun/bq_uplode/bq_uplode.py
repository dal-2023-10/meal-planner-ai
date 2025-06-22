from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
import pandas_gbq
import os
from datetime import datetime, timezone
import uvicorn

app = FastAPI()

# CORS設定（Flutter Webなど必要な場合は制限を適宜調整）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番は適宜制限
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/save_recipe")
async def save_recipe(request: Request):
    data = await request.json()
    
    header_df = pd.DataFrame(data.get("header", []))
    nutrition_df = pd.DataFrame(data.get("nutrition", []))
    ingredients_df = pd.DataFrame(data.get("ingredients", []))
    instructions_df = pd.DataFrame(data.get("instructions", []))
    user_id = data.get("user_id", None)
    
    save_to_bigquery(header_df, nutrition_df, ingredients_df, instructions_df, user_id)
    return {"result": "ok"}

def save_to_bigquery(
    header_df: pd.DataFrame,
    nutrition_df: pd.DataFrame,
    ingredients_df: pd.DataFrame,
    instructions_df: pd.DataFrame,
    user_id: str = None
) -> None:
    project_name = os.getenv('GOOGLE_CLOUD_PROJECT')
    dataset_name = os.getenv('BIGQUERY_DATASET')
    now = datetime.now(timezone.utc)
    menu_id = f"menu_{now.strftime('%Y%m%d_%H%M%S')}"
    
    # --- created_menu（レシピ基本情報） ---
    menu_data = {
        "menu_id": [menu_id],
        "created_at": [now],
        "title": [header_df.iloc[0].get("title", "")],
        "total_time_min": [header_df.iloc[0].get("total_time_min", None)],
        "kcal": [nutrition_df.iloc[0].get("kcal", None)],
        "protein_g": [nutrition_df.iloc[0].get("protein_g", None)],
        "fat_g": [nutrition_df.iloc[0].get("fat_g", None)],
        "carb_g": [nutrition_df.iloc[0].get("carb_g", None)],
        "salt_g": [nutrition_df.iloc[0].get("salt_g", None)],
        "fiber_g": [nutrition_df.iloc[0].get("fiber_g", None)],
    }
    menu_df = pd.DataFrame(menu_data)
    menu_table = f"{project_name}.{dataset_name}.created_menu"
    pandas_gbq.to_gbq(menu_df, menu_table, project_id=project_name, if_exists="append")

    # --- ingredients（材料情報） ---
    if not ingredients_df.empty:
        ingredients_df = ingredients_df.copy()
        ingredients_df["menu_id"] = menu_id
        # 列順を揃える（menu_id, name, quantity, unit）
        ingredients_df = ingredients_df[["menu_id", "name", "quantity", "unit"]]
        ingredients_table = f"{project_name}.{dataset_name}.ingredients"
        pandas_gbq.to_gbq(ingredients_df, ingredients_table, project_id=project_name, if_exists="append")

    # --- instructions ---
    if not instructions_df.empty:
        instructions_df = instructions_df.copy()
        instructions_df["menu_id"] = menu_id
        # 列順を揃える（menu_id, step, text）
        instructions_df = instructions_df[["menu_id", "step", "text"]]
        instructions_table = f"{project_name}.{dataset_name}.instructions"
        pandas_gbq.to_gbq(instructions_df, instructions_table, project_id=project_name, if_exists="append")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8080)
