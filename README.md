# CI/CD Pipeline for ECS

GitHub Actions + CodePipeline による ECS へのCI/CDパイプライン

```
GitHub Push → GitHub Actions (Build) → ECR → S3 → CodePipeline → ECS (Blue/Green)
```

## 前提条件

- AWS CLI v2 (認証済み)
- Terraform >= 1.0.0
- GitHub CLI (`gh auth login` 済み)
- Docker

## クイックスタート

### 1. Bootstrap (初回のみ)

Terraform State用のS3/DynamoDB、GitHub OIDC認証、GitHub Secretsを作成:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

作成されるリソース:
- S3バケット (Terraform State)
- DynamoDB (State Lock)
- GitHub OIDC Provider
- IAM Role (GitHub Actions用)
- GitHub Secrets (AWS_ROLE_ARN, AWS_ACCOUNT_ID, ARTIFACTS_BUCKET)

### 2. Dev環境デプロイ

```bash
cd terraform/environments/dev
terraform init
terraform apply
```

### 3. アプリデプロイ (GitHub Actions)

コードをpushするとGitHub Actionsが自動実行:

```bash
git add .
git commit -m "Deploy"
git push
```

または手動トリガー:
```bash
gh workflow run build-push.yml
```

### 4. 動作確認

```bash
# ALB URLを取得
cd terraform/environments/dev
terraform output alb_dns_name

# ヘルスチェック
curl http://<alb-dns>/health
```

## ECS Launch Type

FargateまたはEC2を選択可能:

```hcl
# terraform.tfvars
launch_type = "fargate"  # または "ec2"
```

| 項目 | Fargate | EC2 |
|-----|---------|-----|
| 管理 | フルマネージド | インスタンス管理必要 |
| コスト | 高め | 低め (Reserved/Spot利用可) |
| 起動速度 | 速い | やや遅い |

## 環境別デプロイ

```bash
# Staging (手動承認あり)
cd terraform/environments/staging
terraform apply

# Production (手動承認あり)
cd terraform/environments/prod
terraform apply
```

## リソース削除

全てのリソースは `terraform destroy` で削除可能:

```bash
# 環境削除
cd terraform/environments/dev
terraform destroy

# Bootstrap削除 (最後に実行)
cd terraform/bootstrap
terraform destroy
```

## ディレクトリ構成

```
├── app/                     # Node.js アプリケーション
├── terraform/
│   ├── bootstrap/           # State管理 + GitHub OIDC
│   ├── modules/
│   │   ├── vpc/            # VPC/Subnet/NAT
│   │   ├── alb/            # ALB + Target Groups
│   │   ├── ecr/            # Container Registry
│   │   ├── ecs/            # Cluster/Service/Task
│   │   └── codepipeline/   # Pipeline + CodeDeploy
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
├── .github/workflows/
│   ├── ci.yml              # PR時のテスト
│   └── build-push.yml      # Build → ECR → S3
├── taskdef.json            # ECS Task Definition
└── appspec.yml             # CodeDeploy設定
```

## トラブルシューティング

### GitHub Actions OIDC認証エラー

```
Error: Could not assume role with OIDC
```

→ Bootstrap が正しく適用されているか確認:
```bash
cd terraform/bootstrap
terraform apply
```

### ECSタスク起動失敗

```
CannotPullContainerError
```

→ ECRにイメージがあるか確認:
```bash
aws ecr list-images --repository-name cicd-pipeline-dev-app
```

→ なければGitHub Actionsを実行:
```bash
gh workflow run build-push.yml
```

### CodeDeployデプロイ失敗

→ ECSサービスのイベントを確認:
```bash
aws ecs describe-services \
  --cluster cicd-pipeline-dev-cluster \
  --services cicd-pipeline-dev-service \
  --query 'services[0].events[:5]'
```

## ローカル開発

```bash
cd app
npm ci
npm run dev      # 開発サーバー (port 3000)
npm test         # テスト実行
npm run build    # ビルド

# Dockerビルド
docker build -t app:local .
docker run -p 3000:3000 app:local
```
