# ------------------------------------------------------------------
# AgentCore Runtime execution role
# ------------------------------------------------------------------

resource "aws_iam_role" "agentcore_runtime" {
  name = "${var.runtime_name}_ac_runtime-role-${module.helpers.name_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AssumeRolePolicy"
        Effect = "Allow"
        Principal = {
          Service = "bedrock-agentcore.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "${local.agentcore_arn_prefix}:*"
          }
        }
      }
    ]
  })

  tags = local.tags
}

# ------------------------------------------------------------------
# Policy 1: Runtime execution (ECR, Logs, X-Ray, Metrics, Bedrock,
#            Memory, Identity, Code Interpreter)
# ------------------------------------------------------------------

resource "aws_iam_role_policy" "runtime_execution" {
  name = "${var.runtime_name}_ac_runtime_exec-pol-${module.helpers.name_suffix}"
  role = aws_iam_role.agentcore_runtime.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # --- ECR image pull ---
      [
        {
          Sid      = "ECRImageAccess"
          Effect   = "Allow"
          Action   = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
          Resource = local.ecr_repository_resources
        },
        {
          Sid      = "ECRTokenAccess"
          Effect   = "Allow"
          Action   = ["ecr:GetAuthorizationToken"]
          Resource = "*"
        },
      ],

      # --- CloudWatch Logs ---
      [
        {
          Sid    = "LogGroupAccess"
          Effect = "Allow"
          Action = ["logs:DescribeLogStreams", "logs:CreateLogGroup"]
          Resource = [
            "${local.logs_arn_prefix}:log-group:/aws/bedrock-agentcore/runtimes/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["logs:DescribeLogGroups"]
          Resource = ["${local.logs_arn_prefix}:log-group:*"]
        },
        {
          Sid    = "LogStreamAccess"
          Effect = "Allow"
          Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = [
            "${local.logs_arn_prefix}:log-group:/aws/bedrock-agentcore/runtimes/*:log-stream:*"
          ]
        },
      ],

      # --- Observability: X-Ray + CloudWatch Metrics ---
      [
        {
          Sid    = "XRayAccess"
          Effect = "Allow"
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords",
            "xray:GetSamplingRules",
            "xray:GetSamplingTargets"
          ]
          Resource = ["*"]
        },
        {
          Sid       = "CloudWatchMetrics"
          Effect    = "Allow"
          Action    = ["cloudwatch:PutMetricData"]
          Resource  = "*"
          Condition = { StringEquals = { "cloudwatch:namespace" = "bedrock-agentcore" } }
        },
      ],

      # --- AgentCore Runtime invocation (agent-to-agent calls) ---
      [
        {
          Sid    = "AgentCoreRuntimeInvoke"
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:InvokeAgentRuntime",
            "bedrock-agentcore:InvokeAgentRuntimeForUser"
          ]
          Resource = ["${local.agentcore_arn_prefix}:runtime/*"]
        },
      ],

      # --- Bedrock model invocation ---
      [
        {
          Sid    = "BedrockModelInvocation"
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream",
            "bedrock:ApplyGuardrail"
          ]
          Resource = [
            "arn:aws:bedrock:*::foundation-model/*",
            "arn:aws:bedrock:*:*:inference-profile/*",
            "arn:aws:bedrock:${local.region}:${local.account_id}:*"
          ]
        },
      ],

      # --- AgentCore Memory (conditional) ---
      local.memory_statements,

      # --- AgentCore Code Interpreter (conditional) ---
      local.code_interpreter_statements,
    )
  })
}

# ------------------------------------------------------------------
# Policy 2: AgentCore Identity access
# ------------------------------------------------------------------

resource "aws_iam_role_policy" "identity_access" {
  name = "${var.runtime_name}_ac_identity-pol-${module.helpers.name_suffix}"
  role = aws_iam_role.agentcore_runtime.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WorkloadAccessToken"
        Effect = "Allow"
        Action = [
          "bedrock-agentcore:GetWorkloadAccessToken",
          "bedrock-agentcore:GetWorkloadAccessTokenForJWT",
          "bedrock-agentcore:GetWorkloadAccessTokenForUserId"
        ]
        Resource = [
          "${local.agentcore_arn_prefix}:workload-identity-directory/default",
          "${local.agentcore_arn_prefix}:workload-identity-directory/default/workload-identity/*"
        ]
      },
      {
        Sid    = "GetResourceApiKey"
        Effect = "Allow"
        Action = ["bedrock-agentcore:GetResourceApiKey"]
        Resource = [
          "${local.agentcore_arn_prefix}:token-vault/default",
          "${local.agentcore_arn_prefix}:token-vault/default/apikeycredentialprovider/*",
          "${local.agentcore_arn_prefix}:workload-identity-directory/default",
          "${local.agentcore_arn_prefix}:workload-identity-directory/default/workload-identity/${var.runtime_name}-*"
        ]
      },
      {
        Sid    = "GetResourceOauth2Token"
        Effect = "Allow"
        Action = ["bedrock-agentcore:GetResourceOauth2Token"]
        Resource = [
          "${local.agentcore_arn_prefix}:token-vault/default",
          "${local.agentcore_arn_prefix}:token-vault/default/oauth2credentialprovider/*",
          "${local.agentcore_arn_prefix}:workload-identity-directory/default",
          "${local.agentcore_arn_prefix}:workload-identity-directory/default/workload-identity/${var.runtime_name}-*"
        ]
      },
      {
        Sid    = "IdentityOauth2Secrets"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:bedrock-agentcore-identity!default/oauth2/*"
        ]
      },
    ]
  })
}

# ------------------------------------------------------------------
# Policy 3: Secrets Manager access for API key credential providers
# Only created when api_key_credential_names is non-empty.
# ------------------------------------------------------------------

resource "aws_iam_role_policy" "secrets_access" {
  count = length(var.api_key_credential_names) > 0 ? 1 : 0

  name = "${var.runtime_name}_ac_secrets-pol-${module.helpers.name_suffix}"
  role = aws_iam_role.agentcore_runtime.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ApiKeySecretsAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = local.api_key_secret_arns
      }
    ]
  })
}