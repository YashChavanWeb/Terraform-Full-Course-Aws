locals {
    positive_cost = [for cost in var.monthly_cost : abs(cost)]
    max_cost = max(local.positive_cost...)
    min_cost = min(local.positive_cost...)

    config_file_exists= fileexists("./config.json")
    config_data = local.config_file_exists ? jsondecode(file("./config.json")) : null   
}