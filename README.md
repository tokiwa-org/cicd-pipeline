# CI/CD Pipeline for ECS Fargate

AWS ECS Fargate へのハイブリッドCI/CDパイプライン

```
GitHub → GitHub Actions (CI) → ECR → CodePipeline (CD) → ECS Fargate
```

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────────┐
│                       CI/CD Pipeline Architecture                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────┐    ┌──────────────────┐    ┌─────────┐                 │
│  │ GitHub  │───▶│  GitHub Actions  │───▶│   ECR   │                 │
│  │  Push   │    │  (Build & Test)  │    │ (Image) │                 │
│  └─────────┘    └──────────────────┘    └────┬────┘                 │
│                                              │                       │
│                                              ▼                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      AWS CodePipeline                          │  │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐                    │  │
│  │  │   Dev   │───▶│ Staging │───▶│  Prod   │                    │  │
│  │  │ Deploy  │    │ Deploy  │    │ Deploy  │                    │  │
│  │  └─────────┘    └────┬────┘    └────┬────┘                    │  │
│  │                      │              │                          │  │
│  │                [Approval]     [Approval]                       │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    ECS Fargate Clusters                        │  │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐                    │  │
│  │  │   dev   │    │ staging │    │  prod   │                    │  │
│  │  └─────────┘    └─────────┘    └─────────┘                    │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## 技術スタック

| コンポーネント | 技術 |
|--------------|------|
| CI (テスト・ビルド) | GitHub Actions |
| コンテナレジストリ | Amazon ECR |
| CD (デプロイ) | CodePipeline + CodeDeploy |
| コンテナ実行環境 | ECS Fargate |
| IaC | Terraform |
| デプロイ戦略 | Blue/Green |

## ディレクトリ構造

```
cicd-pipeline/
├── .github/workflows/          # GitHub Actions
│   ├── ci.yml                  # PRテスト
│   └── build-push.yml          # ビルド・ECRプッシュ
├── terraform/
│   ├── modules/
│   │   ├── vpc/               # VPCネットワーク
│   │   ├── ecr/               # ECRリポジトリ
│   │   ├── ecs/               # ECSクラスタ・サービス
│   │   ├── alb/               # Application Load Balancer
│   │   └── codepipeline/      # CodePipeline + CodeDeploy
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── app/                        # Node.js/TypeScriptアプリ
│   ├── src/
│   ├── Dockerfile
│   └── package.json
├── taskdef.json               # ECSタスク定義テンプレート
├── appspec.yml                # CodeDeploy設定
└── README.md
```

## セットアップ

### 前提条件

- AWS CLI v2
- Terraform >= 1.5.0
- Node.js >= 20.0.0
- Docker

### 1. Terraform State用S3バケットとDynamoDBテーブルの作成

```bash
# S3バケット作成
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region ap-northeast-1 \
  --create-bucket-configuration LocationConstraint=ap-northeast-1

# バージョニング有効化
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

# DynamoDBテーブル作成（ロック用）
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-northeast-1
```

### 2. 設定ファイルの更新

1. `terraform/environments/*/terraform.tfvars` を編集:
   - `github_owner`: GitHubユーザー名/組織名
   - `github_repo`: リポジトリ名

2. `terraform/environments/*/main.tf` の backend 設定を更新:
   - `bucket`: 作成したS3バケット名

### 3. Terraformでインフラ構築

```bash
# dev環境
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# staging環境
cd ../staging
terraform init
terraform plan
terraform apply

# prod環境
cd ../prod
terraform init
terraform plan
terraform apply
```

### 4. GitHub Secretsの設定

リポジトリのSettings > Secrets and variablesで以下を設定:

| Secret名 | 説明 |
|---------|------|
| `AWS_ROLE_ARN` | GitHub Actions用IAMロールARN |
| `AWS_ACCOUNT_ID` | AWSアカウントID |
| `ARTIFACTS_BUCKET` | パイプラインアーティファクト用S3バケット名 |

### 5. 初回デプロイ

```bash
# アプリのビルドテスト
cd app
npm ci
npm run lint
npm run test
npm run build

# Dockerイメージビルドテスト
docker build -t cicd-pipeline-app:test .
docker run -p 3000:3000 cicd-pipeline-app:test
```

## CI/CDフロー

### PRマージ前（CI）

1. `app/`配下のコード変更でPR作成
2. GitHub Actionsが自動実行:
   - Lint
   - Unit Test
   - Build
   - Security Scan

### mainブランチマージ後（CD）

1. GitHub Actionsがビルド・ECRプッシュ
2. `imageDetail.json`をS3にアップロード
3. CodePipelineがトリガー
4. 環境別デプロイ:
   - **dev**: 自動デプロイ
   - **staging**: 手動承認後デプロイ
   - **prod**: 手動承認後デプロイ

## Blue/Greenデプロイ

各環境でBlue/Greenデプロイを実施:

1. 新バージョンをGreenターゲットグループにデプロイ
2. テストリスナー(port 8080)で検証
3. 本番リスナー(port 80)を切り替え
4. 一定時間後にBlue(旧バージョン)を終了

### ロールバック

問題発生時はCodeDeployから自動/手動ロールバック可能。

## ローカル開発

```bash
cd app

# 依存関係インストール
npm ci

# 開発サーバー起動
npm run dev

# テスト実行
npm test

# ビルド
npm run build

# Dockerビルド
docker build -t cicd-pipeline-app:local .
docker run -p 3000:3000 cicd-pipeline-app:local
```

## 環境別設定

| 環境 | VPC CIDR | タスク数 | CPU | Memory | 承認 |
|-----|----------|---------|-----|--------|------|
| dev | 10.0.0.0/16 | 1 | 256 | 512MB | 自動 |
| staging | 10.1.0.0/16 | 2 | 256 | 512MB | 手動 |
| prod | 10.2.0.0/16 | 3 | 512 | 1024MB | 手動 |

## コスト概算

| リソース | dev | staging | prod |
|---------|-----|---------|------|
| Fargate | ~$10/月 | ~$20/月 | ~$60/月 |
| ALB | ~$20/月 | ~$20/月 | ~$20/月 |
| NAT Gateway | ~$35/月 | ~$35/月 | ~$35/月 |
| **合計** | ~$65/月 | ~$75/月 | ~$115/月 |

## トラブルシューティング

### GitHub Actions OIDC認証エラー

```
Error: Could not assume role with OIDC
```

解決策:
1. IAMロールの信頼ポリシーを確認
2. GitHubリポジトリ名が正しいか確認

### CodeDeployデプロイ失敗

```
The deployment failed because a specified file already exists
```

解決策:
1. ECSサービスのタスク定義を確認
2. appspec.ymlのコンテナ名を確認

### ECSタスク起動失敗

```
Task stopped: CannotPullContainerError
```

解決策:
1. ECRリポジトリにイメージが存在するか確認
2. ECSタスク実行ロールにECR権限があるか確認

## ライセンス

MIT
