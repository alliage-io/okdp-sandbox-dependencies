[![ci](https://github.com/okdp/sandbox-dependencies/actions/workflows/ci.yml/badge.svg)](https://github.com/okdp/sandbox-dependencies/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/okdp/sandbox-dependencies)](https://github.com/okdp/sandbox-dependencies/releases/latest)&ensp;&ensp;
[![Helm](https://img.shields.io/badge/helm-3%20%7C%204-blue.svg)](https://helm.sh/)&ensp;&ensp;
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.30+-blue.svg)](https://kubernetes.io/)&ensp;&ensp;
[![License Apache2](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)
<a href="https://okdp.io">
<img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>

## Overview

This repository holds the OKDP sandbox prerequisites: cluster foundations (ingress, DNS,
certificates, database, identity, secret management, deletion protection) and the object
storage backing the platform services. They are not part of the OKDP distribution itself.

It is a **catalog** of OKDP services, as
[`OKDP/platform-charts`](https://github.com/OKDP/platform-charts): one package per
service version, in the format of [`okdp-compile`](https://github.com/OKDP/okdp-compiler),
which compiles the values of an instance into the values of each upstream chart the
service is made of, OKDP's own objects and what the instance publishes. The upstream
charts are rendered as published, from their own repositories: nothing of this
repository is published as a chart, everything OKDP stays in Git.

A platform reads the catalog from Git: its `platform/catalog.yaml` lists the catalog
repositories (`repositories: [{name: sandbox-dependencies, url: <git url>, ref:
<branch|tag|commit>}]`), and the versions of a service are the
`catalog/<service>/<version>/` directories found at `ref`. The deployment layer (the
deployments Git repository read by Flux or Argo CD) lives in
[`OKDP/okdp-sandbox`](https://github.com/OKDP/okdp-sandbox); the components it installs
from here, their layer and their values are listed in
[`docs/components/`](./docs/components/README.md).

## Structure

```
catalog/<service>/<version>/   one package version, immutable once released
contracts/                     the contracts the packages provide or consume (<contract>.schema.json)
scripts/compile-charts.sh      compiles, checks and renders the test cases of packages
docs/components/               the platform components built from these services (for okdp-sandbox)
```

The `version` is `<upstream version>-<OKDP version>`. Each service's README documents its
parameters, what changed from the KuboCD package, and its known gaps.

| Service | Version | Upstream charts | Description |
| --- | --- | --- | --- |
| [`cert-manager`](./catalog/cert-manager/1.21.2-1.0.0) | `1.21.2-1.0.0` | `cert-manager` v1.21.2, `trust-manager` v0.25.0 (charts.jetstack.io), `cert-issuers` 0.2.0 (quay.io/okdp/charts) | cert-manager, trust-manager, cluster issuers and the CA bundle |
| [`cnpg-postgresql`](./catalog/cnpg-postgresql/18.3.0-1.0.0) | `18.3.0-1.0.0` | none: OKDP's own objects | PostgreSQL cluster (CloudNativePG) with logical databases; one `database-server` output each |
| [`coredns-patch`](./catalog/coredns-patch/1.0.0-1.0.0) | `1.0.0-1.0.0` | none: OKDP's own objects | CoreDNS patch resolving the ingress suffix to the ingress controller |
| [`dns-server`](./catalog/dns-server/1.47.1-1.0.0) | `1.47.1-1.0.0` | `coredns` 1.47.1 (coredns.github.io) | Lightweight DNS server (CoreDNS) resolving the sandbox domain for local development |
| [`ingress-nginx`](./catalog/ingress-nginx/4.15.1-1.0.0) | `4.15.1-1.0.0` | `ingress-nginx` 4.15.1 (kubernetes.github.io) | NGINX ingress controller, in `nodePort`, `hostPort` or `metallb` mode (retired upstream: final release) |
| [`keycloak`](./catalog/keycloak/7.3.2-1.0.0) | `7.3.2-1.0.0` | `keycloakx` 7.3.2 (codecentric.github.io) | Keycloak identity and access management on keycloakx and the official image (consumes a `database-server` connection) |
| [`local-secrets-provider`](./catalog/local-secrets-provider/1.0.0-1.0.0) | `1.0.0-1.0.0` | none: OKDP's own objects | Secrets provisioned from a static list and replicated, a local stand-in for a secret manager |
| [`tools`](./catalog/tools/1.0.0-1.0.0) | `1.0.0-1.0.0` | `reloader` 2.2.17 (stakater), `kubernetes-replicator` 2.12.4 (mittwald) | Reloader, replicator, and the `okdp.io/protected` deletion protection |
| [`vault`](./catalog/vault/0.34.1-1.0.0) | `0.34.1-1.0.0` | `vault` 0.34.1 (helm.releases.hashicorp.com) | HashiCorp Vault, the secret backend a SecretStore points at; dev mode (sandbox only) is opt-in |
| [`rustfs`](./catalog/rustfs/1.0.0-1.0.0) | `1.0.0-1.0.0` | `rustfs` 1.0.0 (charts.rustfs.com) | RustFS single-node object store, an alternative to seaweedfs (S3, OIDC console sign-in); one `s3` output |
| [`seaweedfs`](./catalog/seaweedfs/4.47.0-1.0.0) | `4.47.0-1.0.0` | `seaweedfs` 4.47.0 (seaweedfs.github.io) | SeaweedFS object store (S3, IAM, STS); one `s3` output |

Upstream charts that only need static values are not wrapped: the platform components
install them directly (`cloudnative-pg`, `external-secrets`).

A package (`catalog/<service>/<version>/`, laid out as a Helm umbrella chart over its
upstream charts, never packaged):

```
Chart.yaml                 name: <service>, version: <version>, dependencies: the upstream charts,
                           each pinned in its own repository (none for a package of objects only)
okdp.yaml                  OKDP's part: roles and dependsOn (catalog metadata), require (platform
                           values), defaults, upstream (what an instance may set: protect, append),
                           then vars, errors, objects (OKDP's own objects), instance (URL, usage),
                           provides (connections published), oidcClients (OAuth clients)
values.cel.yaml            the values of each upstream chart, by dependency key, YAML + CEL
<key>.defaults.yaml        OKDP's defaults of the chart <key>, plain YAML
config.schema.json         the parameters: types, defaults, x-ui-* hints, x-okdp-connection-ref
README.md                  parameters, platform values read, charts, known gaps
ci/<case>-values.yaml      test instances (a first line "# error: <message>": a case that must fail)
ci/platform.yaml           the platform values of the cases (global.okdp), when they share them
ci/<case>-platform.yaml    a case's own platform values
ci/<case>-connections.yaml a case's own connections
```

The format is described in [`okdp-compiler`](https://github.com/OKDP/okdp-compiler):
[writing a package](https://github.com/OKDP/okdp-compiler/blob/main/docs/02_writing_package.md),
[the service definition](https://github.com/OKDP/okdp-compiler/blob/main/docs/specs/02_service_definition.md),
[inputs and outputs](https://github.com/OKDP/okdp-compiler/blob/main/docs/specs/01_inputs_outputs.md).

## OKDP services

Every service follows the OKDP rules (shared with `platform-charts`):

- the context, by level: the platform values (`global.okdp`) and the platform's
  connections, a project's, an instance's own connections; then the instance's values,
  its parameters and its upstream values (`upstream.<key>`, except the paths the package
  protects);
- each upstream chart receives, merged in this order: its own defaults (Helm applies
  them), OKDP's defaults (`<key>.defaults.yaml`), the values the mapping computes
  (`values.cel.yaml`), and the instance's upstream values;
- OKDP's own objects (generated Secrets, hooks, custom resources, the RBAC and Jobs of
  OKDP's own components) are the package's `objects`: the compiled umbrella renders them
  from `okdp.objects.yaml`, as written. What an instance publishes (URL, usage, provided
  connections) is `okdp.instance.yaml`, beside the compiled umbrella (it replaces the
  descriptor ConfigMap `<release>-okdp`);
- a compile is deterministic: generated passwords come from External Secrets Operator
  generators, and nothing differs between `helm install` (Flux) and `helm template`
  (Argo CD): upstream features built on `lookup`, random functions, `genCA` or
  `.Capabilities` are kept off, their switches protected.

## Working on a package

```bash
export OKDP_CHARTS=~/.cache/okdp/charts     # the chart cache of the checks (helm pull --untar)
pkg=catalog/keycloak/7.3.2-1.0.0

# compile one test instance: the umbrella chart, its values, OKDP's objects
okdp-compile --package $pkg --contracts contracts --context $pkg/ci/platform.yaml \
  --context 2:$pkg/ci/sandbox-connections.yaml -f $pkg/ci/sandbox-values.yaml \
  --release demo-keycloak --namespace demo -o /tmp/demo-keycloak

# check it against the upstream charts' defaults and values.schema.json
okdp-compile --check --charts $OKDP_CHARTS --package $pkg ... (the same inputs, no -o)

# render it as a deployment does
chart=$(mktemp -d) && cp -R /tmp/demo-keycloak/. "$chart" && helm dependency build "$chart"
helm template demo-keycloak "$chart" -n demo -f /tmp/demo-keycloak/instance.values.yaml

# every test case of packages, compiled, checked and rendered
scripts/compile-charts.sh $pkg
scripts/compile-charts.sh catalog/*/*
```

`scripts/compile-charts.sh` documents its inputs in its header: it pulls the charts the
checks need into `$OKDP_CHARTS`, and needs `okdp-compile` (`$OKDP_COMPILE`), `helm` and
`yq`. It, [`catalog-template.yml`](.github/workflows/catalog-template.yml) and the
contracts are copies of the canonical ones in `OKDP/platform-charts`: they must stay
byte-identical.

A released version directory is immutable: a change of a service is a new version, a
copy of the directory under its new version (`Chart.yaml` `version`). The upstream half
of the version follows the main upstream chart, the OKDP half is SemVer of the package.

## CI and releases

[`ci.yml`](.github/workflows/ci.yml) runs
[`catalog-template.yml`](.github/workflows/catalog-template.yml) on every package on
each pull request and push: it builds `okdp-compile` from
[okdp-compiler](https://github.com/OKDP/okdp-compiler) and runs
`scripts/compile-charts.sh catalog/*/*` (compile, check against the upstream charts,
render). Nothing is published.

[`release-please.yml`](.github/workflows/release-please.yml) releases the repository as
a whole: merging its release pull request tags `vX.Y.Z` and updates `CHANGELOG.md`, a ref
a platform's `catalog.yaml` can pin.

---

## Contributing & License

Contributions follow the [OKDP contribution guide](https://github.com/OKDP/.github/blob/main/CONTRIBUTING.md). Released under the [Apache License 2.0](LICENSE).

---

**Built 🚀 for the OKDP Community**
<a href="https://okdp.io">
  <img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>
