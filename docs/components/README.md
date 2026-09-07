# Platform components of the sandbox

What the deployments repository (`okdp-sandbox/gitops/platform/components/<NN>-<name>/`)
installs from this repository, one directory per row. The `<NN>-<name>.values.yaml` file
next to this README is the component's `values.yaml`; its header gives the `instance.yaml`.
Layers: `00` CRDs/operators, `10` infra, `20` identity/storage/db, `30` control plane (none
here). A layer starts once every component of the layer below is ready.

Release = `<project>-<name>`. Charts are `oci://quay.io/okdp/sandbox-charts/<service>` unless
the upstream chart is used directly.

| Component | Project (namespace) | Service / chart | Version | Needs |
|---|---|---|---|---|
| `00-tools` | `kube-tools` | `tools` | `1.0.0-1.0.0` | |
| `00-cert-manager` | `cert-manager` | `cert-manager` | `1.21.2-1.0.0` | |
| `00-cloudnative-pg` | `cnpg-system` | `oci://ghcr.io/cloudnative-pg/charts/cloudnative-pg` (upstream) | `0.29.1` | |
| `00-external-secrets` | `external-secrets` | `oci://ghcr.io/external-secrets/charts/external-secrets` (upstream) | `2.11.0` | |
| `10-ingress-nginx` | `ingress-nginx` | `ingress-nginx` | `4.15.1-1.0.0` | cert-manager (webhook certs are hooks, no CRD) |
| `10-cert-issuers` | `cert-manager` | `cert-manager` | `1.21.2-1.0.0` | cert-manager CRDs and webhook |
| `10-coredns-patch` | `kube-system` | `coredns-patch` | `1.0.0-1.0.0` | the ingress-nginx Service name only |
| `10-dns-server` | `dns-server` | `dns-server` | `1.47.1-1.0.0` | |
| `10-local-secrets-provider` | `okdp-system` | `local-secrets-provider` | `1.0.0-1.0.0` | replicator (tools) |
| `20-trust-bundle` | `cert-manager` | `cert-manager` | `1.21.2-1.0.0` | trust-manager webhook (10-cert-issuers) |
| `20-cnpg-postgresql` | `cnpg-system` | `cnpg-postgresql` | `18.3.0-1.0.0` | cnpg operator, `creds-keycloak-db` (10) |
| `20-keycloak` | `keycloak` | `keycloak` | `7.3.2-1.0.0` | issuer, ingress, the database (same layer: Keycloak restarts until it answers) |
| `20-storage` (optional) | `default` | `seaweedfs` | `4.47.0-1.0.0` | ESO, Reloader, issuer, ingress, `creds-seaweedfs-s3` (10) |
| `20-kubauth` (optional) | `kubauth` | `kubauth` | `0.3.0-snapshot-1.0.1` | cert-manager, ingress |
| `20-vault` (optional) | `vault` | `vault` | `0.34.1-1.0.0` | issuer, ingress admission webhook |

`kubocd-webhooks` has no successor (KuboCD goes away).

Upstream notes: ESO 2.x serves `external-secrets.io/v1` only (every ESO object of the
platform is `v1`; see `00-external-secrets.values.yaml` for a cluster still on 0.15);
ingress-nginx is retired upstream, 4.15.1 being its final release.

Platform values these components read (`platform/platform-values.yaml`):
`ingress.suffix`, `ingress.className`, `certificateIssuers.selfSigned.name`,
`storageClass.data` (cnpg-postgresql), `storageClass.workspace` (seaweedfs),
`oidc.kubauth.namespace` (kubauth, when `oidc.clientProvisioning` is `kubauth`).

## Connections between components

`database-server` and `s3` are external-only contracts (no internal naming convention in
okdp-lib): cnpg-postgresql and seaweedfs publish their outputs in their descriptor
ConfigMaps (`<release>-okdp`), and a consumer declares the provider in a connection
values layer whose `secretRef` names a Secret of the consumer's namespace:

- `20-keycloak` → `20-cnpg-postgresql` output `cnpg-system-cnpg-postgresql-keycloak`,
  Secret `creds-keycloak-db` (replicated to every namespace by 10-local-secrets-provider).
  Components have `connections: []` and `values.yaml` must not carry `connections`: the
  file above declares it inline until the layout gives components connection files
  (open question).
- project services → `20-storage` output `default-storage`: a
  `projects/<p>/connections/<name>.yaml` with `apiUrl`, `internalUrl`, `region`,
  `pathStyle` and `secretRef: {name: creds-seaweedfs-s3}` (or the project's own grant).

## Argo CD note

cert-manager's cainjector, ingress-nginx's certgen hook, trust-manager and kubauth write
`caBundle` into their webhook configurations after the apply: the components
ApplicationSet should ignore `/webhooks/*/clientConfig/caBundle` on
`MutatingWebhookConfiguration` and `ValidatingWebhookConfiguration` (and
`/spec/conversion/webhook/clientConfig/caBundle` on CRDs), otherwise self-heal keeps
reverting them.
