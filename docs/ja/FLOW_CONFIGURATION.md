# フロー設定ガイド

このガイドでは、レコードが作成・更新・削除されたときに Notion 同期をトリガーするための Salesforce フローの設定方法について説明します。

## 概要

Notion 同期システムでは、ユーザーコンテキストを維持しながら同期リクエストを処理するために、Invocable Apex メソッドを使用します。これにより、レコード操作は迅速に完了し、同期処理は適切な名前付き認証情報アクセスを保ちながら非同期で実行されます。

## フローのアーキテクチャ

```
レコード変更 → フロートリガー → Invocable Apex → @future/Queueable → Notion API
```

## テンプレートフロー

2 つのテンプレートフローが用意されています。

1. **NotionSync_Template_CreateUpdate.flow-meta.xml** - 作成・更新オペレーション用
2. **NotionSync_Template_Delete.flow-meta.xml** - 削除オペレーション用

## 新しいオブジェクト用のフロー作成

### ステップ 1: テンプレートファイルをコピー

1. `force-app/main/default/flows/` に移動します
2. テンプレートフローをコピーします:
   - `NotionSync_Template_CreateUpdate.flow-meta.xml` → `NotionSync_[ObjectName]_CreateUpdate.flow-meta.xml`
   - `NotionSync_Template_Delete.flow-meta.xml` → `NotionSync_[ObjectName]_Delete.flow-meta.xml`

### ステップ 2: 作成/更新フローを設定

コピーした作成/更新フローファイルを編集します。

1. **ラベルを更新します:**
   ```xml
   <label>Notion Sync - [ObjectName] Create/Update</label>
   ```

2. **説明を更新します:**
   ```xml
   <description>Flow for [ObjectName] CREATE/UPDATE operations - triggers Notion sync when [ObjectName] records are created or updated.</description>
   ```

3. **開始要素でオブジェクト種別を設定します:**
   ```xml
   <start>
       <object>[ObjectApiName]</object>
       <recordTriggerType>CreateAndUpdate</recordTriggerType>
       <triggerType>RecordAfterSave</triggerType>
   </start>
   ```

4. **アクション呼び出しの入力を更新します:**
   ```xml
   <inputParameters>
       <name>objectType</name>
       <value>
           <stringValue>[ObjectApiName]</stringValue>
       </value>
   </inputParameters>
   ```

### ステップ 3: 削除フローを設定

コピーした削除フローファイルを編集します。

1. **ラベルを更新します:**
   ```xml
   <label>Notion Sync - [ObjectName] Delete</label>
   ```

2. **説明を更新します:**
   ```xml
   <description>Flow for [ObjectName] DELETE operations - triggers Notion sync when [ObjectName] records are deleted.</description>
   ```

3. **開始要素でオブジェクト種別を設定します:**
   ```xml
   <start>
       <object>[ObjectApiName]</object>
       <recordTriggerType>Delete</recordTriggerType>
       <triggerType>RecordBeforeDelete</triggerType>
   </start>
   ```

4. **アクション呼び出しの入力を更新します:**
   ```xml
   <inputParameters>
       <name>objectType</name>
       <value>
           <stringValue>[ObjectApiName]</stringValue>
       </value>
   </inputParameters>
   ```

## 例: Contact オブジェクト

Contact オブジェクト用のフローを作成する手順は次のとおりです。

### 1. NotionSync_Contact_CreateUpdate.flow-meta.xml

1. テンプレートからコピーします
2. `[ObjectName]` を `Contact` に置き換えます
3. `[ObjectApiName]` を `Contact` に置き換えます
4. このフローは、Contact レコードが作成または更新されたときにトリガーされます

### 2. NotionSync_Contact_Delete.flow-meta.xml

1. テンプレートからコピーします
2. `[ObjectName]` を `Contact` に置き換えます
3. `[ObjectApiName]` を `Contact` に置き換えます
4. このフローは、Contact レコードが削除されたときにトリガーされます

## フローのデプロイ

フローファイルを作成したら、次の手順でデプロイします。

```bash
# Salesforce にデプロイ
sf project deploy start --source-dir force-app/main/default/flows

# 設定 → フロー でフローを有効化
```

## フローのテスト

フローが正しく動作しているか確認するには、次の操作を行います。

1. **作成のテスト:** 対象オブジェクトの新規レコードを作成します
2. **更新のテスト:** 対象オブジェクトの既存レコードを更新します
3. **削除のテスト:** 対象オブジェクトのレコードを削除します

同期ログを確認して、レコードが処理されていることを確認します。

```bash
sf apex run --file scripts/apex/check-sync-result.apex
```

## フローの命名規則

一貫性を保つため、以下の命名パターンに従ってください。

- **作成/更新:** `NotionSync_[ObjectName]_CreateUpdate`
- **削除:** `NotionSync_[ObjectName]_Delete`

例:
- `NotionSync_Account_CreateUpdate`
- `NotionSync_Account_Delete`
- `NotionSync_Contact_CreateUpdate`
- `NotionSync_Contact_Delete`
- `NotionSync_Opportunity_CreateUpdate`
- `NotionSync_Opportunity_Delete`

## トラブルシューティング

### フローがトリガーされない
1. フローが有効化されているかを確認します
2. オブジェクト種別が完全に一致しているかを確認します
3. トリガー条件が満たされていることを確認します
4. ユーザーに `Notion_Integration_User` 権限セットが割り当てられているかを確認します

### Invocable メソッドが呼び出されない
1. フローのデバッグログを確認します
2. アクション名が `NotionSyncInvocable` になっているかを確認します
3. 必要なパラメータがすべてマッピングされているかを確認します

### 同期が処理されない
1. Apex デバッグログでエラーを確認します
2. `Notion_Sync_Log__c` の同期ログを確認します
3. 名前付き認証情報の設定を確認します

## ベストプラクティス

1. **フローはシンプルに保つ** - Invocable メソッドを呼び出すだけにとどめ、複雑なロジックを追加しないでください
2. **一貫した命名を使用する** - 確立された命名規則に従ってください
3. **十分にテストする** - すべてのトリガーシナリオが正しく動作することを確認してください
4. **パフォーマンスを監視する** - レコード操作へのパフォーマンス影響を注視してください
5. **カスタマイズを文書化する** - フローに追加したカスタムロジックを記録しておいてください

## 高度な設定

### 条件付き同期
特定のレコードのみを同期するには、フローに開始条件を追加します。

```xml
<decisions>
    <name>Should_Sync</name>
    <label>Should Sync?</label>
    <locationX>176</locationX>
    <locationY>134</locationY>
    <defaultConnectorLabel>Don't Sync</defaultConnectorLabel>
    <rules>
        <name>Sync_Record</name>
        <conditionLogic>and</conditionLogic>
        <conditions>
            <leftValueReference>$Record.Status__c</leftValueReference>
            <operator>EqualTo</operator>
            <rightValue>
                <stringValue>Active</stringValue>
            </rightValue>
        </conditions>
        <connector>
            <targetReference>Sync_to_Notion</targetReference>
        </connector>
        <label>Sync Record</label>
    </rules>
</decisions>
```

### 一括オペレーション
フローは一括オペレーションを効率的に処理するよう設計されています。Invocable メソッドは自動的に次のように動作します。
- 単一レコードのオペレーションには @future を使用 (即時処理)
- 一括オペレーションには Queueable を使用 (バッチ処理)

これにより、オペレーションのサイズに関係なく最適なパフォーマンスが確保されます。

## セキュリティに関する考慮事項

1. **権限セット**: ユーザーに `Notion_Integration_User` 権限セットが割り当てられている必要があります
2. **オブジェクトアクセス**: ユーザーは同期対象オブジェクトに対する適切な CRUD 権限が必要です
3. **項目アクセス**: 同期対象項目への項目レベルセキュリティを許可してください
4. **名前付き認証情報**: API キーを Named Principal に設定し、ユーザーに権限セットを割り当てる必要があります
