# tf-data-transforms

The Terraform expression idioms that come up most in real configs, each with a test: defaults with `merge`, grouping with `...`, filtering, `flatten` to composite keys, `cidrsubnets`, `setproduct`, `templatefile`, and why `for_each` beats `count`.

> **What is verified.** No provider and no resources, only locals and outputs, so there is nothing to deploy. On 2026-10-17, with Terraform 1.16.5 on Windows, `terraform test` passed 8 of 8 runs. GitHub Actions (Linux) ran the same commands and passed (2026-10-17).

## The input

`data/services.yaml` is a terse list of services, with fields omitted when the default is fine. `main.tf` turns it into a map keyed by name and derives everything else from that.

## The idioms (`main.tf`, numbered in the comments)

1. **Defaults and optional fields.** `merge(defaults, service, {...})` with `try()` for nested or missing fields. `merge` is shallow, so nested maps are handled explicitly.
2. **Group by.** `{ for name, s in services : s.tier => name... }`. The trailing `...` collects duplicate keys into a list; without it, two services in one tier is an error.
3. **Filter.** `[for name, s in services : name if s.replicas > 1]`.
4. **Flatten to composite keys.** Nested lists become one map keyed `"api:8080"`, which is stable for `for_each`.
5. **Subnet allocation.** `cidrsubnets` over sorted tiers, so the same input always yields the same CIDRs.
6. **Cross product.** `setproduct` of environments and services.
7. **`templatefile`.** One rendered config per service, with a loop over extra ports and env vars.
8. **`count` vs `for_each`.** The outputs show the index of each item before and after removing the first one: with `count` every later address shifts, with `for_each` they keep their keys.

## Honest limits

- It is pure computation. It says nothing about how these values behave once they feed real resources.
- The count-versus-for-each result is shown as computed keys and indexes; no resource is created or destroyed here.
- **A type pitfall in the tests:** comparing a `list`/`map` output to a literal `[...]`/`{...}` is false because the literal is a tuple/object. The tests wrap expected values in `tolist()` and `tomap()`. It took failing tests to find this.
- `strcontains` needs Terraform 1.5.1 or later; the tests need 1.6.

## Run it

```
terraform init
terraform test
terraform console   # then try: local.names_by_tier
```
