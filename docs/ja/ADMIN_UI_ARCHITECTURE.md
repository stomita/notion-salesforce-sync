# Notion Sync 管理者 UI アーキテクチャ

## 概要

Notion Sync 管理者 UI は、Lightning Web コンポーネント (LWC) ベースのインターフェイスで、Salesforce 管理者がカスタムメタデータレコードを直接編集することなく Notion 同期のマッピングを設定できるようにします。

## コンポーネントアーキテクチャ

### 1. メインコンテナコンポーネント
**コンポーネント**: `notionSyncAdmin`
- アプリケーション全体の状態とナビゲーションを管理
- オブジェクト選択と設定の読み込みを処理
- `isNewConfiguration` フラグで新規と既存の設定を追跡
- 未保存の変更を管理し、確認ダイアログを提供
- エラー処理とトースト通知を提供
- 設定ビューとサマリービュー間の調整を実施

### 2. 設定サマリーコンポーネント
**コンポーネント**: `notionSyncSummary`
- 設定済みの同期マッピングをすべて表示するデフォルトのランディングビュー
- サマリー統計を表示 (設定済みオブジェクト、有効な同期、項目マッピング)
- すべての設定をテーブルビューで提供:
  - オブジェクト名と API 名
  - Notion データベース ID
  - 有効/無効ステータス
  - 項目数とリレーションシップ数
  - 編集アクション
- 親コンポーネントに編集イベントをディスパッチ

### 3. データベースブラウザーコンポーネント
**コンポーネント**: `notionDatabaseBrowser`
- データベース選択用のモーダルコンポーネント
- 利用可能な Notion データベースを取得して表示
- データベースの検索とフィルタリングを可能にする
- データベースのプロパティとその型を表示
- データベース ID と名前を含む選択イベントをディスパッチ

### 4. 項目マッピングコンポーネント
**コンポーネント**: `notionFieldMapping`
- メイン管理者コンポーネント内に組み込まれる
- 選択されたオブジェクトの Salesforce 項目を表示
- Notion データベースのプロパティを表示
- 互換性のあるプロパティ型を自動検出
- 項目マッピング配列を管理
- Long Text 項目のボディコンテンツマッピングをサポート

### 5. リレーションシップ設定コンポーネント
**コンポーネント**: `notionRelationshipConfig`
- メイン管理者コンポーネント内に組み込まれる
- 親子リレーションシップを設定
- 参照/主従項目を Notion リレーションにマッピング
- リレーションシップマッピング配列を管理

## Apex アーキテクチャ

### 1. NotionAdminController
権限チェック機能を備えた UI 操作のメインコントローラー:
- `checkAdminPermission()`: ユーザーが `Notion_Sync_Admin` カスタム権限を持っているかを検証
- `getDatabases()`: API 経由で Notion データベースを取得
- `getDatabaseSchema(databaseId)`: 特定のデータベースのプロパティを取得
- `getSalesforceObjects()`: 利用可能な SF オブジェクトを返す (同期可能なオブジェクトでフィルタ)
- `getObjectFields(objectApiName)`: 型情報付きでオブジェクトの項目を取得
- `getAllSyncConfigurations()`: 既存の同期設定をすべて取得
- `getSyncConfiguration(objectApiName)`: 特定オブジェクトの設定を取得
- `saveSyncConfiguration(config)`: Metadata API を使用して設定を保存
- `testConnection(databaseId)`: Notion API の接続性を確認

### 2. NotionMetadataService
Metadata API を使用したカスタムメタデータ操作のサービスクラス:
- `saveSyncConfiguration(config)`: すべてのメタデータレコードの保存を統括
- NotionSyncObject__mdt レコードの作成/更新
- NotionSyncField__mdt レコードの作成/更新
- NotionRelation__mdt レコードの作成/更新
- 開発者名のサニタイズを処理
- 非同期でのメタデータデプロイを管理

### 3. NotionApiClient
Notion API との連携用サービス:
- 認証に指定ログイン情報 (`Notion_API`) を使用
- `searchDatabases()`: アクセス可能なすべてのデータベースを取得
- `getDatabase(databaseId)`: 特定のデータベーススキーマを取得
- API レスポンスの解析とエラー処理を実施
- 標準化された NotionResponse ラッパーを返却

## データフロー

1. **初期ロード**:
   - サマリーコンポーネントがすべての同期設定を取得
   - 設定テーブルと統計を表示
   - ユーザーは新規作成または既存設定の編集が可能

2. **新規設定プロセス**:
   - ユーザーが「New Sync Configuration」をクリック
   - コンポーネントが `isNewConfiguration = true` を設定
   - ユーザーがドロップダウンから Salesforce オブジェクトを選択
   - ユーザーが Notion データベースを参照して選択
   - 初期設定をメタデータに保存
   - 項目およびリレーションシップマッピングを後から追加可能

3. **設定の編集プロセス**:
   - ユーザーが既存設定の「Edit」をクリック
   - コンポーネントが設定の詳細をロード
   - ユーザーが設定、項目、またはリレーションシップを変更
   - `hasUnsavedChanges` フラグで変更を追跡
   - 保存により Metadata API 経由で更新をデプロイ

4. **検証**:
   - オブジェクトの選択は必須
   - Notion データベースの選択は必須
   - Salesforce ID プロパティ名は必須
   - 項目マッピングは任意 (後から追加可能)
   - テストボタンで API 接続性を確認

## UI/UX デザイン

### Lightning Design System コンポーネント
- レスポンシブデザイン用の Lightning Layout
- オブジェクト/項目リスト用の Lightning Datatable
- 選択用の Lightning Combobox
- 項目マッピング用の Lightning Dual Listbox
- セクション構成用の Lightning Accordion
- ローディング状態用の Lightning Spinner
- 通知用の Lightning Toast

### レイアウト構造

#### メインビュー (サマリー)
```
┌─────────────────────────────────────────┐
│         Notion Sync Admin               │
├─────────────────────────────────────────┤
│  Sync Configurations                    │
│  [New Sync Configuration]               │
├─────────────────────────────────────────┤
│  ┌─────┐  ┌─────┐  ┌──────┐           │
│  │  5  │  │  5  │  │  13  │           │
│  └─────┘  └─────┘  └──────┘           │
│  Objects  Active   Mappings            │
├─────────────────────────────────────────┤
│  Configured Objects Table               │
│  ┌─────────────────────────────────┐   │
│  │ Object | Database | Status | ... │   │
│  │ Account| 2125... | Active | Edit │   │
│  │ Contact| 2125... | Active | Edit │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

#### 設定ビュー
```
┌─────────────────────────────────────────┐
│  [←] Edit Account Configuration         │
├─────────────────────────────────────────┤
│  Basic Configuration                    │
│  ☑ Active                              │
│  Database: [Account DB] [Browse]       │
│  SF ID Property: [Salesforce_ID]       │
├─────────────────────────────────────────┤
│  Field Mappings                         │
│  [Field mapping component]              │
├─────────────────────────────────────────┤
│  Relationship Mappings                  │
│  [Relationship config component]        │
├─────────────────────────────────────────┤
│  [Cancel] [Test Connection] [Save]      │
└─────────────────────────────────────────┘
```

## 実装ステータス

### 完了機能
1. ✅ 権限チェック機能付きのコア Apex コントローラー
2. ✅ Metadata API を使用したメタデータサービス
3. ✅ 指定ログイン情報を用いた Notion API インテグレーション
4. ✅ ナビゲーション付きのメインコンテナコンポーネント
5. ✅ 設定テーブルを備えたサマリービュー
6. ✅ オブジェクト選択とデータベースマッピング
7. ✅ 項目マッピングコンポーネント
8. ✅ リレーションシップ設定コンポーネント
9. ✅ データベースブラウザーモーダル
10. ✅ 検証付きの保存機能
11. ✅ 接続テスト機能
12. ✅ 権限セットとカスタム権限
13. ✅ タブ付き Lightning App
14. ✅ Notion 同期ログのリストビュー
15. ✅ 新規設定作成フロー
16. ✅ 既存設定の編集フロー
17. ✅ 未保存変更の追跡
18. ✅ エラー処理とトースト通知

### 将来の拡張
1. ID の代わりに Notion データベース名を表示
2. 一括項目マッピング操作
3. 設定のインポート/エクスポート
4. 項目マッピングテンプレート
5. 同期プレビュー機能

## セキュリティに関する考慮事項

1. **権限モデル**:
   - カスタム権限: きめ細かい制御のための `Notion_Sync_Admin`
   - 権限セット: `Notion_Sync_Administrator` が必要な権限をすべてバンドル
   - すべての Apex メソッドは `FeatureManagement.checkPermission()` を使用して権限をチェック
   - UI は権限のないユーザーに対して明確な「Access Denied」メッセージを表示

2. **API セキュリティ**:
   - セキュアな認証のための指定ログイン情報 (`Notion_API`)
   - 指定プリンシパルを使用した外部ログイン情報
   - API キーをコードやカスタム設定に保存しない
   - NotionRateLimiter によるレート制限の適用

3. **データ検証**:
   - オブジェクト API 名をスキーマに対して検証
   - 項目 API 名のアクセシビリティをチェック
   - Notion プロパティ名のサニタイズ
   - 使用前にデータベース ID を検証
   - メタデータ向けに開発者名をサニタイズ

## テスト戦略

1. **単体テスト**:
   - `NotionAdminControllerTest`: 90% 以上のカバレッジ
   - `NotionMetadataServiceTest`: メタデータ操作
   - 権限チェックの検証
   - エラー処理シナリオ

2. **インテグレーションテスト**:
   - エンドツーエンドの設定フロー
   - 実際の Notion API との連携
   - メタデータデプロイの検証

3. **UI テスト**:
   - Claude 内で UI テストに Playwright MCP を使用
   - 組織 URL の取得: `sf org open --url-only -o <org-alias>`
   - コンポーネントへのナビゲーションと操作
   - 設定の作成と編集の検証
