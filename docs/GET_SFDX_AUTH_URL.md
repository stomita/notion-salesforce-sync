# DEVHUB_SFDX_AUTH_URLの取得方法

## 前提条件
- Salesforce組織（Developer Edition、Enterprise Edition、またはUnlimited Edition）
- Dev Hubが有効化されていること
- Salesforce CLIがインストールされていること

## 手順

### 1. Salesforce CLIのインストール（未インストールの場合）

```bash
# npmを使用
npm install -g @salesforce/cli

# または、インストーラーを使用
# https://developer.salesforce.com/tools/salesforcecli
```

### 2. Dev Hubの有効化

1. Salesforce組織にログイン
2. 設定 → 開発 → Dev Hub
3. 「Dev Hubを有効化」をON
4. 「ロック解除済みパッケージと第二世代管理パッケージ」もON

### 3. Salesforce CLIでDev Hub組織に認証

```bash
# ブラウザで認証（推奨）
sf org login web --alias my-devhub --set-default-dev-hub

# または、既存の組織に接続
sf org login web --instance-url https://login.salesforce.com --alias my-devhub --set-default-dev-hub
```

ブラウザが開き、Salesforceログイン画面が表示されます。
ログインして「アクセスを許可」をクリックしてください。

### 4. SFDX Auth URLの取得

認証が完了したら、以下のコマンドでAuth URLを取得します：

```bash
# JSON形式で詳細情報を表示
sf org display --target-org my-devhub --verbose --json
```

出力例：
```json
{
  "status": 0,
  "result": {
    "id": "00D5g000004FkWyEAK",
    "accessToken": "00D5g000004FkWy!ARoAQO...",
    "instanceUrl": "https://your-domain.my.salesforce.com",
    "username": "admin@example.com",
    "connectedStatus": "Connected",
    "sfdxAuthUrl": "force://PlatformCLI::5Aep861...[長い文字列]...@your-domain.my.salesforce.com"
  }
}
```

### 5. Auth URLの確認

`sfdxAuthUrl`の値をコピーします。形式は以下のようになります：

```
force://PlatformCLI::[クライアントID]::[リフレッシュトークン]@[インスタンスURL]
```

### 6. Auth URLのテスト（オプション）

取得したAuth URLが正しく動作することを確認：

```bash
# 一時ファイルに保存してテスト
echo "force://PlatformCLI::..." > auth.txt
sf org login sfdx-url --sfdx-url-file auth.txt --alias test-devhub
rm auth.txt

# 組織情報を表示
sf org display --target-org test-devhub
```

## トラブルシューティング

### "No Dev Hub org found"エラー
- Dev Hubが有効化されているか確認
- `--set-default-dev-hub`フラグを使用して認証

### Auth URLが表示されない
- `--verbose`フラグを追加
- Salesforce CLIを最新版にアップデート：`sf update`

### 認証が失敗する
- ブラウザのキャッシュをクリア
- 別のブラウザで試す
- VPNを無効化

## セキュリティ上の注意

⚠️ **SFDX Auth URLは機密情報です**
- パスワードと同等の重要度で管理してください
- 公開リポジトリにコミットしない
- 定期的に更新することを推奨

## Auth URLの無効化

セキュリティ上の理由でAuth URLを無効化する場合：

1. Salesforce組織にログイン
2. 設定 → アプリケーション → 接続アプリケーション → 接続アプリケーションを管理する
3. 「Salesforce CLI」を見つける
4. 「取り消し」をクリック

## 参考リンク

- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/)
- [Dev Hub の有効化](https://developer.salesforce.com/docs/atlas.ja-jp.sfdx_setup.meta/sfdx_setup/sfdx_setup_enable_devhub.htm)
- [SFDX認証](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference_auth.htm)