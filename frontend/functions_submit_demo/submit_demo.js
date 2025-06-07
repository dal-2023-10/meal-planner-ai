// 🔐 認証キーのパスを指定（ローカル環境用）
// process.env.GOOGLE_APPLICATION_CREDENTIALS = './key.json';

const express = require('express');
const bodyParser = require('body-parser');
const { BigQuery } = require('@google-cloud/bigquery');

const app = express();
app.use(bodyParser.json());

// 📦 BigQuery クライアントの初期化
const bigquery = new BigQuery();

// 🔧 使用するデータセットとテーブル名
const datasetId = 'meal_planner';
const tableId = 'demo';

// ランダムな16文字の英数字を生成する関数
function generateRandomId(length = 16) {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  return Array.from({ length }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

// 🌐 CORS（クロスオリジンリクエスト）を許可するミドルウェア
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*'); // 必要に応じてドメインを制限可能
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // 🔁 プリフライトリクエスト（OPTIONS）には204で即応答
  if (req.method === 'OPTIONS') {
    return res.sendStatus(204);
  }

  next(); // 次のミドルウェアへ
});

// 📨 FlutterアプリからのPOSTリクエストを処理
app.post('/submit', async (req, res) => {
  try {
    const data = req.body;

    const row = {
      user_id: generateRandomId(),
      name: null,
      age: JSON.stringify(data.age),
      gender: JSON.stringify(data.gender),
      dietary_style: JSON.stringify(data.preferences),
      created_at: new Date().toISOString(),
    };

    await bigquery.dataset(datasetId).table(tableId).insert(row);
    console.log('BigQuery insert succeeded.');

    res.status(200).send('Data inserted successfully.');
  } catch (error) {
    if (error.name === 'PartialFailureError') {
      // エラーの詳細をログに出す
      error.errors.forEach(err => {
        console.error('Insert error row:', err.row);
        console.error('Insert error reason:', err.errors);
      });
    } else {
      console.error('BigQuery insert error:', error);
    }
    res.status(500).send('BigQuery insert failed');
  }
});


// 🚀 サーバー起動（Cloud Runなどで使用するポート）
const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Server listening on port ${port}`);
});
