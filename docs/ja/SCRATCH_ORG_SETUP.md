# スクラッチ組織セットアップガイド

このガイドでは、Notion Salesforce Sync の開発用にスクラッチ組織を適切にセットアップする方法を説明します。

## クイックスタート - 自動セットアップ

スクラッチ組織をセットアップする最も簡単な方法は、提供されているセットアップスクリプトを使用することです。

```bash
# デフォルトセットアップ（エイリアス 'notion-sync-scratch' で組織を作成）
./scripts/setup-scratch-org.sh

# カスタムエイリアス
./scripts/setup-scratch-org.sh my-org-alias
```

## セットアップスクリプトの動作

セットアップスクリプト（`scripts/setup-scratch-org.sh`）は、以下のステップを実行します。

1. **スクラッチ組織の作成**
   - 有効期限 30 日
   - デフォルト組織として設定
   - `config/project-scratch-def.json` の設定を使用

2. **全メタデータのデプロイ**
   - `force-app/main` と `force-app/integration` の両方のフォルダーをデプロイ
   - テストオブジェクト（Test_Parent_Object__c、Test_Child_Object__c）を含む

3. **権限セットの割り当て**
   - `Notion_Integration_User` - API アクセスに必要
   - `Notion_Sync_Admin` - 管理 UI へのアクセスに必要
   - `Notion_Integration_Test_User` - テストオブジェクトへのアクセスに必要

4. **パスワードの生成**
   - スクラッチ組織ユーザー用のパスワードを生成
   - Playwright などのツールを使用した UI テストに役立ちます

## 手動セットアップ

組織を手動でセットアップしたり、プロセスをカスタマイズしたりする必要がある場合は、以下を実行します。

```bash
# 1. スクラッチ組織の作成
sf org create scratch -f config/project-scratch-def.json -a notion-sync-scratch -d -y 30

# 2. メタデータのデプロイ
sf project deploy start --source-dir force-app -o notion-sync-scratch

# 3. 権限セットの割り当て
sf org assign permset --name Notion_Integration_User -o notion-sync-scratch
sf org assign permset --name Notion_Sync_Admin -o notion-sync-scratch
sf org assign permset --name Notion_Integration_Test_User -o notion-sync-scratch

# 4. パスワードの生成
sf org generate password -o notion-sync-scratch

# 5. 組織を開く
sf org open -o notion-sync-scratch -p /lightning/n/Notion_Sync_Admin
```

## 重要な注意事項

### 権限セット

割り当てが必要な権限セットは 3 つあります。

1. **Notion_Integration_User**（`force-app/main` 配下）
   - API アクセス権限を付与
   - 同期機能を動作させるために必須

2. **Notion_Sync_Admin**（`force-app/main` 配下）
   - Notion Sync Admin UI へのアクセス権を付与
   - 同期設定を構成するために必須

3. **Notion_Integration_Test_User**（`force-app/integration` 配下）
   - テストオブジェクトとそのフィールドへのアクセス権を付与
   - Test_Parent_Object__c と Test_Child_Object__c のフィールドメタデータを表示するために必須
   - これがないと、UI でカスタムフィールドが "Unknown" 型として表示されます

### テストオブジェクト

integration フォルダーには、インテグレーションテストに使用するテストオブジェクトが含まれています。
- `Test_Parent_Object__c` - カスタムフィールドを持つ親オブジェクト
- `Test_Child_Object__c` - 参照関係を持つ子オブジェクト

これらのオブジェクトは、`force-app` ディレクトリ全体をデプロイした場合にのみデプロイされます。

## トラブルシューティング

### フィールドが "Unknown" 型として表示される

Notion Sync Admin UI でテストオブジェクトのカスタムフィールドが "Unknown" 型として表示される場合は、以下を確認してください。
1. `Notion_Integration_Test_User` 権限セットが割り当てられていることを確認
2. 割り当て後にブラウザーページを再読み込み

### 権限エラー

"You do not have permission to access Notion Sync Admin features" と表示される場合は、以下を確認してください。
1. `Notion_Sync_Admin` 権限セットが割り当てられていることを確認
2. 必要に応じてログアウトして再ログイン

### デプロイの失敗

デプロイが失敗する場合は、以下を確認してください。
1. Dev Hub が有効化されていることを確認
2. 認証されていることを確認: `sf org list`
3. デプロイ状況を確認: `sf project deploy report`

## 便利なコマンド

```bash
# 組織の詳細（パスワードを含む）を表示
sf org display -o notion-sync-scratch

# UI テスト用の組織 URL を取得
sf org open --url-only -o notion-sync-scratch

# 特定のページを開く
sf org open -o notion-sync-scratch -p /lightning/n/Notion_Sync_Admin

# 完了時にスクラッチ組織を削除
sf org delete scratch -o notion-sync-scratch -p
```
