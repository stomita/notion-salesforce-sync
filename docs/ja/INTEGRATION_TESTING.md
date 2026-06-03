# インテグレーションテストガイド

このガイドでは、実際の API 呼び出しで Notion 同期機能を検証するインテグレーションテストの実行方法について説明します。

## 前提条件

1. API アクセスが可能な Notion アカウント
2. Notion インテグレーショントークン
3. Notion に作成済みのテスト用データベース（データベースのセットアップについては CI_SETUP.md を参照）
4. パッケージがデプロイ済みの Salesforce スクラッチ組織

## テスト用データベースのセットアップ

### 概要

インテグレーションテストでは、テストマッピングが期待するとおりに、特定のプロパティを設定した 4 つの Notion データベースが必要です。

**重要**: すべてのデータベースに、Salesforce レコードを追跡するための `salesforce_id` プロパティ（型: Text）が必要です。

### データベース作成の手順

#### 1. Notion に 4 つのテスト用データベースを作成する

Notion ワークスペースに新しいデータベースページを作成します。
1. Account Test Database
2. Contact Test Database
3. Test Parent Database
4. Test Child Database

#### 2. 各データベースのプロパティを設定する

##### Account Test Database
以下のプロパティを追加します。
- プロパティ名: `Name` → 型: `Title`
- プロパティ名: `salesforce_id` → 型: `Text`

**注意**: Account の Description はページ本文にマッピングされます。

##### Contact Test Database
以下のプロパティを追加します。
- プロパティ名: `Name` → 型: `Title`
- プロパティ名: `Email` → 型: `Email`
- プロパティ名: `Account` → 型: `Relation` → 「Account Test Database」を選択
- プロパティ名: `salesforce_id` → 型: `Text`

##### Test Parent Database
以下のプロパティを追加します。
- プロパティ名: `Name` → 型: `Title`
- プロパティ名: `Status` → 型: `Select` → 選択肢を追加: Active, Inactive, In Progress
- プロパティ名: `Amount` → 型: `Number`
- プロパティ名: `Active` → 型: `Checkbox`
- プロパティ名: `salesforce_id` → 型: `Text`

**注意**: Description__c はページ本文にマッピングされます。

##### Test Child Database
以下のプロパティを追加します。
- プロパティ名: `Name` → 型: `Title`
- プロパティ名: `Quantity` → 型: `Number`
- プロパティ名: `Due Date` → 型: `Date`
- プロパティ名: `Test Parent` → 型: `Relation` → 「Test Parent Database」を選択
- プロパティ名: `Account` → 型: `Relation` → 「Account Test Database」を選択
- プロパティ名: `salesforce_id` → 型: `Text`

**注意**: Details__c はページ本文にマッピングされます。

#### 3. インテグレーションへのアクセスを付与する

各データベースに対して以下を実行します。
1. 右上の `Share` ボタンをクリック
2. `Invite` をクリック
3. インテグレーション名を検索
4. 該当のインテグレーションを選択
5. 編集権限が付与されていることを確認

#### 4. データベース ID を取得する

各データベースに対して以下を実行します。
1. `Share` → `Copy link` をクリック
2. URL の形式は次のとおりです: `https://www.notion.so/{workspace}/{database-id}?v={view-id}`
3. database-id の部分（32 文字）をコピー

#### 5. データベース ID を設定する

これらを環境変数または GitHub シークレットとして設定します。
- `NOTION_DATABASE_ID_ACCOUNT` = Account データベース ID
- `NOTION_DATABASE_ID_CONTACT` = Contact データベース ID
- `NOTION_DATABASE_ID_TEST_PARENT` = Test Parent データベース ID
- `NOTION_DATABASE_ID_TEST_CHILD` = Test Child データベース ID

### よくあるデータベースセットアップの問題

#### 「Property not found」エラー
- プロパティ名は大文字と小文字を区別し、完全に一致している必要があります
- タイトルプロパティには「Title」ではなく「Name」を使用します
- プロパティ名末尾の空白がないか確認します

#### 「Relation not found」エラー
- データベースは順番に作成してください（最初に Account、次に Contact など）
- リレーションプロパティが正しいターゲットデータベースを指していることを確認します
- リレーション名は完全に一致している必要があります

#### 同期の失敗
- すべてのデータベースに `salesforce_id` プロパティが存在することを確認します
- インテグレーションがすべてのデータベースへの編集権限を持っていることを確認します
- 必要なすべてのプロパティが正しい型で作成されていることを確認します

### ページ本文への項目マッピング

以下の Salesforce 項目は、Notion ページのプロパティではなく、本文に同期されます。
- Account: `Description` 項目 → ページ本文
- Test Parent: `Description__c` 項目 → ページ本文
- Test Child: `Details__c` 項目 → ページ本文

これらは Notion ページ内のリッチテキストとして表示されます。

## クイックスタート

インテグレーションテストフレームワークは、自動化された CI 実行とインタラクティブなローカル開発の両方をサポートしています。

### 適切なスクリプトの選び方

#### 次のような場合は `run-integration-tests.sh` を使用してください:
- **初回セットアップ** - テスト環境をまだ設定していない場合
- **CI/CD 環境** - 完全なセットアップが必要な新しいスクラッチ組織で実行する場合
- **完全な自動化が必要** - スクリプトにすべての設定を任せたい場合

このスクリプトでは以下を提供します。
- 不足している環境変数（API キー、データベース ID）のインタラクティブな入力プロンプト
- テストメタデータの自動設定
- インテグレーションテストコンポーネントのデプロイ
- API キーによる指定ログイン情報のセットアップ
- テスト実行
- クリーンアップ（プレースホルダー値の復元）

```bash
# 初回セットアップ
./scripts/run-integration-tests.sh

# スクラッチ組織を指定
./scripts/run-integration-tests.sh my-scratch-org
```

#### 次のような場合は `execute-integration-tests.sh` を使用してください:
- **すべての設定が完了済み** - 指定ログイン情報、メタデータ、コンポーネントがセットアップ済みの場合
- **すばやい再実行** - セットアップなしで再度テストを実行したい場合
- **デバッグ** - テスト修正を繰り返し行っており、高速な実行が必要な場合

この軽量スクリプトはすべてのセットアップ手順をスキップし、テストの実行のみを行います。

```bash
# 高速なテスト実行
./scripts/execute-integration-tests.sh

# テストコードの変更をデプロイした後
sf project deploy start --source-dir force-app/integration
./scripts/execute-integration-tests.sh
```

### 環境変数（オプション）

非インタラクティブに実行する場合は、以下の環境変数を設定します。

```bash
export NOTION_API_KEY='your-notion-api-key'
export NOTION_WORKSPACE_ID='your-workspace-id'
export NOTION_DATABASE_ID_ACCOUNT='account-database-id'
export NOTION_DATABASE_ID_CONTACT='contact-database-id'
export NOTION_DATABASE_ID_TEST_PARENT='parent-database-id'
export NOTION_DATABASE_ID_TEST_CHILD='child-database-id'
```

#### .env ファイルの使用

インテグレーションテストスクリプトは、プロジェクトルートに `.env` ファイルが存在する場合、自動的に環境変数を読み込みます。

```bash
# 設定を含む .env ファイルを作成
cat > .env << EOF
NOTION_API_KEY=your-notion-api-key
NOTION_WORKSPACE_ID=your-workspace-id
NOTION_TEST_ACCOUNT_DB=account-database-id
NOTION_TEST_CONTACT_DB=contact-database-id
NOTION_TEST_PARENT_DB=parent-database-id
NOTION_TEST_CHILD_DB=child-database-id
EOF

# インテグレーションテストを実行（.env を自動的に読み込み）
./scripts/run-integration-tests.sh
```

このアプローチは特に以下の場合に便利です。
- 毎回変数をエクスポートしたくないローカル開発
- 機密性の高い API キーをシェル履歴から除外したい場合
- 異なる環境間をすばやく切り替えたい場合
- チームメンバー間で一貫した設定を維持したい場合

**注意**: `.env` ファイルは絶対にバージョン管理にコミットしないでください。`.gitignore` ファイルに追加してください。

## 動作の仕組み

### 1. 認証情報の自動セットアップ

`NotionTestCredentialSetup` クラスは、指定ログイン情報をプログラムで設定します。
- 認証情報の作成と更新の両方を処理
- API キーを安全に設定
- 適切な権限が割り当てられることを保証

### 2. メタデータの設定

`configure-test-metadata.sh` スクリプトは以下を行います。
- カスタムメタデータファイルのプレースホルダー値を置換
- すべてのプレースホルダーが置換されたことを検証
- 異なるオペレーティングシステム間で動作

### 3. テストの実行

`NotionIntegrationTestExecutor` クラスは以下を行います。
- 包括的な同期テストを実行
- 作成、更新、削除操作を検証
- リレーションシップ同期をテスト
- 詳細な進捗とエラーレポートを提供

## テストカバレッジ

インテグレーションテストでは以下を検証します。

1. **作成同期** - Salesforce レコードの作成が Notion に同期される
2. **更新同期** - Salesforce レコードの更新が Notion ページに反映される
3. **リレーションシップ同期** - 関連レコードが Notion 上でリレーションシップを維持する
4. **削除同期** - Salesforce レコードの削除が Notion ページの削除を引き起こす

### 項目型のカバレッジ

包括的な同期サポートを保証するため、テストオブジェクトにはさまざまな項目型が含まれています。
- テキストおよびロングテキストエリア
- 数値および通貨
- 日付および日時
- チェックボックス（ブール値）
- 選択リストの値
- 主従関係
- 参照関係
- ページ本文へのマッピング（ロングテキストエリア → Notion ページ本文）

## テスト結果のモニタリング

### テスト実行中

テスト出力には以下が表示されます。
- 各テストの進捗
- 成功/失敗のステータス
- エラーメッセージ（ある場合）

### テスト実行後

Notion ワークスペースで以下を確認します。
- テストレコードが作成されたこと
- リレーションシップが適切にリンクされていること
- 削除されたレコードが除去されていること

Salesforce で同期ログをクエリします。
```apex
SELECT Record_Id__c, Object_Type__c, Operation_Type__c, 
       Status__c, Notion_Page_Id__c, Error_Message__c
FROM Notion_Sync_Log__c
WHERE CreatedDate >= :DateTime.now().addHours(-1)
ORDER BY CreatedDate DESC
```

## CI/CD インテグレーション

### GitHub Actions のセットアップ

以下の条件を満たすと、インテグレーションテストが CI で自動的に実行されます。
1. 必要なシークレットがすべて GitHub に設定されている
2. プルリクエストが作成または更新された
3. コードが main ブランチにプッシュされた

必要な GitHub の設定:

**シークレット**（機密データ）:
- `DEVHUB_SFDX_AUTH_URL` - Salesforce Dev Hub 認証
- `NOTION_API_KEY` - Notion API キー

**変数**（機密ではない設定）:
- `NOTION_WORKSPACE_ID` - Notion ワークスペース ID
- `NOTION_TEST_ACCOUNT_DB` - Account テストデータベース ID
- `NOTION_TEST_CONTACT_DB` - Contact テストデータベース ID
- `NOTION_TEST_PARENT_DB` - Test Parent データベース ID
- `NOTION_TEST_CHILD_DB` - Test Child データベース ID

CI ワークフローは以下を行います。
1. すべての設定が存在することを検証する（存在しない場合は早期に失敗）
2. スクラッチ組織を作成する
3. インテグレーションテストを含むすべてのメタデータをデプロイする
4. 指定ログイン情報を自動的に設定する
5. インテグレーションテストを実行する
6. 結果をレポートする

## トラブルシューティング

### インタラクティブなプロンプトが動作しない

スクリプトがハングしたり、プロンプトが表示されない場合:
- インタラクティブなターミナルで実行しているか確認します
- プロンプトの代わりに環境変数を設定してみます

### 環境変数が設定されていない（CI）

CI では、不足している環境変数があると即座に失敗します。
- 必要なシークレットがすべて GitHub に設定されているか確認します
- シークレット名が完全に一致しているか確認します（大文字小文字を区別）

### API 認証に失敗する

401 Unauthorized でテストが失敗する場合:
- API キーが正しく、有効であることを確認します
- Notion インテグレーションがすべてのテストデータベースにアクセスできるか確認します
- 指定ログイン情報が適切に設定されていることを確認します

### 認証情報のセットアップに失敗する

「Failed to configure credential」と表示される場合:
- External Credential と指定ログイン情報が存在することを確認します
- 権限セットがデプロイされていることを確認します
- 組織で適切な権限を持っていることを確認します

### 同期が発生しない

レコードが同期されない場合:
- 組織でフローがアクティブであることを確認します
- カスタムメタデータが正しくデプロイされていることを確認します
- Notion_Sync_Log__c レコードでエラーを確認します
- フローが Invocable Apex を使用して適切に設定されていることを確認します

### テストデータの競合

既存データが原因でテストが失敗する場合:
- テスト実行ツールは開始時にテストデータをクリーンアップします
- 必要に応じて、残っているテストレコードを手動で削除してください
- Notion でのユニーク制約違反がないか確認します

## ベストプラクティス

1. **専用のテストデータベースを使用する** - 本番データに対してテストを実行しないでください
2. **テスト後にクリーンアップする** - スクリプトはメタデータファイルを自動的に復元します
3. **API 制限をモニタリングする** - Notion API のレート制限に注意してください
4. **隔離されたテスト** - インテグレーションテストには専用のスクラッチ組織を使用します

## 単体テスト

インテグレーションテストを実行する前に、単体テストでコア機能を検証します。

```bash
sf apex test run --tests NotionApiClientTest --code-coverage --result-format human --wait 10
```

期待される結果: すべてのテストが高いコードカバレッジで成功するはずです。

## 手動でのテスト実行

テストプロセスをより細かく制御する必要がある場合:

### 1. テストメタデータの設定

```bash
./scripts/configure-test-metadata.sh \
  --workspace-id "your-workspace-id" \
  --account-db "account-db-id" \
  --contact-db "contact-db-id" \
  --parent-db "parent-db-id" \
  --child-db "child-db-id"
```

### 2. インテグレーションテストのデプロイ

```bash
sf project deploy start --source-dir force-app/integration
```

### 3. 認証情報のセットアップ

テンプレートから一時的なスクリプトを作成します。
```bash
sed "s/NOTION_API_KEY_PLACEHOLDER/your-api-key/" \
  scripts/apex/setup-integration-credentials-template.apex > /tmp/setup-creds.apex

sf apex run --file /tmp/setup-creds.apex
```

### 4. テストの実行

```bash
./scripts/execute-integration-tests.sh
```

## 高度な使用方法

### 失敗したテストのデバッグ

1. **デバッグログを有効にします:**
   ```bash
   sf apex tail log --target-org your-org
   ```

2. **同期ログを確認します:**
   ```apex
   // 開発者コンソールまたは匿名 Apex で実行
   List<Notion_Sync_Log__c> logs = [
       SELECT Record_Id__c, Object_Type__c, Operation_Type__c, 
              Status__c, Error_Message__c, CreatedDate
       FROM Notion_Sync_Log__c
       WHERE CreatedDate = TODAY
       ORDER BY CreatedDate DESC
       LIMIT 50
   ];
   System.debug(JSON.serializePretty(logs));
   ```

3. **Invocable Apex を検証します:**
   ```apex
   // Invocable メソッドを直接テスト
   NotionSyncInvocable.SyncRequest request = new NotionSyncInvocable.SyncRequest();
   request.recordId = 'test123';
   request.objectType = 'Account';
   request.operationType = 'CREATE';
   
   List<NotionSyncInvocable.SyncRequest> requests = new List<NotionSyncInvocable.SyncRequest>{request};
   NotionSyncInvocable.syncToNotion(requests);
   ```

### テストデータのカスタマイズ

テスト実行ツールはテストデータに特定のプレフィックスを使用します。
- Account: "Integration Test Account"
- Contact: "Integration Test Contact"
- テストオブジェクト: "Integration Test"

異なるテストデータを使用するには、実行ツールクラスを変更するか、独自のテストシナリオを作成してください。

## セキュリティのベストプラクティス

1. API トークンを**絶対にバージョン管理にコミットしない**でください
2. すべての外部 API 呼び出しに**指定ログイン情報**を使用してください
3. API トークンを定期的にローテーションしてください
4. Notion でインテグレーションのアクセスを必要なデータベースのみに制限してください
5. 同期ログを監視して不正アクセスの試みを検出してください

## その他のデバッグコマンド

```bash
# 最近のログを表示
sf apex log list

# 詳細なログを取得
sf apex log get --log-id <log-id>

# 同期ログをモニタリング
sf data query -f scripts/soql/check-sync-logs.soql

# Queueable ジョブを確認
sf data query --query "SELECT Id, Status, JobType, MethodName, CreatedDate FROM AsyncApexJob WHERE JobType='Queueable' ORDER BY CreatedDate DESC LIMIT 10"
```

## インテグレーションテストアーキテクチャ

### テスト実行パターン

すべてのインテグレーションテストは、一貫性と信頼性を確保するために、標準化された 3 フェーズの実行パターンに従います。

1. **セットアップフェーズ**（オプション）
   - テストデータと環境を準備する
   - テスト実行前にクリーンな状態を保証する
   - テストが事前データを必要としない場合は省略可能

2. **実行フェーズ**（必須）
   - 実際のテスト操作を実行する
   - 同期プロセスを起動する
   - テスト対象のアクションを実行する

3. **確認フェーズ**（必須）
   - 期待される結果を検証する
   - Salesforce と Notion 間のデータ整合性を確認する
   - 明確な診断とともに成功または失敗を報告する

### テスト実装のガイドライン

新しいインテグレーションテストを作成する際:

1. **命名規則**:
   - テストスクリプト: `test-N-descriptive-name.sh` (N はテスト番号)
   - Apex ファイル: `test-N-descriptive-name-{setup|run|check}.apex`

2. **アーキテクチャの階層**:
   - **シェルスクリプト** (`test-*.sh`): テスト実行を編成
   - **Apex スクリプト** (`test-*.apex`): テスト実行ツールをインスタンス化して呼び出す薄いラッパー
   - **テスト実行ツール** (`NotionIntegrationTestExecutor`): 実際のテストロジックを含む

3. **シェルスクリプトの構造**:
   - オプションの組織エイリアスパラメータを受け取る
   - 相対パスの解決に `SCRIPT_DIR` を使用する
   - 操作の複雑さに応じた適切な待機時間を実装する
   - 堅牢なチェックのために `retry-check.sh` を使用する

4. **Apex スクリプトの構造**:
   ```apex
   // テスト実行ツールをインスタンス化
   NotionIntegrationTestExecutor executor = new NotionIntegrationTestExecutor();
   
   // 適切なメソッドを呼び出す
   executor.runYourTest();  // 実行フェーズ用
   executor.checkYourTestResults();  // 確認フェーズ用
   
   // 成功/失敗のレポートを処理
   System.debug('✓ Test passed');
   System.debug('INTEGRATION_TEST_FAILURE_MARKER');  // 失敗時
   ```

5. **テスト実行ツールの実装**:
   - `NotionIntegrationTestExecutor` クラスに新しいメソッドを追加
   - 一貫性のために既存のパターンに従う
   - 各テストに対して実行メソッドと確認メソッドの両方を実装する
   - テスト目的に合致した分かりやすいメソッド名を使用する

6. **タイミングの考慮事項**:
   - 期待される同期時間に基づいて初期待機時間を選択する
   - 信頼性と実行時間のバランスを取るためにリトライパラメータを設定する
   - リトライ間隔を設定する際は操作の複雑さを考慮する

### テストインフラ

インテグレーションテストフレームワークは以下を提供します。

- **`retry-check.sh`**: 非同期操作のリトライロジックを処理
- **`run-apex-with-validation.sh`**: Apex を実行して出力を検証
- **`execute-integration-tests.sh`**: すべてのテストを順に実行
- **テストオーケストレーション**: 依存関係を考慮して番号付きテストが順に実行される

## インテグレーションテストの構造

`force-app/integration` ディレクトリには以下が含まれます。

- **objects/**: さまざまな項目型とリレーションシップを持つカスタムテストオブジェクト
  - `Test_Parent_Object__c`: さまざまな項目型を持つ親オブジェクト
  - `Test_Child_Object__c`: 主従関係および参照関係を持つ子オブジェクト

- **customMetadata/**: Notion 同期用のテスト設定
  - テストデータベース用の NotionDatabase レコード
  - 同期設定用の NotionSyncObject レコード
  - 項目マッピング用の NotionSyncField レコード
  - リレーションシップマッピング用の NotionRelation レコード

- **flows/**: テストオブジェクト用の自動化フロー
  - Invocable Apex を呼び出す作成/更新フロー
  - レコード削除用の削除フロー

- **permissionsets/**: テストオブジェクトアクセス用の権限セット

- **classes/**: テスト実行および認証情報セットアップクラス
  - `NotionIntegrationTestExecutor`: メインのテストランナー
  - `NotionTestCredentialSetup`: プログラムによる認証情報設定
  - `NotionTestCredentialSetupTest`: 認証情報セットアップの単体テスト

注意: このディレクトリは、メインのパッケージデプロイには含まれません（sfdx-project.json で `default: false` としてマーク）。
