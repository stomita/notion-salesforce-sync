# CI セットアップガイド

このガイドでは、Notion API を使用したインテグレーションテストを実行するための GitHub Actions の設定方法を説明します。

## 前提条件

1. Notion インテグレーショントークン（API キー）
2. テスト用データベースを作成済みの Notion ワークスペース
3. シークレットを設定するためのリポジトリ管理者権限

## 必要な GitHub シークレット

GitHub リポジトリの設定（Settings → Secrets and variables → Actions）で以下のシークレットを設定してください。

### 1. `NOTION_API_KEY`
Notion インテグレーショントークンです。取得方法は以下のとおりです。
1. https://www.notion.so/my-integrations にアクセスします
2. 新しいインテグレーションを作成するか、既存のものを使用します
3. 「Internal Integration Token」をコピーします

### 2. `NOTION_WORKSPACE_ID`
Notion ワークスペースの ID です。確認方法は以下のとおりです。
1. Notion ワークスペース内の任意のページを開きます
2. URL を確認します: `https://www.notion.so/{workspace-name}-{workspace-id}`
3. ワークスペース ID（32 文字の文字列）をコピーします

### 3. データベース ID
Notion にテスト用データベースを 4 つ作成し、それぞれの ID を取得します。

- `NOTION_DATABASE_ID_ACCOUNT` - Account レコード用
- `NOTION_DATABASE_ID_CONTACT` - Contact レコード用
- `NOTION_DATABASE_ID_TEST_PARENT` - Test_Parent_Object__c レコード用
- `NOTION_DATABASE_ID_TEST_CHILD` - Test_Child_Object__c レコード用

データベース ID の取得方法は以下のとおりです。
1. Notion でデータベースを開きます
2. 「Share」をクリックしてリンクをコピーします
3. URL から ID を抽出します: `https://www.notion.so/{workspace}/{database-id}?v={view-id}`

## Notion でのテストデータベースのセットアップ

必須プロパティを含むテストデータベースの作成および設定の詳細な手順については、[インテグレーションテストガイドのテストデータベースセットアップセクション](INTEGRATION_TESTING.md#test-database-setup)を参照してください。

**概要**: インテグレーションテストのフィールドマッピングと一致する特定のプロパティを持つ 4 つのデータベース（Account、Contact、Test Parent、Test Child）を作成する必要があります。すべてのデータベースにはトラッキング用の `salesforce_id` プロパティが必要です。

## GitHub シークレットの設定

1. GitHub のリポジトリにアクセスします
2. Settings → Secrets and variables → Actions に移動します
3. 必要なシークレットごとに「New repository secret」をクリックします
4. 上記のとおりに正確な名前を入力し、値を貼り付けます

## セットアップの検証

すべてのシークレットを設定した後の手順は以下のとおりです。
1. 変更をプッシュして CI をトリガーします
2. Actions タブでワークフローをモニタリングします
3. 「Validate Integration Test Configuration」ステップですべてのシークレットが設定されていることが検証されます

## トラブルシューティング

### 「Validate Integration Test Configuration」で CI が失敗する場合
- 必須シークレット 6 つすべてが設定されていることを確認してください
- シークレット名にタイプミスがないか確認してください
- 値が空でないことを確認してください

### インテグレーションテストが失敗する場合
- Notion API キーがすべてのテストデータベースにアクセス可能であることを確認してください
- データベースのプロパティが期待される名前と一致していることを確認してください
- ワークスペース ID が正しいことを確認してください

### 権限エラー
- Notion インテグレーションにすべてのテストデータベースへのアクセス権を付与してください
- 各データベースで Share → Invite → インテグレーションを選択してください
