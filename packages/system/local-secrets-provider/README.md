# local-secrets-provider

OKDP chart provisioning the Kubernetes Secrets the platform services need from a static
list: a local stand-in for an external secret manager in sandbox environments (the
credentials stay out of the platform model). Every Secret carries
`replicator.v1.mittwald.de/replicate-to: "*"`, so the replicator of the `tools` chart
copies it to every namespace. Every value is given explicitly: an empty one is refused.

It renders `oci://quay.io/okdp/charts/local-secrets-provider` 0.1.0, vendored under
`vendor/` (see `vendor.yaml`), with values computed in `templates/_values.tpl`.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `secrets` | (required) | List of `{name, data: {<key>: <value>}, labels: {<key>: <value>}}`, one Secret each; `labels` optional. |

`labels` are added to the Secret (the vendored chart has no such field: the wrapper adds
them to its output) and kubernetes-replicator copies them to the replicas. Database owner
Secrets read by CloudNativePG managed roles (cnpg-postgresql `owner.passwordSecret`) need
`cnpg.io/reload: "true"`: otherwise a role reconciled before the replica of its Secret
reaches the namespace keeps no password (see the cnpg-postgresql README).

In the sandbox it provides `creds-keycloak-db` (keys `username`, `password`), the owner
of the `keycloak` database (cnpg-postgresql) and the credentials Secret of Keycloak's
`database-server` connection, labelled `cnpg.io/reload: "true"`.

## Changes from the KuboCD package

- Empty values are refused (schema and chart). The upstream chart marks them
  `secret-generator.v1.mittwald.de/autogenerate` for kubernetes-secret-generator, which
  the `tools` chart no longer ships; a value generated in the cluster after Helm applied
  the Secret was drift for Flux and Argo CD anyway. Give explicit values, or generate
  passwords with ESO (`okdp.generatedSecret` in okdp-lib-chart).

## Tests

```sh
scripts/vendor-charts.sh packages/system/local-secrets-provider   # download vendor/ (not committed)
helm dependency build packages/system/local-secrets-provider
helm lint packages/system/local-secrets-provider -f packages/system/local-secrets-provider/ci/sandbox-values.yaml
helm template okdp-system-local-secrets-provider packages/system/local-secrets-provider -n okdp-system \
  -f packages/system/local-secrets-provider/ci/sandbox-values.yaml
```
