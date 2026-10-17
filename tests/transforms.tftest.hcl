run "defaults_are_applied" {
  command = plan

  assert {
    condition     = output.services["api"].replicas == 1 && output.services["worker"].replicas == 4
    error_message = "api should get the default of 1 replica, worker keeps its own 4"
  }

  assert {
    condition     = output.services["cache"].health_path == "/ping" && output.services["api"].health_path == "/healthz"
    error_message = "explicit healthcheck path wins, otherwise /healthz"
  }

  assert {
    condition     = output.services["cache"].tier == "data"
    error_message = "explicit tier is kept"
  }
}

run "grouping_collects_duplicates" {
  command = plan

  assert {
    condition     = output.names_by_tier == { web = ["admin", "api"], batch = ["worker"], data = ["cache"] }
    error_message = "the ... operator should collect both web services into one list"
  }
}

run "filter_scaled_services" {
  command = plan

  assert {
    condition     = output.scaled == tolist(["admin", "worker"])
    error_message = "only admin (2) and worker (4) run more than one replica"
  }
}

run "flatten_to_composite_keys" {
  command = plan

  assert {
    condition     = length(output.listeners) == 6 && contains(output.listeners, "api:8082")
    error_message = "api has 3 ports plus 3 other services = 6 listeners"
  }
}

run "subnets_are_deterministic" {
  command = plan

  assert {
    condition     = output.subnets == tomap({ batch = "10.20.0.0/24", data = "10.20.1.0/24", web = "10.20.2.0/24" })
    error_message = "one /24 per tier, assigned in sorted tier order"
  }
}

run "cross_product" {
  command = plan

  assert {
    condition     = length(output.deployments) == 8 && output.deployments[0] == "dev/admin"
    error_message = "2 envs x 4 services, sorted by service within env"
  }
}

run "template_renders_per_service" {
  command = plan

  assert {
    condition     = strcontains(output.rendered["api"], "also_listen 8081;") && strcontains(output.rendered["api"], "env LOG_LEVEL=debug;")
    error_message = "extra ports and env lines should be rendered"
  }

  assert {
    condition     = !strcontains(output.rendered["worker"], "env ")
    error_message = "a service without env should render no env lines"
  }
}

run "count_shifts_but_for_each_does_not" {
  command = plan

  assert {
    condition     = output.count_vs_for_each.count_before == ["0=a", "1=b", "2=c"] && output.count_vs_for_each.count_after_removal == ["0=b", "1=c"]
    error_message = "with count, removing the first item renumbers everything after it"
  }

  assert {
    condition     = output.count_vs_for_each.for_each_after == tolist(["b", "c"])
    error_message = "with for_each, b and c keep their keys"
  }
}
