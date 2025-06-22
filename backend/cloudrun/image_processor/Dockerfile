FROM python:3.10-slim

WORKDIR /app

# 依存パッケージのコピー＆インストール
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードをコピー
COPY image_processor_generate.py ./

# ログ出力（printデバッグ用）
ENV PYTHONUNBUFFERED=1

# FastAPIサーバの起動（PORTはCloud Run用に可変で）
CMD ["uvicorn", "menu_image_generate:app", "--host", "0.0.0.0", "--port", "8080"]