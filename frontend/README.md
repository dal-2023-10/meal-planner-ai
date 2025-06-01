# meal-planner-ai

献立提案・チラシ登録 Webアプリ

## 📦 構成

```
meal-planner-ai/
├── frontend/              # Flutter Webアプリ（UI入力・画像登録）
├── backend/               # FastAPI（献立API・BigQuery連携）
├── infra/                 # Terraform, Cloud Build 等 IaC
├── .github/workflows/     # GitHub Actions CI/CD 設定
├── .gitignore
└── README.md              # ← このファイル
```

## 📦 環境情報

### Flutter バージョン
- Flutter SDK: 3.22.1（推奨）
- Dart: 3.2.3
- 使用パッケージ：
  - `multi_select_flutter`
  - `google_fonts`
  - `image_picker`

---

### ✅ Flutter アプリ（frontend）
```bash
cd frontend
flutter pub get
flutter run -d chrome  # Web実行
```


## 📝 今後の予定

- [ ] 個人情報、画像の保存
- [ ] Geminiによる献立生成
