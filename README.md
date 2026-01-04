# CI/CD Pipeline for ECS

GitHub Actions による ECS へのCI/CDパイプライン（ECS Native Blue/Green Deployment）

```
GitHub Push → GitHub Actions (Build & Deploy) → ECR → ECS (Native Blue/Green)
```

> **Note**: 以前はCodeDeployを使用していましたが、ECSネイティブのBlue/Greenデプロイメントに移行しました。
> CodeDeployは不要となり、GitHub Actionsから直接ECSサービスを更新します。

### なぜECSネイティブBlue/Greenが推奨されるのか

AWS公式ドキュメント（[Migrating from AWS CodeDeploy to Amazon ECS for blue/green deployments](https://aws.amazon.com/blogs/containers/migrating-from-aws-codedeploy-to-amazon-ecs-for-blue-green-deployments/)）によると、ECSネイティブBlue/Greenには以下の利点があります：

| 観点 | CodeDeploy Blue/Green | ECS Native Blue/Green |
|------|----------------------|----------------------|
| **設定の複雑さ** | 別サービス（CodeDeploy）の設定が必要 | ECSサービス内で完結 |
| **追加料金** | CodeDeployの利用料金 | 追加料金なし |
| **カスタムツール** | 必要な場合あり | 不要 |
| **ロールバック** | CodeDeploy経由 | ECS標準機能 |
| **CloudFormation対応** | 制限あり（ネストスタック不可） | 完全対応 |
| **ECS機能との連携** | 一部制限あり | 完全統合 |

**主な改善点**:
- **Service Discovery対応**: ECSの標準機能と完全統合
- **ライフサイクルフック実行時間**: より長い実行時間をサポート
- **ヘッドレスサービス対応**: ロードバランサーなしでも利用可能
- **Amazon EBS対応**: ステートフルワークロードのサポート

参考: [AWS News Blog - Built-in blue/green deployments in Amazon ECS](https://aws.amazon.com/blogs/aws/accelerate-safe-software-releases-with-new-built-in-blue-green-deployments-in-amazon-ecs/)

### ECSネイティブのデプロイ戦略

ECSデプロイメントコントローラーでは、以下の4つのデプロイ戦略が利用可能です：

| 戦略 | 説明 | ユースケース |
|------|------|-------------|
| **Rolling** | 新旧タスクを並行稼働させながら段階的に入れ替え | デフォルト。シンプルなデプロイ |
| **Blue/Green** | トラフィックを100%一括で新バージョンに切り替え | 即座の切り替えとロールバックが必要な場合 |
| **Canary** | 少量のトラフィック（0.1%〜99.9%）を新バージョンに送り、検証後に全体を移行 | 高リスクな変更の段階的検証 |
| **Linear** | 等間隔でトラフィックを段階的に移行（例: 10%ずつ） | 時間をかけた安定的な移行 |

**Canaryデプロイの設定例**:
```json
{
  "deploymentConfiguration": {
    "deploymentCircuitBreaker": { "enable": true, "rollback": true },
    "alarms": { "alarmNames": ["my-alarm"], "enable": true, "rollback": true }
  },
  "deploymentStrategy": {
    "type": "CANARY",
    "canary": {
      "canaryPercent": 10,
      "canaryBakeTimeInMinutes": 15
    },
    "bakeTimeInMinutes": 30
  }
}
```

**Linearデプロイの設定例**:
```json
{
  "deploymentStrategy": {
    "type": "LINEAR",
    "linear": {
      "stepPercent": 20,
      "stepBakeTimeInMinutes": 10
    },
    "bakeTimeInMinutes": 30
  }
}
```

**共通機能**:
- **Bake Time**: 全トラフィック移行後、旧バージョンを終了するまでの待機時間
- **ライフサイクルフック**: カスタム検証ステップの実行
- **CloudWatch Alarms**: 障害検出時の自動ロールバック
- **Service Connect対応**: サービスメッシュとの完全統合

参考: [Amazon ECS now supports built-in Linear and Canary deployments](https://aws.amazon.com/about-aws/whats-new/2025/10/amazon-ecs-built-in-linear-canary-deployments/)

### AWS CI/CDの進化

AWS CI/CDサービスの最近の動向：

| 時期 | 変更 |
|------|------|
| **2024年7月** | AWS CodeCommit、新規顧客への提供一時停止を発表 |
| **2025年3月** | AWS CodeBuild、GitHub組織/エンタープライズレベルのセルフホストランナー対応 |
| **2025年10月** | ECSネイティブLinear/Canaryデプロイメント対応 |
| **2025年11月** | AWS CodeCommit、GA（一般提供）に復帰 |

> **CodeCommitの復帰について**: 2024年7月の発表後、顧客からのフィードバックを受け、AWSは2025年11月にCodeCommitをGAに復帰させました。
> IAM統合、VPCエンドポイント、CloudTrailログなどの機能が規制産業で重要視されており、Git LFSサポート（2026年Q1予定）などの機能追加も計画されています。

**本プロジェクトのCI/CDアーキテクチャ**:

```
GitHub Actions (Build & Test)
    ↓
ECR (Container Registry)
    ↓
ECS Native Deployment (Rolling/Blue-Green/Canary/Linear)
```

**このアーキテクチャを選択した理由**:
- **GitHub中心の開発フロー**: PRレビュー、Actions、Secretsなど一元管理
- **CodeDeploy不要**: ECSネイティブデプロイメントで完結（設定がシンプル）
- **柔軟なビルド環境**: GitHub Actionsまたはセルフホストランナー

> **Note**: AWS CodeCommit/CodeBuild/CodePipelineも引き続き利用可能です。AWS固有の機能（IAM統合、VPCエンドポイント、CodeGuruレビュー等）が必要な場合や、規制要件でAWS内に閉じる必要がある場合はAWSネイティブのCI/CDサービスが適しています。

参考:
- [The Future of AWS CodeCommit (GA復帰発表)](https://aws.amazon.com/blogs/devops/aws-codecommit-returns-to-general-availability/)
- [AWS CodeBuild now supports GitHub self-hosted runners](https://aws.amazon.com/about-aws/whats-new/2025/03/aws-codebuild-organization-enterprise-level-github-self-hosted-runners/)

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

Fargate、EC2、またはManaged Instancesを選択可能:

```hcl
# terraform.tfvars
launch_type = "fargate"  # fargate, ec2, or managed_instances
```

| 項目 | Fargate | EC2 | Managed Instances |
|-----|---------|-----|-------------------|
| 管理 | フルマネージド | インスタンス管理必要 | AWSがEC2を自動管理 |
| コスト | 高め | 低め (Reserved/Spot利用可) | 中程度 |
| 起動速度 | 速い | やや遅い | やや遅い |
| スケーリング | 自動 | ASG設定必要 | Capacity Provider自動管理 |
| 削除の容易さ | 簡単 | 普通 | ⚠️ 注意が必要 |

### Managed Instances設定例

```hcl
# terraform.tfvars
launch_type = "managed_instances"
managed_instances_vcpu_range   = { min = 1, max = 2 }
managed_instances_memory_range = { min = 1024, max = 4096 }
```

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

### ECSデプロイ失敗

→ ECSサービスのイベントとデプロイ状態を確認:
```bash
# サービスイベントを確認
aws ecs describe-services \
  --cluster cicd-pipeline-dev-cluster \
  --services cicd-pipeline-dev-service \
  --query 'services[0].events[:5]'

# デプロイ状態を確認
aws ecs describe-services \
  --cluster cicd-pipeline-dev-cluster \
  --services cicd-pipeline-dev-service \
  --query 'services[0].deployments'
```

> **Note**: ECSネイティブBlue/Greenデプロイメントを使用しているため、CodeDeployは使用していません。
> デプロイはGitHub Actionsから `aws ecs update-service` で直接実行されます。

### Managed Instances削除が失敗する

`terraform destroy` 実行時にManaged Instancesが削除されない場合があります。

**原因**: ECS Managed InstancesはTerraformの依存関係グラフで完全に表現できない複雑なライフサイクルを持っています:

1. **依存関係の順序問題**: TerraformがIAMロールを先に削除すると、ECS ServiceがALBからターゲットを登録解除できなくなる
2. **Capacity Providerのライフサイクル**: Service停止→タスク停止→Container Instance登録解除→EC2終了→Capacity Provider削除の順序が必要
3. **EC2終了保護**: Managed InstancesはECS自身のみが終了可能（直接の`ec2:TerminateInstances`は拒否される）

**解決策**:

```bash
# 1. Capacity Providerの状態を確認
aws ecs describe-capacity-providers \
  --capacity-providers cicd-pipeline-dev-capacity-provider \
  --query 'capacityProviders[0].{status:status,updateStatus:updateStatus}'

# 2. Container Instanceを強制的に登録解除
INSTANCE_ARN=$(aws ecs list-container-instances \
  --cluster cicd-pipeline-dev-cluster \
  --query 'containerInstanceArns[0]' --output text)

aws ecs deregister-container-instance \
  --cluster cicd-pipeline-dev-cluster \
  --container-instance $INSTANCE_ARN \
  --force

# 3. EC2インスタンスの終了を待つ（ECSが自動終了）
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*ecs*" \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name}'

# 4. Capacity Providerを削除
aws ecs delete-capacity-provider \
  --capacity-provider cicd-pipeline-dev-capacity-provider

# 5. terraform destroyを再実行
terraform destroy
```

**予防策**: `terraform destroy`の前にサービスを0にスケールダウン:
```bash
aws ecs update-service \
  --cluster cicd-pipeline-dev-cluster \
  --service cicd-pipeline-dev-service \
  --desired-count 0

# サービスが安定するまで待機
aws ecs wait services-stable \
  --cluster cicd-pipeline-dev-cluster \
  --services cicd-pipeline-dev-service

# その後destroy
terraform destroy
```

> **Note**: FargateではCapacity ProviderやManaged Instanceがないため、この問題は発生しません。

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
