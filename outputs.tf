output "services" {
  value = local.services
}

output "names_by_tier" {
  value = local.names_by_tier
}

output "scaled" {
  value = local.scaled
}

output "listeners" {
  value = keys(local.listeners)
}

output "subnets" {
  value = local.subnets
}

output "deployments" {
  value = local.deployments
}

output "rendered" {
  value = local.rendered
}

output "count_vs_for_each" {
  value = {
    count_before        = local.count_addresses_before
    count_after_removal = local.count_addresses_after
    for_each_after      = local.for_each_keys_after
  }
}
