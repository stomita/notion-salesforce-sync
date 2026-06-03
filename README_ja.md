[English](./README.md) | 日本語

# Notion Salesforce Sync

Salesforce のデータを Notion データベースにリアルタイムで同期する、Salesforce ネイティブのインテグレーションツールです。

## 機能

- 🔄 フロートリガによるリアルタイム同期
- 🔗 Salesforce オブジェクトのリレーションシップを Notion のリレーションとして保持
- 📊 レコードページ、アプリページ、ホームページに Notion データベースの行を表示する、埋め込み可能な **Notion Widget** Lightning コンポーネント（関連リストとしての動作にも対応）
- 🧭 Salesforce からレコードに対応する Notion ページを開くための **Notion Navigation** コンポーネント
- ⚡ Queueable Apex による非同期処理
- 🛠️ カスタムメタデータ型による設定駆動型の構成
- 🔒 指定ログイン情報を用いたセキュアな API インテグレーション
- 📝 ロングテキストエリア項目を Notion ページ本文としてサポート
- ♻️ 同期失敗時の自動再試行機構

## アーキテクチャ

本ツールは同期的なフローベースのアーキテクチャを採用しています。

```
[Record Change] → [Flow] → [Invocable Apex] → [Queueable/Future] → [Notion API]
```

同期的なアプローチを採ることで、処理全体を通じてユーザーコンテキストが維持され、指定ログイン情報へのアクセスが正しく機能します。

## セットアップ

管理者向けのインストールと構成手順の全体像 — パッケージインストール、Notion インテグレーション、認証情報、同期マッピング、ウィジェット設定、フロー設定、動作確認 — は **[docs/ja/SETUP_GUIDE.md](docs/ja/SETUP_GUIDE.md)** にまとまっています。

トピック別クイックリンク:

- **インストールと初回セットアップ**: [docs/ja/SETUP_GUIDE.md](docs/ja/SETUP_GUIDE.md)
- **管理 UI リファレンス (Sync および Widget Designer)**: [docs/ja/ADMIN_UI_USAGE.md](docs/ja/ADMIN_UI_USAGE.md)
- **フロートリガの設定**: [docs/ja/FLOW_CONFIGURATION.md](docs/ja/FLOW_CONFIGURATION.md)
- **一括 / 大量データ時の挙動**: [docs/ja/LARGE_DATA_SYNC.md](docs/ja/LARGE_DATA_SYNC.md)
- **開発者向けスクラッチ組織セットアップ**: [docs/ja/SCRATCH_ORG_SETUP.md](docs/ja/SCRATCH_ORG_SETUP.md)
- **パッケージング (2GP)**: [docs/ja/PACKAGING.md](docs/ja/PACKAGING.md)

## 開発

詳細な開発ガイドラインとアーキテクチャドキュメントについては [CLAUDE.md](CLAUDE.md) を参照してください。

## テスト

### 単体テスト

主要機能を検証するために単体テストを実行します。

```bash
sf apex test run --code-coverage --result-format human
```

### インテグレーションテスト

実際の Notion API 呼び出しを伴う包括的なエンドツーエンドテストについては、[インテグレーションテストガイド](docs/ja/INTEGRATION_TESTING.md) を参照してください。

クイックスタート:
```bash
./scripts/execute-integration-tests.sh
```

メタデータ設定と認証情報のセットアップを含む完全なセットアップ:
```bash
./scripts/run-integration-tests.sh
```

### CI/CD セットアップ

本プロジェクトは継続的インテグレーションに GitHub Actions を使用しています。CI ワークフローは自動的に以下を行います。

1. スクラッチ組織を作成
2. すべてのメタデータをデプロイ
3. Apex テストを実行
4. インテグレーションテストを実行
5. スクラッチ組織を削除

#### 必須設定

##### GitHub Secrets (機密データ):
- `DEVHUB_SFDX_AUTH_URL`: Dev Hub 組織の Salesforce DX 認証 URL
- `NOTION_API_KEY`: Notion インテグレーションのトークン

Dev Hub の認証 URL を取得するには:
```bash
sf org display -o your-devhub-alias --verbose --json
```
出力の `sfdxAuthUrl` フィールドを確認してください。

##### GitHub Variables (非機密設定):
**重要**: CI を正常に実行するためには、以下のすべてを設定する必要があります。

リポジトリ変数として設定してください (Settings → Secrets and variables → Actions → Variables):
- `NOTION_WORKSPACE_ID`: Notion のワークスペース ID
- `NOTION_TEST_ACCOUNT_DB`: Account 用のテストデータベース ID
- `NOTION_TEST_CONTACT_DB`: Contact 用のテストデータベース ID
- `NOTION_TEST_PARENT_DB`: 親オブジェクト用のテストデータベース ID
- `NOTION_TEST_CHILD_DB`: 子オブジェクト用のテストデータベース ID

CI ワークフローは開始時にすべての設定を検証し、いずれかが欠けている場合は失敗します。

テストデータベースのセットアップと値の取得に関する詳細な手順については、[CI セットアップガイド](docs/ja/CI_SETUP.md) を参照してください。

## CI/CD

### 継続的インテグレーション

本プロジェクトは自動テストに GitHub Actions を使用しています。

- **自動 CI**: `main` へのすべてのプッシュおよびすべてのプルリクエストで実行
- **手動 CI トリガ**: プルリクエストに `run-ci` ラベルを追加すると CI を手動で起動
- **ワークフロー直接実行**: Actions タブから任意のブランチで CI を実行可能

CI ワークフローの内容:
1. 必須のすべてのシークレットを検証 (不足があれば即座に失敗)
2. 一時的な Salesforce スクラッチ組織を作成
3. すべてのメタデータをデプロイ
4. すべての Apex テストをコードカバレッジ付きで実行
5. Notion API に対するインテグレーションテストを実行
6. スクラッチ組織を自動的にクリーンアップ

### CI でのインテグレーションテスト

CI ワークフローは自動的に以下を行います。
- 必須のすべての Notion シークレットが設定されていることを検証 (不足があれば即座に失敗)
- Notion データベース ID を使用してテストメタデータを構成
- 指定ログイン情報をプログラム的にセットアップ
- 実際の Notion API に対するエンドツーエンドの同期テストを実行
- 作成、更新、削除、およびリレーションシップ操作を検証

### PR ラベル

- `run-ci`: プルリクエストで CI ワークフローを手動でトリガ

## トラブルシューティング

### よくある問題

#### 「ログイン情報にアクセスできませんでした」エラー

このエラーは、ユーザーが指定ログイン情報にアクセスできない場合に発生します。

**解決策:**
1. 指定principal に API キーが設定されていることを確認します (設定 → 指定ログイン情報 → 外部ログイン情報 → Notion Credential → NotionIntegration)
2. ユーザーに「Notion Integration User」権限セットを割り当てていることを確認します
3. 同期をトリガするすべてのユーザーに権限セットを割り当てる必要があります
4. 診断スクリプトを実行して構成を確認します:
   ```bash
   sf apex run --file scripts/apex/verify-named-credential.apex
   ```

#### 「未承認のエンドポイント」エラー

これは、指定principal の認証情報が設定されていないことを示します。

**解決策:**
1. 指定principal はすでに存在しているはずです — [SETUP_GUIDE.md ステップ 3.1](docs/ja/SETUP_GUIDE.md#31-register-your-notion-api-key) の手順に従って API キーを追加してください
2. `SecretKey` パラメータに有効な Notion API トークンが含まれていることを確認します
3. ユーザーに「Notion Integration User」権限セットが割り当てられていることを確認します

#### 同期がトリガされない

レコードが Notion に同期されない場合:

1. フローの有効化を確認します:
   ```bash
   sf apex run --file scripts/apex/diagnose-sync-issue.apex
   ```

2. 同期ログでエラーを確認します:
   - App Launcher → Notion Sync Logs に移動
   - 失敗した同期について Error Message 項目を確認

3. Notion データベースに必要なプロパティが設定されていることを確認します

#### API トークンの問題

同期ログに 401 エラーが表示される場合:
- Notion API トークンが正しいことを確認します
- インテグレーションが対象の Notion データベースにアクセスできることを確認します
- トークンの有効期限が切れていないか、または取り消されていないかを確認します

## ライセンス

MIT
