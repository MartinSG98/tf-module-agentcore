# tf-module-agentcore

This module creates the IAM roles needed to run an agent on Amazon Bedrock AgentCore:

* a **runtime execution role**, assumed by the AgentCore service to run your agent container. It can pull the container image from ECR, write logs, traces and metrics, invoke Bedrock models (and other agent runtimes for agent-to-agent calls), and use AgentCore Identity. Memory and Code Interpreter permissions are toggled with inputs.
* a **CodeBuild role** for building and pushing the agent container image to ECR, with logging and access to the standard CodeBuild source/artifact buckets.

The runtime role's trust policy is restricted to the AgentCore service in the current account, so it cannot be assumed cross-account.

## Inputs

* `environment`: the name of the environment in which this module is being invoked.
* `runtime_name`: the name of the AgentCore runtime. Used to name IAM resources and scope policies.
* `account_shortname`: optional short name for the current account, used in resource name suffixes.
* `ecr_repository_arns`: ECR repository ARN(s) the roles may pull from (and CodeBuild may push to). Defaults to all repositories in the account.
* `api_key_credential_names`: names of API key credential providers whose Secrets Manager secrets the runtime may read (e.g. `["TAVILY_API_KEY"]`). Leave empty if no external API keys are used.
* `enable_memory`: grant the runtime role permissions for AgentCore Memory. Default `true`.
* `enable_code_interpreter`: grant the runtime role permissions for AgentCore Code Interpreter. Default `false`.
* `tags`: additional tags to be applied to all resources created by this module.

## Outputs

* `runtime_role_arn`, `runtime_role_name`: the AgentCore runtime execution role.
* `codebuild_role_arn`, `codebuild_role_name`: the CodeBuild role for container image builds.

## Example

```hcl
module "agent_iam" {
  source = "git::https://github.com/MartinSG98/tf-module-agentcore.git?ref=1.0.0"

  environment  = var.environment
  runtime_name = "myagent"

  ecr_repository_arns      = [aws_ecr_repository.agent.arn]
  api_key_credential_names = ["TAVILY_API_KEY"]
  enable_code_interpreter  = true

  tags = local.tags
}
```
