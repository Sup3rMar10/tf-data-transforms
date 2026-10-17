# Pure data transformation: no provider, no resources. Every output is covered by tests/, so
# these idioms can be refactored with a safety net.

locals {
  raw = yamldecode(file("${path.module}/data/services.yaml"))

  defaults = {
    tier     = "web"
    replicas = 1
  }

  # 1. Apply defaults, keyed by name. merge() is shallow and later maps win, so the service's own
  #    values override defaults. Nested maps and optional fields are handled explicitly with try().
  services = {
    for s in local.raw.services : s.name => merge(local.defaults, s, {
      env         = try(s.env, {})
      extra_ports = try(s.extra_ports, [])
      health_path = try(s.healthcheck.path, "/healthz")
    })
  }

  # 2. Group by a field. The trailing "..." collects duplicate keys into a list.
  names_by_tier = { for name, s in local.services : s.tier => name... }

  # 3. Filter: only services that need more than one replica.
  scaled = sort([for name, s in local.services : name if s.replicas > 1])

  # 4. Flatten nested lists into one map keyed by a composite string (stable for for_each).
  listeners = {
    for l in flatten([
      for name, s in local.services : [
        for p in concat([s.port], s.extra_ports) : { service = name, port = p }
      ]
    ]) : "${l.service}:${l.port}" => l
  }

  # 5. Allocate subnets deterministically: one /24 per tier, in sorted tier order.
  tiers   = sort(distinct([for s in local.services : s.tier]))
  subnets = zipmap(local.tiers, cidrsubnets("10.20.0.0/16", [for t in local.tiers : 8]...))

  # 6. Cross product: every service in every environment.
  deployments = [for pair in setproduct(["dev", "prod"], sort(keys(local.services))) : "${pair[0]}/${pair[1]}"]

  # 7. Render a text file per service with templatefile().
  rendered = {
    for name, s in local.services : name => templatefile("${path.module}/templates/service.conf.tftpl", {
      name        = name
      tier        = s.tier
      replicas    = s.replicas
      port        = s.port
      health_path = s.health_path
      extra_ports = s.extra_ports
      env_lines   = [for k, v in s.env : "${k}=${v}"]
    })
  }

  # 8. count vs for_each: what happens to addresses when the first item is removed.
  letters                = ["a", "b", "c"]
  count_addresses_before = [for i, v in local.letters : "${i}=${v}"]
  count_addresses_after  = [for i, v in slice(local.letters, 1, 3) : "${i}=${v}"]
  for_each_keys_after    = sort(keys({ for v in slice(local.letters, 1, 3) : v => true }))
}
