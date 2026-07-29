# Inputs into this module

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "environment" {
  type        = string
  description = "The name of the environment in which this module is being invoked"
  validation {
    condition     = contains(["sand", "dev", "uat", "perf", "stage", "prod", "core", "shared"], var.environment)
    error_message = "Environment must be one of sand, dev, uat, perf, stage, prod, core or shared."
  }
}

variable "runtime_name" {
  type        = string
  description = "The name of the AgentCore runtime. Used to name IAM resources and scope policies."
  validation {
    condition     = can(regex("^[a-z0-9_]+$", var.runtime_name))
    error_message = "Runtime name must be numbers, lowercase letters and underscores."
  }
}

variable "ecr_repository_arns" {
  type        = list(string)
  description = "ECR repository ARN(s) the runtime role is allowed to pull images from. Defaults to all repositories in the account."
  default     = []
}

variable "api_key_credential_names" {
  type        = list(string)
  description = "Names of API key credential providers whose Secrets Manager secrets the runtime may read (e.g. [\"TAVILY_API_KEY\"]). Leave empty if no external API keys are used."
  default     = []
}

variable "enable_code_interpreter" {
  type        = bool
  description = "Grant the runtime role permissions for AgentCore Code Interpreter."
  default     = false
}

variable "enable_memory" {
  type        = bool
  description = "Grant the runtime role permissions for AgentCore Memory."
  default     = true
}

# Tags to add on to the default set on the provider
variable "tags" {
  type        = map(string)
  description = "Additional tags to be applied to all resources created by this module"
  default     = {}
}

variable "account_shortname" {
  type        = string
  description = "Optional short name for the current account, used in resource name suffixes. Falls back to the raw account ID when not set."
  default     = null
}
