variable "name_prefix" {}

variable "autoscaling_group_name" {}

variable "hook_heartbeat_timeout" {
  default = 900
}

variable "hook_default_result" {
  default = "ABANDON"
}
