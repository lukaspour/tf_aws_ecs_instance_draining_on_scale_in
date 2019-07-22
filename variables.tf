variable "region" {
  description = "Region"
  type        = string
}

variable "cluster_name" {
  description = "Name of cluster to be used for draining during scaling"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Name of autoscaling group to be used for draning during scaling"
  type        = string
}

variable "function_sleep_time" {
  description = "Number of seconds the function should sleep before checking ECS Instance Task Count again"
  default = 15
}

variable "lambda_enabled" {
  description = "For some reasons, you could be interested in just uploading the lambda, not making it work"
  type        = bool
  default     = true
}

variable "hook_heartbeat_timeout" {
  description = "Timeout of the heartbeat during the scaling process"
  type        = number
  default     = 900
}

variable "hook_default_result" {
  description = "Default action to apply if the hook timeouts"
  type        = string
  default     = "ABANDON"
}
