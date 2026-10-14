# tf-module-agentcore

Creates the IAM roles an agent needs to run on Amazon Bedrock AgentCore. It does not create the runtime itself, only the two roles (and their policies) that the runtime and the build of its container image use:

- **The runtime execution role** (`<runtime_name>_ac_runtime-role-<suffix>`) is assumed by the AgentCore service to run your agent container. It can pull the image from ECR, write logs under `/aws/bedrock-agentcore/runtimes/`, send X-Ray traces and CloudWatch metrics in the `bedrock-agentcore` namespace, invoke Bedrock foundation models and inference profiles and apply guardrails, invoke other agent runtimes in the account for agent-to-agent calls, and use AgentCore Identity for workload access tokens, API keys and OAuth2 tokens. Memory permissions are on by default and Code Interpreter permissions are off, and inputs switch both.
- **The CodeBuild role** (`<runtime_name>_ac_codebuild-role-<suffix>`) builds the agent's container image and pushes it to ECR. It can write build logs under `/aws/codebuild/` and read and write the CodeBuild source and artifact buckets (`codepipeline-<region>-*` and `bedrock-agentcore-codebuild-sources-<account>-<region>`).

The runtime role's trust policy only accepts the AgentCore service acting for the same account (`aws:SourceAccount` and `aws:SourceArn` conditions), so it cannot be assumed cross-account. The module uses [tf-module-helpers](https://github.com/MartinSG98/tf-module-helpers) for the name suffix, the account ID and the region. It needs the AWS provider 6.x.

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

## Secrets

The runtime role can always read the OAuth2 secrets AgentCore Identity keeps under `bedrock-agentcore-identity!default/oauth2/`. For API keys, list the names of the credential providers in `api_key_credential_names`. The module then adds a third policy that lets the runtime read and describe the matching secrets under `bedrock-agentcore-identity!default/apikey/<name>`. With the list empty that policy is not created.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `environment` | `string` | required | Environment the module is used in: `sand`, `dev`, `uat`, `perf`, `stage`, `prod`, `core` or `shared` |
| `runtime_name` | `string` | required | Name of the AgentCore runtime, in lower-case letters, digits and underscores. Used in the role and policy names and to scope the Identity permissions |
| `account_shortname` | `string` | `null` | Short name for the current account in name suffixes. Falls back to the account ID |
| `ecr_repository_arns` | `list(string)` | `[]` | ECR repositories the runtime may pull from and CodeBuild may push to. Empty means every repository in the account |
| `api_key_credential_names` | `list(string)` | `[]` | API key credential providers whose secrets the runtime may read, for example `["TAVILY_API_KEY"]`. Leave empty if the agent uses no external API keys |
| `enable_memory` | `bool` | `true` | Give the runtime role permissions for AgentCore Memory |
| `enable_code_interpreter` | `bool` | `false` | Give the runtime role permissions for AgentCore Code Interpreter |
| `tags` | `map(string)` | `{}` | Extra tags for the roles. An `InfraModule` tag is added with `tf-module-agentcore`, followed by any `InfraModule` value you pass here |

## Outputs

| Name | Description |
|---|---|
| `runtime_role_arn` | ARN of the AgentCore runtime execution role |
| `runtime_role_name` | Name of the AgentCore runtime execution role |
| `codebuild_role_arn` | ARN of the CodeBuild role for container image builds |
| `codebuild_role_name` | Name of the CodeBuild role for container image builds |
