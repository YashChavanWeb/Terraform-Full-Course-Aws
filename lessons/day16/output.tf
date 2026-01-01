output "user_names" {
  value = [for user in local.users : "${user.first_name} ${user.last_name}"]
}

output "user_passwords" {
  value = {
    for user, profile in aws_iam_user_login_profile.users :
    user => "Password created - user must reset on first login"
  }
  sensitive = true
}