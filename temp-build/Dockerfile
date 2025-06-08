FROM python:3.9-slim

WORKDIR /app

# 必要なパッケージのインストール
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# アプリケーションコードのコピー
COPY app/ ./app/

# サーバーの起動
CMD exec uvicorn app.app:app --host $HOST --port ${PORT}
