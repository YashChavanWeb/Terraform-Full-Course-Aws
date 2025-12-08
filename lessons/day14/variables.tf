variable "bucket_name" {
  default = "yashchavanweb12123"
}

variable "domain_name" {
  description = "The domain name for the website (e.g., example.com)"
  type        = string
  default     = ""  # Set your domain name here or pass via terraform.tfvars
}

variable "route53_zone_id" {
  description = "The Route 53 hosted zone ID for the domain"
  type        = string
  default     = ""  # Set your hosted zone ID here or pass via terraform.tfvars
}

variable "create_route53_record" {
  description = "Whether to create Route 53 record (set to false if you don't have a domain)"
  type        = bool
  default     = false
}

