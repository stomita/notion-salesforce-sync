# 大量データ同期アーキテクチャ

## 概要

本ドキュメントでは、Salesforce-Notion 同期が実行時のガバナ制限チェックと自動的な Queueable チェーンを用いて、大規模なデータ同期をどのように処理するかを説明します。本アーキテクチャはレコードを個別に処理し、制限に近づくと自動的にチェーンするため、事前のバッチ分割が不要です。

## 現在の実装の特徴

本実装では、インテリジェントな実行時処理によって大量データを扱います。

### 1. ガバナ制限の把握
- **実行時チェック**: 実行中にガバナ制限を監視します
- **自動チェーン**: 制限に近づくと次の Queueable へチェーンします
- **典型的な処理量**: Queueable 1 回の実行あたり約 19 レコード
- **完全な処理**: すべてのレコードは最終的にチェーンを通じて処理されます
- **事前バッチ分割なし**: システムが自動的にレコードの分配を処理します

### 2. Notion API レート制限の処理
- **リクエストレート**: 3 リクエスト/秒の制限を遵守します
- **レート制限の検出**: 429 レスポンスを適切に処理します
- **自動的な間隔調整**: リクエスト間に組み込みの遅延があります
- **ガバナベースのスロットリング**: ガバナ制約による自然なレート制限

### 3. アーキテクチャの利点
- 実行時チェック付きの個別レコード処理
- 自己チェーンする Queueable パターン
- 完了後の自動重複排除
- 複雑なバッチサイズ計算が不要
- シンプルで保守しやすいコード構造

## 大量データ同期のアーキテクチャ

本アーキテクチャでは、実行時のガバナ制限チェックを用いて、あらゆるデータ量を自動的に処理します。

### 1. 実行時のガバナ制限チェック

#### 実行時チェックを備えた拡張レートリミッタ

```apex
public class NotionRateLimiter {
    private static final Integer REQUESTS_PER_SECOND = 3;
    
    public class RateLimitException extends Exception {}
    
    /**
     * Check if processing should stop based on governor limits
     * Called during record processing to determine when to chain
     */
    public static Boolean shouldStopProcessing() {
        Integer remainingCallouts = Limits.getLimitCallouts() - Limits.getCallouts();
        Integer remainingCpu = Limits.getLimitCpuTime() - Limits.getCpuTime();
        Decimal heapUsage = Limits.getLimitHeapSize() > 0 ? 
            Decimal.valueOf(Limits.getHeapSize()) / Limits.getLimitHeapSize() : 0;
        
        // Stop if approaching any limit threshold
        Boolean shouldStop = (remainingCallouts < 6) || 
                           (remainingCpu < 5000) || 
                           (heapUsage > 0.85);
        
        if (shouldStop) {
            System.debug('Approaching limits - Callouts remaining: ' + remainingCallouts + 
                       ', CPU remaining: ' + remainingCpu + 'ms, Heap usage: ' + 
                       (heapUsage * 100).setScale(1) + '%');
        }
        
        return shouldStop;
    }
    
    public static void throttleRequest() {
        // Check if we're too close to callout limit
        if (Limits.getCallouts() >= Limits.getLimitCallouts() - 2) {
            throw new RateLimitException(
                String.format('Approaching callout limit ({0}/{1})',
                    new List<Object>{Limits.getCallouts(), Limits.getLimitCallouts()})
            );
        }
        
        // Rate limiting logic for 3 req/sec
        DateTime lastRequest = getLastRequestTime();
        if (lastRequest != null) {
            Long millisecondsSinceLastRequest = DateTime.now().getTime() - lastRequest.getTime();
            Long minimumInterval = 1000 / REQUESTS_PER_SECOND; // 333ms between requests
            
            if (millisecondsSinceLastRequest < minimumInterval) {
                throw new RateLimitException('Rate limit requires delay');
            }
        }
        
        setLastRequestTime(DateTime.now());
    }
    
    public static Map<String, Object> getGovernorLimitStatusMap() {
        return new Map<String, Object>{
            'calloutsUsed' => Limits.getCallouts(),
            'calloutLimit' => Limits.getLimitCallouts(),
            'cpuTimeUsed' => Limits.getCpuTime(),
            'cpuTimeLimit' => Limits.getLimitCpuTime(),
            'heapUsed' => Limits.getHeapSize(),
            'heapLimit' => Limits.getLimitHeapSize()
        };
    }
}
```

### 2. 自己チェーンする Queueable の実装

```apex
public class NotionSyncQueueable implements Queueable, Database.AllowsCallouts {
    private List<NotionSync.Request> allRequests;
    private Integer startIndex;
    private NotionSyncLogger logger;
    private NotionSyncProcessor processor;
    private Set<Id> allRecordIds; // Track all records for deduplication
    private String currentObjectType;
    
    public NotionSyncQueueable(List<NotionSync.Request> requests) {
        this(requests, 0);
    }
    
    public NotionSyncQueueable(List<NotionSync.Request> requests, Integer startIndex) {
        this.allRequests = requests;
        this.startIndex = startIndex != null ? startIndex : 0;
        this.logger = new NotionSyncLogger();
        this.processor = new NotionSyncProcessor(this.logger);
        
        // Extract ALL record IDs for deduplication
        this.allRecordIds = new Set<Id>();
        for (NotionSync.Request request : requests) {
            if (request.operationType != 'DELETE' && String.isNotBlank(request.recordId)) {
                this.allRecordIds.add(request.recordId);
                if (String.isNotBlank(request.objectType)) {
                    this.currentObjectType = request.objectType;
                }
            }
        }
    }
    
    public void execute(QueueableContext context) {
        Integer currentIndex = startIndex;
        
        try {
            System.debug('Starting at index ' + startIndex + ' with ' + 
                       allRequests.size() + ' total requests');
            
            // Process records individually with runtime checking
            while (currentIndex < allRequests.size()) {
                // Check limits BEFORE processing (except first record)
                if (currentIndex > startIndex && NotionRateLimiter.shouldStopProcessing()) {
                    System.debug('Approaching limits at index ' + currentIndex);
                    break;
                }
                
                // Process single record
                NotionSync.Request request = allRequests[currentIndex];
                processSingleRequest(request);
                currentIndex++;
                
                // Log progress
                Map<String, Object> limits = NotionRateLimiter.getGovernorLimitStatusMap();
                System.debug('Processed index ' + (currentIndex - 1) + ': ' +
                           'Callouts: ' + limits.get('calloutsUsed') + '/' + 
                           limits.get('calloutLimit'));
            }
            
            // Chain if more records remain
            if (currentIndex < allRequests.size()) {
                chainNextBatch(currentIndex);
            } else {
                // All done - trigger deduplication
                handleDeduplication();
            }
            
        } finally {
            logger.flush();
        }
    }
    
    private void chainNextBatch(Integer nextIndex) {
        if (!Test.isRunningTest()) {
            System.debug('Chaining next batch starting at index ' + nextIndex);
            System.enqueueJob(new NotionSyncQueueable(allRequests, nextIndex));
        }
    }
    
    private void handleDeduplication() {
        if (!allRecordIds.isEmpty() && String.isNotBlank(currentObjectType)) {
            System.enqueueJob(new NotionDeduplicationQueueable(
                allRecordIds, currentObjectType));
        }
    }
}
```

#### 処理の特性

実行時の制限チェックにより、システムは以下に自動的に対応します。

- **典型的な処理量**: Queueable 1 回の実行あたり約 19 レコード
- **固定バッチサイズなし**: システムが実際の使用状況に基づいてチェーンするタイミングを判断
- **完全な処理**: すべてのレコードは最終的にチェーンを通じて処理されます
- **自然なレート制限**: ガバナ制限が本質的なスロットリングを提供します

### 3. 処理フローの例

システムが大量データセットをどのように扱うかの例を示します。

```
例: 75 件の Account レコードを処理する場合

1. フローが 75 レコードで NotionSyncInvocable を起動
2. NotionSyncInvocable が 75 件のリクエストすべてを含む NotionSyncQueueable をキューイング
3. 1 回目の NotionSyncQueueable 実行:
   - インデックス 0〜18 のレコード(19 件)を処理
   - ガバナ制限のしきい値に到達
   - インデックス 19 から始まる次の Queueable にチェーン
4. 2 回目の NotionSyncQueueable 実行:
   - インデックス 19〜37 のレコード(19 件)を処理
   - ガバナ制限のしきい値に到達
   - インデックス 38 から始まる次の Queueable にチェーン
5. 3 回目の NotionSyncQueueable 実行:
   - インデックス 38〜56 のレコード(19 件)を処理
   - ガバナ制限のしきい値に到達
   - インデックス 57 から始まる次の Queueable にチェーン
6. 4 回目の NotionSyncQueueable 実行:
   - インデックス 57〜74 のレコード(18 件)を処理
   - 全レコード完了
   - 75 件すべてに対して NotionDeduplicationQueueable をキューイング
7. NotionDeduplicationQueueable が実行され重複を処理

合計: 75 レコードを 4 回の Queueable 実行 + 1 回の重複排除で処理
```

### 4. スケジュール同期の実装

定期的な一括同期のための実装例です。

```apex
public class NotionSyncScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Get configured objects for scheduled sync
        List<NotionSyncObject__mdt> syncObjects = [
            SELECT ObjectApiName__c 
            FROM NotionSyncObject__mdt 
            WHERE IsActive__c = true 
            AND EnableScheduledSync__c = true
        ];
        
        for (NotionSyncObject__mdt syncObject : syncObjects) {
            // Query records to sync
            List<SObject> recordsToSync = Database.query(
                'SELECT Id FROM ' + syncObject.ObjectApiName__c + 
                ' WHERE LastModifiedDate >= :DateTime.now().addDays(-1)'
            );
            
            // Create sync requests
            List<NotionSync.Request> requests = new List<NotionSync.Request>();
            for (SObject record : recordsToSync) {
                requests.add(new NotionSync.Request(
                    record.Id, 
                    syncObject.ObjectApiName__c, 
                    'UPDATE'
                ));
            }
            
            // Enqueue for processing
            if (!requests.isEmpty()) {
                System.enqueueJob(new NotionSyncQueueable(requests));
            }
        }
    }
}
```

### 5. 進捗トラッキング

既存の `Notion_Sync_Log__c` オブジェクトが個々のレコードの同期ステータスを追跡します。大規模な同期処理を監視する際には、集計データをクエリできます。

```apex
// Get sync progress for current batch
AggregateResult[] results = [
    SELECT Status__c, COUNT(Id) recordCount
    FROM Notion_Sync_Log__c
    WHERE CreatedDate >= :DateTime.now().addHours(-1)
    GROUP BY Status__c
];

for (AggregateResult ar : results) {
    System.debug(ar.get('Status__c') + ': ' + ar.get('recordCount'));
}
```

### 6. 再試行メカニズム

失敗した同期に対しては、シンプルな再試行メカニズムを実装します。

```apex
public class NotionSyncRetryScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        // Query recent failed sync logs
        List<Notion_Sync_Log__c> failedLogs = [
            SELECT Record_Id__c, Object_Type__c, Retry_Count__c
            FROM Notion_Sync_Log__c
            WHERE Status__c = 'Failed'
            AND CreatedDate >= :DateTime.now().addHours(-24)
            AND Retry_Count__c < 3
            LIMIT 200
        ];
        
        if (!failedLogs.isEmpty()) {
            // Group by object type
            Map<String, List<NotionSync.Request>> requestsByType = 
                new Map<String, List<NotionSync.Request>>();
            
            for (Notion_Sync_Log__c log : failedLogs) {
                if (!requestsByType.containsKey(log.Object_Type__c)) {
                    requestsByType.put(log.Object_Type__c, new List<NotionSync.Request>());
                }
                
                requestsByType.get(log.Object_Type__c).add(
                    new NotionSync.Request(
                        log.Record_Id__c,
                        log.Object_Type__c,
                        'UPDATE'
                    )
                );
            }
            
            // Enqueue retries by object type
            for (List<NotionSync.Request> requests : requestsByType.values()) {
                System.enqueueJob(new NotionSyncQueueable(requests));
            }
        }
    }
}
```

## 実装上のメリット

実行時の制限チェック方式には以下の利点があります。

### 1. シンプル化されたアーキテクチャ
- 単一の Queueable クラスがあらゆるデータ量を処理
- 複雑なバッチサイズ計算が不要
- ガバナ制限への自動適応
- 自己管理型の処理フロー

### 2. 一貫した処理
- すべてのレコード量で同じコードパスを使用
- 予測可能な動作
- テストとデバッグが容易
- データ量による特殊ケースが不要

### 3. 最適なリソース利用
- 1 回の実行あたり最大限のレコードを処理
- ガバナ制約による自然なレート制限
- 効率的な CPU 時間とヒープサイズの使用
- 自動スロットリング

## 利用ガイドライン

### 各アプローチの使い分け

1. **リアルタイムフロー同期**(基本実装 — ARCHITECTURE_REVIEW.md を参照)
   - 単一レコードの操作
   - 小さなバッチ(50 レコード未満)
   - 即時同期が必要な場合
   - ユーザートリガーによる変更

2. **Queueable チェーン**(中量データ向けの拡張)
   - 中規模データセット(50〜1000 レコード)
   - 準リアルタイムが必要な場合
   - 複雑なリレーションシップ処理が必要な場合
   - 一括フロー操作

3. **Batch Apex**(大量データ向けの拡張)
   - 大規模データセット(1000 レコード超)
   - スケジュール/定期同期
   - 初期データ移行
   - 一括データ修正

4. **スケジュール同期**
   - 定期的な同期が必要な場合
   - タイミングがクリティカルでない場合
   - 夜間処理
   - データベース全体のリフレッシュ

## 設定

### 新規メタデータ項目

`NotionSyncObject__mdt` に追加:
- `EnableScheduledSync__c` (チェックボックス)
- `BatchSize__c` (数値、デフォルト: 20)
- `ScheduleCron__c` (テキスト) — スケジューリング用 Cron 式

### Invocable メソッドの拡張

`NotionSyncInvocable` に新規パラメータを追加:
- `syncMode`: 'REALTIME' | 'BATCH' | 'SCHEDULED'
- `batchSize`: 数値(オプション)

## ガバナ制限の管理

### 実行時の制限チェック

システムはガバナ制限を自動的に監視し、対応します。

1. **主な制約**:
   - コールアウト上限: トランザクションあたり 100
   - CPU 時間: 非同期で 60 秒
   - ヒープサイズ: 非同期で 12MB
   - API レート: 3 リクエスト/秒

2. **自動適応**:
   - 各レコード処理前に制限をチェック
   - しきい値に近づくとチェーン
   - 通常は 1 回の実行で約 19 レコードを処理
   - 手動チューニング不要

3. **自然なスロットリング**:
   - ガバナ制限が本質的なレート制限を提供
   - 複雑な遅延機構は不要
   - システムが処理速度を自己調整


### レート制限の処理

システムは自然なガバナ制約を通じてレート制限を処理します。

1. **組み込みのスロットリング**:
   - 約 19 レコードの処理に通常数秒かかる
   - API コール間の自然な間隔
   - ガバナ制限が API への過負荷を防止

2. **429 レスポンスの処理**:
   - 適切に検出・ログ記録
   - 失敗したレコードは後で再試行可能
   - 体系的なリカバリのためにスケジュール再試行ジョブを使用

3. **複雑な遅延が不要**:
   - Queueable チェーンが自然な間隔を提供
   - ガバナ制限が妥当な処理速度を強制
   - 人為的な遅延なしにシステムが自己管理

## 処理の特性

### 実行時の挙動

システムは一貫した処理パターンを示します。

1. **1 回の実行あたりのレコード数**:
   - 制限に達するまで通常約 19 レコード
   - レコードの複雑さによって若干変動
   - 手動の設定は不要

2. **実行時間**:
   - 各 Queueable は数秒間実行
   - API レートに自然に準拠
   - 効率的なリソース利用

3. **スケーラビリティ**:
   - チェーンによりあらゆるデータ量に対応
   - 線形な処理時間
   - 予測可能な動作

## ベストプラクティス

### 1. シンプル化された処理

**自動的な処理**:
- バッチサイズの設定は不要
- 実行時チェックがすべてのデータ量を処理
- レート制限への自然な準拠
- 自己管理型のシステム

### 2. レート制限のモニタリング

**カスタムオブジェクト**: `Notion_API_Usage__c`
```
- Request_Time__c (DateTime)
- Request_Type__c (Text)
- Response_Code__c (Number)
- Rate_Limited__c (Checkbox)
- Retry_After__c (Number)
```

**モニタリングダッシュボード**:
- 分/時間あたりのリクエスト数の推移
- レート制限への到達頻度
- 平均レスポンス時間
- 失敗リクエストのパターン

### 3. スケジューリング戦略

**シンプルなスケジューリング**:
- 標準の Salesforce Schedulable を使用
- 定期的に変更レコードをクエリ
- 処理のためにキューイング
- データ量はシステムに任せる

**例**:
```apex
// Simple scheduled sync
public void execute(SchedulableContext sc) {
    List<Account> modifiedAccounts = [
        SELECT Id FROM Account 
        WHERE LastModifiedDate >= :DateTime.now().addHours(-1)
    ];
    
    if (!modifiedAccounts.isEmpty()) {
        NotionSyncInvocable.syncRecords(modifiedAccounts);
    }
}
```

### 4. エラー処理のベストプラクティス

**レート制限固有の処理**:
- 必ず 429 ステータスコードをチェック
- Retry-After ヘッダーを尊重
- 指数バックオフを実装
- レート制限のパターンを追跡

**一般的なエラー処理**:
- すべてのエラーを完全なコンテキストとともにログ記録
- 一時的な失敗と恒久的な失敗を区別
- 繰り返されるレート制限に対してアラート
- 過剰な 429 発生時には自動停止

### 5. パフォーマンスの最適化

**API コールの削減**:
- リレーションシップ参照を一括で実行
- 頻繁にアクセスするデータをキャッシュ
- 利用可能な場合はバルクエンドポイントを使用
- 不要な更新を最小化

**処理の最適化**:
- 親オブジェクトを先に処理
- リレーションシップの複雑さでレコードをグループ化
- 並列処理は慎重に使用
- CPU 時間とヒープ使用量を監視

## 移行パス

既存の実装からの移行手順:

1. 実行時チェックを備えた新しい NotionSyncQueueable に更新
2. 既存のバッチサイズ設定を削除
3. データ量はシステムに自動的に任せる
4. 同期ログを通じてパフォーマンスを監視

## テスト戦略

1. **単体テスト**
   - 実行時の制限チェックロジックをテスト
   - Queueable チェーンの挙動を検証
   - 完了後の重複排除をテスト

2. **インテグレーションテスト**
   - 実際の Notion API でテスト
   - 大規模データセットの処理を検証
   - 中断と再開をテスト

3. **パフォーマンステスト**
   - 様々なデータ量で同期時間を測定
   - 自動チェーンの挙動を監視
   - ガバナ制限の検出を検証

## モニタリングとアラート

1. **ダッシュボード**
   - 同期パフォーマンスのメトリクス
   - エラー率とパターン
   - API 使用統計

2. **アラート**
   - 同期処理の失敗
   - 高いエラー率
   - 異常な処理パターン

3. **レポート**
   - 日次の同期サマリー
   - 週次のパフォーマンス傾向
   - 月次のデータ量分析
