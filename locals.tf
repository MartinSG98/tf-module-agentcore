locals {
  # Used to tag all resources created by the module
  tags = merge(
    var.tags,
    { "InfraModule" = join(":", compact(["tf-module-agentcore", lookup(var.tags, "InfraModule", "")])) }
  )

  account_id = module.helpers.account_id
  region     = module.helpers.region_name

  # Common ARN prefixes used across policies
  agentcore_arn_prefix = "arn:aws:bedrock-agentcore:${local.region}:${local.account_id}"
  logs_arn_prefix      = "arn:aws:logs:${local.region}:${local.account_id}"

  # ECR repository resources — default to all repos in the account when none are specified
  ecr_repository_resources = length(var.ecr_repository_arns) > 0 ? var.ecr_repository_arns : [
    "arn:aws:ecr:${local.region}:${local.account_id}:repository/*"
  ]

  # Secrets Manager ARNs for each API key credential provider
  api_key_secret_arns = [
    for name in var.api_key_credential_names :
    "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:bedrock-agentcore-identity!default/apikey/${name}*"
  ]

  # Conditional IAM statement blocks — built as locals so that concat/flatten
  # does not hit Terraform's "inconsistent conditional result types" error.
  memory_statements = var.enable_memory ? [
    {
      Sid      = "AgentCoreMemoryCreate"
      Effect   = "Allow"
      Action   = ["bedrock-agentcore:CreateMemory"]
      Resource = ["*"]
    },
    {
      Sid    = "AgentCoreMemory"
      Effect = "Allow"
      Action = [
        "bedrock-agentcore:CreateEvent",
        "bedrock-agentcore:GetEvent",
        "bedrock-agentcore:GetMemory",
        "bedrock-agentcore:GetMemoryRecord",
        "bedrock-agentcore:ListActors",
        "bedrock-agentcore:ListEvents",
        "bedrock-agentcore:ListMemoryRecords",
        "bedrock-agentcore:ListSessions",
        "bedrock-agentcore:DeleteEvent",
        "bedrock-agentcore:DeleteMemoryRecord",
        "bedrock-agentcore:RetrieveMemoryRecords"
      ]
      Resource = ["${local.agentcore_arn_prefix}:memory/*"]
    },
  ] : []

  code_interpreter_statements = var.enable_code_interpreter ? [
    {
      Sid    = "AgentCoreCodeInterpreter"
      Effect = "Allow"
      Action = [
        "bedrock-agentcore:CreateCodeInterpreter",
        "bedrock-agentcore:StartCodeInterpreterSession",
        "bedrock-agentcore:InvokeCodeInterpreter",
        "bedrock-agentcore:StopCodeInterpreterSession",
        "bedrock-agentcore:DeleteCodeInterpreter",
        "bedrock-agentcore:ListCodeInterpreters",
        "bedrock-agentcore:GetCodeInterpreter",
        "bedrock-agentcore:GetCodeInterpreterSession",
        "bedrock-agentcore:ListCodeInterpreterSessions"
      ]
      Resource = [
        "arn:aws:bedrock-agentcore:${local.region}:aws:code-interpreter/*",
        "${local.agentcore_arn_prefix}:code-interpreter/*",
        "${local.agentcore_arn_prefix}:code-interpreter-custom/*"
      ]
    },
  ] : []
}
