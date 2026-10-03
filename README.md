[![ci](https://github.com/okdp/sandbox-dependencies/actions/workflows/ci.yml/badge.svg)](https://github.com/okdp/sandbox-dependencies/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/okdp/sandbox-dependencies)](https://github.com/okdp/sandbox-dependencies/releases/latest)&ensp;&ensp;
[![Helm](https://img.shields.io/badge/helm-3.x-blue.svg)](https://helm.sh/)&ensp;&ensp;
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.30+-blue.svg)](https://kubernetes.io/)&ensp;&ensp;
[![License Apache2](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)
<a href="https://okdp.io">
<img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>

## Overview

This repository builds and publishes the Helm charts of the OKDP sandbox prerequisites:
cluster foundations (ingress, DNS, certificates, database, identity, secret management,
deletion protection) and the object storage backing the platform services. They are not
part of the OKDP distribution itself.

It is **charts-only**: it owns the charts under `packages/` and the CI that tests and
publishes them. The deployment layer (the deployments Git repository read by Flux or Argo
CD) lives in [`OKDP/okdp-sandbox`](https://github.com/OKDP/okdp-sandbox); the components it
installs from here, their layer and their values are listed in
[`docs/components/`](./docs/components/README.md).

## OKDP charts

Every chart follows the OKDP chart rules (shared with `platform-packages` and
`community-packages`):

- values: `global.okdp` (platform values, the first values layer), `connections` (external
  connections), then the chart parameters (the former KuboCD parameters);
- upstream charts whose values are computed are **vendored** under `vendor/<name>/`
  (listed in `vendor.yaml`, downloaded, not committed, with
  [`scripts/vendor-charts.sh`](./scripts/vendor-charts.sh)) and rendered with
  `okdp.vendor.render` from the library chart `okdp-lib-chart`: their fixed values in
  `vendor-values/<name>.yaml` (plain YAML, `valuesFile`), the computed ones in
  `templates/_values.tpl`;
- every chart renders the instance descriptor ConfigMap `<release>-okdp` (URL, usage, the
  connections it provides);
- nothing differs between `helm install` (Flux) and `helm template` (Argo CD): no `lookup`,
  no random function, hooks limited to pre/post-install/upgrade. Reviewed upstream
  exceptions are in each chart's `okdp-guard-allow.yaml`.

Upstream charts that only needed static values are no longer wrapped: the platform
components install them directly (`cloudnative-pg`, `external-secrets`).

## Structure

```
packages/
├── system/             # Infrastructure & system charts
│   ├── cert-manager/           # + trust-manager + cluster issuers (3 components)
│   ├── cnpg-postgresql/        # database-server provider
│   ├── coredns-patch/
│   ├── dns-server/
│   ├── ingress-nginx/
│   ├── keycloak/               # database-server consumer
│   ├── local-secrets-provider/
│   ├── tools/                  # + deletion protection (ValidatingAdmissionPolicy)
│   └── vault/
└── services/
    ├── rustfs/                 # s3 provider (alternative to seaweedfs)
    └── seaweedfs/              # s3 provider
docs/components/        # the platform components built from these charts (for okdp-sandbox)
scripts/vendor-charts.sh
sandbox-dependencies-values.yaml   # release OCI repository (packageRepository), read by CI
```

## Charts

The chart `version` is `<upstream version>-<OKDP version>`; release-please owns the OKDP
half. Each chart's README documents its parameters and what changed from the KuboCD package.

| Chart | Version | Description |
| --- | --- | --- |
| [`cert-manager`](./packages/system/cert-manager) | `1.21.2-1.0.0` | cert-manager, trust-manager, cluster issuers and the CA bundle |
| [`cnpg-postgresql`](./packages/system/cnpg-postgresql) | `18.3.0-1.0.0` | PostgreSQL cluster (CloudNativePG) with logical databases; one `database-server` output each |
| [`coredns-patch`](./packages/system/coredns-patch) | `1.0.0-1.0.0` | CoreDNS patch resolving the ingress suffix to the ingress controller |
| [`dns-server`](./packages/system/dns-server) | `1.47.1-1.0.0` | Lightweight DNS server (CoreDNS) resolving the sandbox domain for local development |
| [`ingress-nginx`](./packages/system/ingress-nginx) | `4.15.1-1.0.0` | NGINX ingress controller, in `nodePort`, `hostPort` or `metallb` mode (retired upstream: final release) |
| [`keycloak`](./packages/system/keycloak) | `7.3.2-1.0.0` | Keycloak identity and access management on keycloakx and the official image (consumes a `database-server` connection) |
| [`local-secrets-provider`](./packages/system/local-secrets-provider) | `1.0.0-1.0.0` | Secrets provisioned from a static list and replicated, a local stand-in for a secret manager |
| [`tools`](./packages/system/tools) | `1.0.0-1.0.0` | Reloader, replicator, and the `okdp.io/protected` deletion protection |
| [`vault`](./packages/system/vault) | `0.34.1-1.0.0` | HashiCorp Vault, the secret backend a SecretStore points at; dev mode (sandbox only) is opt-in |
| [`rustfs`](./packages/services/rustfs) | `1.0.0-1.0.0` | RustFS single-node object store, an alternative to seaweedfs (S3, OIDC console sign-in); one `s3` output |
| [`seaweedfs`](./packages/services/seaweedfs) | `4.47.0-1.0.0` | SeaweedFS object store (S3, IAM, STS); one `s3` output |

## Working on a chart

The charts depend on `okdp-lib-chart` from the OCI registry
`oci://quay.io/okdp/okdp-lib-chart` (`helm dependency build` fetches it):

```bash
scripts/vendor-charts.sh packages/system/keycloak           # download vendor/ (not committed), again after a version bump
helm dependency build packages/system/keycloak
for f in packages/system/keycloak/ci/*-values.yaml; do
  helm lint packages/system/keycloak -f "$f"
  helm template keycloak-keycloak packages/system/keycloak -n keycloak -f "$f"
done

# The CI checks, from a checkout of OKDP/gh-workflows next to this repository:
../gh-workflows/scripts/okdp-chart-guard.sh packages/system/keycloak
../gh-workflows/scripts/okdp-chart-test.sh packages/system/keycloak
```

## GitHub CI and Publishing

The workflows call the reusable
[`okdp-chart-ci.yml`](https://github.com/OKDP/gh-workflows#okdp-chart-ci-okdp-chart-ciyml)
of `OKDP/gh-workflows`: `scripts/vendor-charts.sh` (downloads `vendor/`), the chart guard
(forbidden patterns, descriptor, schema, vendored charts), `helm lint`, `helm template` of every `ci/*-values.yaml`, `kubeconform`, then
`helm package` and `helm push`.

- [`ci.yml`](./.github/workflows/ci.yml) (push, pull request, dispatch): the changed charts,
  pushed to `oci://ghcr.io/okdp/sandbox-dependencies/charts/<chart>:0.0.0-ci.<branch>.g<sha>`
  (validation only for pull requests from forks).
- [`release-please.yml`](./.github/workflows/release-please.yml): release-please keeps a
  release pull request; [`compose-oci-tag.sh`](./.github/scripts/compose-oci-tag.sh) writes
  `<upstream>-<release-please version>` into each released `Chart.yaml`. Merging it
  publishes the released charts to `oci://quay.io/okdp/sandbox-charts/<chart>:<version>`
  (`REGISTRY_USERNAME`, `REGISTRY_ROBOT_TOKEN`); a version already published fails.
- [`publish.yml`](./.github/workflows/publish.yml) (dispatch): republishes every chart whose
  version is not on the registry yet.

The release repository is `packageRepository` in
[`sandbox-dependencies-values.yaml`](./sandbox-dependencies-values.yaml).

---

## Contributing & License

Contributions follow the [OKDP contribution guide](https://github.com/OKDP/.github/blob/main/CONTRIBUTING.md). Released under the [Apache License 2.0](LICENSE).

---

**Built 🚀 for the OKDP Community**
<a href="https://okdp.io">
  <img src="https://okdp.io/logos/okdp-notext.svg" height="20px" style="margin: 0 2px;" />
</a>
