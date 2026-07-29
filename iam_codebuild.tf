# ------------------------------------------------------------------
# CodeBuild execution role — builds and pushes container images to ECR
# ------------------------------------------------------------------

resource "aws_iam_role" "codebuild" {
  name = "${var.runtime_name}_ac_codebuild-role-${module.helpers.name_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "codebuild_execution" {
  name = "${var.runtime_name}_ac_codebuild_exec-pol-${module.helpers.name_suffix}"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # --- ECR auth token (account-wide, required for docker login) ---
      {
        Sid      = "ECRTokenAccess"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },

      # --- ECR push/pull on the target repository ---
      {
        Sid    = "ECRImageAccess"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeRepositories",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = local.ecr_repository_resources
      },

      # --- CloudWatch Logs for build output ---
      {
        Sid    = "CodeBuildLogGroup"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:DescribeLogGroups"]
        Resource = [
          "${local.logs_arn_prefix}:log-group:/aws/codebuild/*"
        ]
      },
      {
        Sid    = "CodeBuildLogStream"
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "${local.logs_arn_prefix}:log-group:/aws/codebuild/*:log-stream:*"
        ]
      },

      # --- S3 access for CodeBuild source/artifact buckets ---
      {
        Sid    = "CodeBuildS3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::codepipeline-${local.region}-*",
          "arn:aws:s3:::codepipeline-${local.region}-*/*",
          "arn:aws:s3:::bedrock-agentcore-codebuild-sources-${local.account_id}-${local.region}/*"
        ]
      },
    ]
  })
}