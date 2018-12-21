variable "name_prefix" {}

variable "autoscaling_group_name" {}

variable "hook_heartbeat_timeout" {
  default = 900
}

variable "hook_default_result" {
  default = "ABANDON"
}

variable "log_retention_in_days" {
  description = "Log retention of the lambda function"
  default     = "60"
}
