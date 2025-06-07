# Node.js 22 の公式イメージを使用
FROM node:22

# アプリケーションディレクトリ作成
WORKDIR /usr/src/app

# package.json と package-lock.json をコピー
COPY package*.json ./

# 依存関係をインストール
RUN npm install

# アプリのソースコードをコピー
COPY . .

# コンテナ起動時に実行するコマンド
CMD ["node", "submit_demo.js"]

# Cloud Run はデフォルトで 8080 ポートを使うのでEXPOSEは推奨（なくても動く）
EXPOSE 8080
