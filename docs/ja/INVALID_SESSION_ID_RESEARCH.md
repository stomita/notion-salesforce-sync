# Lightning コンポーネントにおける Metadata API の INVALID_SESSION_ID エラー調査

## 問題の概要

Lightning コンポーネントから Metadata API を呼び出す際（具体的には `NotionAdminController.deleteSyncConfiguration` 内）、以下のエラーが発生します。

```
Web service callout failed: WebService returned a SOAP Fault: INVALID_SESSION_ID: Invalid Session ID found in SessionHeader: Illegal Session
```

### 根本原因

このエラーは NotionAdminController.cls の 629 行目で発生します。
```apex
service.SessionHeader.sessionId = UserInfo.getSessionId();
```

**発生理由**: Lightning コンテキストでは、`UserInfo.getSessionId()` が返すセッション ID は API コールには有効ではありません。セキュリティポリシーにより、Lightning コンポーネントによって生成されたセッションは API アクセス用に有効化されていません。

## 現行実装の分析

### 1. 削除フロー
現在の削除処理は以下のパスをたどります。
- `NotionAdminController.deleteSyncConfiguration()` → SOAP API を使用する MetadataService を利用
- `NotionAdminController.deleteCustomMetadataRecords()` → セッション ID を用いた直接的な Metadata API コール

### 2. 保存／更新フロー
保存処理は異なるアプローチを採用しています。
- `NotionAdminController.saveSyncConfiguration()` → `NotionMetadataService.saveSyncConfiguration()`
- `Metadata.Operations.enqueueDeployment()` を使用 - ネイティブな Apex メタデータデプロイ（セッション ID 不要）

## 解決策の選択肢

### 選択肢 1: ネイティブな Metadata.Operations API を使用する（推奨）
**実装**: 削除処理を保存／更新と同じアプローチでリファクタリングする

**メリット**:
- 既にコードベース内（NotionMetadataService）で動作実績がある
- セッション ID が不要
- Salesforce ネイティブのサポート
- 既存のパターンと整合性が取れる

**デメリット**:
- 削除ロジックのリファクタリングが必要
- ソフト削除の扱いを変える必要があるかもしれない

### 選択肢 2: Metadata API 用の指定ログイン情報を作成する
**実装**: 「legacy」タイプとして構成された指定ログイン情報をセットアップする

**メリット**:
- 外部 API コールに対する Salesforce 推奨のアプローチ
- セキュアでメンテナンス性が高い

**デメリット**:
- 追加のセットアップが必要
- 内部の Metadata API コールには過剰かもしれない
- それでも大幅なリファクタリングが必要

### 選択肢 3: Visualforce ページによる回避策
**実装**: `{!$Api.Session_ID}` を提供する VF ページを作成する

**メリット**:
- 有効な API セッション ID を取得できる

**デメリット**:
- 追加の VF ページにより複雑性が増す
- モダンな解決策ではない
- Classic 機能への依存が生じる

## 推奨される解決策

**選択肢 1 を採用**: アプリケーション全体で一貫して `Metadata.Operations` API を使用するようリファクタリングする。

### 実装手順:

1. **`deleteSyncConfiguration` メソッドのリファクタリング**:
   - `deleteCustomMetadataRecords` への直接呼び出しを削除
   - 代わりに `NotionMetadataService.deleteObjectConfiguration` を呼び出す

2. **`NotionMetadataService.deleteObjectConfiguration` の更新**:
   - `Metadata.Operations.enqueueDeployment` を用いたソフト削除を既に実装済み
   - 変更不要 - 既に正しいアプローチを採用している

3. **未使用コードの削除**:
   - NotionAdminController から `deleteCustomMetadataRecords` メソッドを削除
   - 削除処理における MetadataService への依存を解消

### 必要なコード変更:

`NotionAdminController.cls` 内の以下のコードを置き換えます。
```apex
@AuraEnabled
public static SaveResult deleteSyncConfiguration(String objectApiName) {
    checkAdminPermission();
    
    SaveResult result = new SaveResult();
    try {
        // Use MetadataService to delete the configuration
        deleteCustomMetadataRecords(objectApiName);
        
        result.success = true;
        result.message = 'Configuration deleted successfully.';
        return result;
    } catch (Exception e) {
        result.success = false;
        result.message = 'Failed to delete configuration: ' + e.getMessage();
        result.errors = new List<String>{ e.getMessage() };
        return result;
    }
}
```

以下のコードに置き換えます。
```apex
@AuraEnabled
public static SaveResult deleteSyncConfiguration(String objectApiName) {
    checkAdminPermission();
    
    SaveResult result = new SaveResult();
    try {
        // Use NotionMetadataService for consistent metadata operations
        NotionMetadataService.deleteObjectConfiguration(objectApiName);
        
        result.success = true;
        result.message = 'Configuration deleted successfully.';
        return result;
    } catch (Exception e) {
        result.success = false;
        result.message = 'Failed to delete configuration: ' + e.getMessage();
        result.errors = new List<String>{ e.getMessage() };
        return result;
    }
}
```

その後、`deleteCustomMetadataRecords` メソッド全体（611 ～ 691 行目）を削除します。

## その他の考慮事項

1. **ソフト削除の実装**: 現在の `NotionMetadataService.deleteObjectConfiguration` は、レコードを物理的に削除するのではなく `IsDeleted__c = true` を設定することで、既にソフト削除を実装しています。

2. **非同期処理という特性**: `Metadata.Operations.enqueueDeployment` は非同期であるため、削除開始から完了までの遅延を UI 側で扱う必要があるかもしれません。

3. **テスト**: 新しい実装で動作するように、削除関連のすべてのテストスクリプトを更新してください。

## 参考資料

- [Salesforce Known Issue: Session ID in Lightning](https://success.salesforce.com/issues_view?id=a1p3A0000003eJiQAI)
- [Metadata.Operations Documentation](https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_Metadata_Operations.htm)
- [Lightning Component API Access Restrictions](https://developer.salesforce.com/docs/atlas.en-us.lightning.meta/lightning/security_csp.htm)
