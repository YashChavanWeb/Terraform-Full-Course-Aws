variable "bucket_names" {
  type = list(string)
  default = ["yashchavanweb.bucket-1", "yashchavanweb.bucket-2", "yashchavanweb.bucket-3"]
}

variable "bucket_names_set" {
  type = set(string)
 default = ["yashchavanweb.bucket-1", "yashchavanweb.bucket-2", "yashchavanweb.bucket-3"]
}