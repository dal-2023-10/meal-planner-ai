FROM python:3.10-slim

WORKDIR /app

# 必要なパッケージのインストール
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードのコピー
COPY app/ ./app/

# ログ出力の設定
ENV PYTHONUNBUFFERED=1

# サーバーの起動（Cloud Runの環境変数PORTを使用）
CMD exec uvicorn app.app:app --host 0.0.0.0 --port ${PORT:-8080}
