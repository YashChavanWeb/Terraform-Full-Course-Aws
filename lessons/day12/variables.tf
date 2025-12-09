variable "instance_type" {
  default = "t2.micro"

  # validation 1 - length
  validation {
   condition = length(var.instance_type) >= 2 && length(var.instance_type) <= 20
   error_message = "Instance type must be between 2 and 20 characters long"
  }
  # validation 2 - allowed values only t2 and t3 instances
  validation {
    # so here we can use regular expression (regex)
    condition = can(regex("^t[2-3]\\.", var.instance_type))
    error_message = "Instance type must be t2 or t3"
  }
}


variable "backup_name" {
    default = "daily_backup"
    validation {
        condition = endswith(var.backup_name, "_backup")
        error_message = "Backup name must end with '_backup'"
    }
}

variable "credentials" {
  default = "xyz123"
  sensitive = true
}

variable "monthly_cost" {
  default = [-50,300,12,-10,21]
}