# おなかプランナー

食事計画を効率的に管理するためのアプリケーション

## プロジェクト構成

```
onaka-planner/
│  README.md                # プロジェクト概要・セットアップ
│  .gitignore               # Git管理除外
│
├─ backend/                 # バックエンド（Cloud Run用API）
│   └─ cloudrun/
│       ├─ menu_image_generate/
│       │    ├─ menu_image_generate.py   # メニュー→料理画像API
│       │    ├─ Dockerfile
│       │    ├─ requirements.txt
│       │    └─ .env
│       ├─ image_process/
│       │    ├─ image_process.py   # チラシ画像→チラシ情報API
│       │    ├─ Dockerfile
│       │    ├─ requirements.txt
│       │    └─ .env
│       ├─ menu_generate/
│       │    ├─ menu_generate.py         # メニュー生成API
│       │    ├─ Dockerfile
│       │    ├─ requirements.txt
│       │    └─ .env
│    　 └─ bq_uplode/
│            ├─ bq_uplode.py             # BigQueryアップロードAPI
│            ├─ Dockerfile
│            ├─ requirements.txt
│            └─ .env
│
└─ frontend/                      # フロントエンド（Flutterアプリ）
    ├─ lib/
    │    ├─ main.dart                 # エントリーポイント
    │    ├─ input_form_page.dart      # 入力フォーム画面
    │    ├─ flyer_upload_page.dart    # チラシ画像アップロード画面
    │    ├─ recipe_suggestions_page.dart # レシピ表示画面
    │    ├─ loading_page.dart         # ローディング画面
    │    └─ firebase_options.dart     # Firebase設定
    ├─ android/                      # Androidネイティブ 
    ├─ ios/                          # iOSネイティブ
    ├─ linux/                        # Linuxネイティブ
    ├─ macos/                        # macOSネイティブ
    ├─ windows/                      # Windowsネイティブ
    ├─ web/                          # Web設定・リソース
    ├─ public/                       # Web公開用静的ファイル
    ├─ test/                         # テストコード
    ├─ analysis_options.yaml         # 静的解析設定
    ├─ pubspec.yaml                  # 依存パッケージ
    ├─ pubspec.lock                  # 依存バージョンロック
    └─ firebase.json                 # Firebase設定
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
# macOS/Linux:
source .venv/bin/activate
# Windows:
.venv\Scripts\activate
```

2. 依存関係のインストール（開発用ツールも含めてインストールする場合）:
```bash
uv pip install -e .[dev]
```

- 通常の依存関係のみの場合は `[dev]` を外してください。
- 依存関係は `pyproject.toml` で管理しています。

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
