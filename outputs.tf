# Outputs from this module

# AgentCore Runtime role
output "runtime_role_arn" {
  value       = aws_iam_role.agentcore_runtime.arn
  description = "ARN of the IAM role for the AgentCore runtime"
}

output "runtime_role_name" {
  value       = aws_iam_role.agentcore_runtime.name
  description = "Name of the IAM role for the AgentCore runtime"
}

# CodeBuild role
output "codebuild_role_arn" {
  value       = aws_iam_role.codebuild.arn
  description = "ARN of the IAM role for CodeBuild (container image builds)"
}

output "codebuild_role_name" {
  value       = aws_iam_role.codebuild.name
  description = "Name of the IAM role for CodeBuild (container image builds)"
}
