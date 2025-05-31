# Meal Planner

食事計画を効率的に管理するためのアプリケーション

## プロジェクト構成

```
meal_planner/
│  README.md               # プロジェクト概要・セットアップ手順
│  .gitignore             # Git除外設定
│  .env.example           # 環境変数サンプル
│
├─ .github/               # GitHub Actions など CI/CD 設定
│   └─ workflows/
│       ├─ frontend_ci.yml # Flutter テスト & ビルド
│       └─ backend_ci.yml  # Cloud Run 用 API テスト & デプロイ
│
├─ infra/                 # IaC・GCP リソース定義
│   ├─ terraform/         # Terraform設定
│   │   ├─ main.tf        # BigQuery DS/テーブル, Cloud Run, IAM
│   │   └─ variables.tf
│   └─ cloudbuild/        # Cloud Build 用設定
│       ├─ cloudrun.yaml
│       └─ bigquery.yaml
│
├─ backend/               # Cloud Run に載せる API
│   ├─ src/meal_planner_api/
│   │   ├─ __init__.py
│   │   ├─ main.py        # FastAPI エントリポイント
│   │   ├─ models.py      # Pydantic モデル
│   │   └─ services.py    # BigQuery サービス
│   ├─ tests/             # pytest
│   ├─ Dockerfile
│   └─ pyproject.toml     # 依存管理
│
├─ frontend/              # Flutter アプリ
│   ├─ lib/
│   │   ├─ main.dart
│   │   └─ screens/       # 画面定義
│   ├─ assets/           # 画像・フォント等
│   ├─ test/             # テスト
│   ├─ pubspec.yaml      # 依存管理
│   └─ Dockerfile        # Webビルド用
│
└─ docs/                 # 設計ドキュメント
    ├─ architecture/     # アーキテクチャ図
    ├─ api/             # OpenAPI仕様
    └─ decisions/       # ADR
```

## セットアップ手順

### 前提条件

- Python 3.9+
- Flutter 3.0+
- Docker
- Google Cloud SDK
- Terraform

### バックエンド開発環境のセットアップ

1. 仮想環境の作成と有効化:
```bash
cd backend
uv venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
```

2. 依存関係のインストール:
```bash
uv pip install -r requirements.txt
```

3. 環境変数の設定:
```bash
cp .env.example .env
# .envファイルを編集して必要な値を設定
```

4. 開発サーバーの起動:
```bash
uvicorn meal_planner_api.main:app --reload
```

### フロントエンド開発環境のセットアップ

1. Flutterの依存関係をインストール:
```bash
cd frontend
flutter pub get
```

2. 開発サーバーの起動:
```bash
flutter run
```

### インフラストラクチャのデプロイ

1. Terraformの初期化:
```bash
cd infra/terraform
terraform init
```

2. プランの確認と適用:
```bash
terraform plan
terraform apply
```

## 開発ガイドライン

- コミットメッセージは[Conventional Commits](https://www.conventionalcommits.org/)に従ってください
- プルリクエストは必ずレビューを受けてからマージしてください
- テストカバレッジは80%以上を維持してください

## ライセンス

MIT License 