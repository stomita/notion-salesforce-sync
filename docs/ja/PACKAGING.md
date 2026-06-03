# 2GP 管理パッケージガイド

このガイドでは、Notion Salesforce Sync を第2世代パッケージ (2GP) としてビルド・管理する方法を説明します。

## 前提条件

1. **ネームスペース付き DevHub**: 以下を備えた Developer Edition 組織が必要です:
   - Dev Hub が有効化されていること
   - 第2世代管理パッケージが有効化されていること
   - 登録済みのネームスペース (例: `notionsync`)

2. **Salesforce CLI**: 最新バージョンがインストールされていること

3. **パッケージ作成済み**: 「Notion Salesforce Sync」パッケージは既に作成済みで、ID は `0HogL0000000FVJSA2` です

## 設定

パッケージ設定を含む `.env` ファイルを作成します:
```bash
# サンプルファイルをコピー
cp .env.example .env

# パッケージ詳細を追加するため編集:
NOTION_SYNC_PACKAGE_NAMESPACE=notionsync
NOTION_SYNC_PACKAGE_ID=0HogL0000000FVJSA2
```

## パッケージバージョンのビルド

### クイックスタート

`.env` を設定し、デフォルトの DevHub を指定した状態で:
```bash
# .env のデフォルト値をすべて使ってビルド
./scripts/build-package.sh

# 必要に応じて特定の値を上書き
./scripts/build-package.sh --namespace myothernamespace --wait 30
```

### ビルドスクリプトのオプション

- `--namespace <namespace>` - ネームスペースを上書き (デフォルト: NOTION_SYNC_PACKAGE_NAMESPACE)
- `--devhub <alias>` - DevHub を上書き (デフォルト: デフォルトの DevHub)
- `--package-id <id>` - パッケージ ID を上書き (デフォルト: NOTION_SYNC_PACKAGE_ID)
- `--wait <minutes>` - パッケージ作成の待機時間 (デフォルト: 20)
- `--skip-validation` - パッケージ作成時の検証をスキップ
- `--no-code-coverage` - コードカバレッジの計算をスキップ

### ビルドスクリプトの処理内容

1. `.env` ファイルから設定を読み込みます
2. `sfdx-project.json` のバックアップを作成します
3. プロジェクトファイルにネームスペースとパッケージ ID を一時的に追加します
4. 設定内容で `sf package version create` を実行します
5. 元の `sfdx-project.json` を自動的に復元します

## パッケージ管理コマンド

### パッケージバージョンの一覧表示
```bash
sf package version list \
  --package "Notion Salesforce Sync" \
  --target-dev-hub notion-sync-devhub
```

### パッケージ詳細の参照
```bash
sf package version report \
  --package <version-id> \
  --target-dev-hub notion-sync-devhub
```

### スクラッチ組織へのインストール (テスト)
```bash
# テスト用のスクラッチ組織を作成
sf org create scratch -f config/project-scratch-def.json -a test-org -d -y 7

# パッケージをインストール
sf package install \
  --package <version-id> \
  --target-org test-org \
  --wait 10
```

### リリース版へのプロモート
```bash
sf package version promote \
  --package <version-id> \
  --target-dev-hub notion-sync-devhub
```

## CI/CD に関する考慮事項

CI パイプラインはネームスペースを持たない別の DevHub を使用するため、以下の点に注意してください:

1. **開発**: main ブランチでは `sfdx-project.json` にネームスペースを含めないこと
2. **パッケージビルド**: パッケージ作成時のみネームスペースを注入するためにビルドスクリプトを使用すること
3. **テスト**: CI のテストはスクラッチ組織でネームスペースなしで実行されること

## パッケージインストール手順

パッケージをインストールした後、顧客は以下を行う必要があります:

1. **External Credential の設定**:
   - 設定 → 指定ログイン情報 → 外部ログイン情報 (External Credentials) に移動
   - 「Notion Credential」を見つけます
   - Notion API キーを使って新しい Principal を作成します

2. **権限の割り当て**:
   - API アクセスが必要なユーザーには `Notion_Integration_User` 権限セットを割り当てます
   - 管理者には `Notion_Sync_Admin` 権限セットを割り当てます

3. **同期設定の構成**:
   - Notion Sync Admin アプリケーションを使ってオブジェクトとフィールドのマッピングを設定します
   - 同期をトリガーするフローを設定します

## トラブルシューティング

### Namespace Not Found エラー
ネームスペースが見つからないというエラーが出る場合:
- ネームスペースが登録されている正しい DevHub を使用していることを確認してください
- コマンド内のネームスペースが正しくスペルされていることを確認してください

### コードカバレッジの問題
コードカバレッジが原因でパッケージ作成に失敗する場合:
- `sf apex test run --code-coverage` を実行してカバレッジを確認してください
- すべての Apex クラスが適切なテストカバレッジ (最低 75%) を持つことを確認してください

### パッケージバージョン作成のタイムアウト
作成がタイムアウトする場合:
- 大規模なパッケージでは `--wait 30` 以上を指定してください
- `sf package version create report` でジョブのステータスを確認してください
