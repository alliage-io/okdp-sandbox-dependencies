# cert-manager

OKDP chart of [cert-manager](https://cert-manager.io/) with
[trust-manager](https://cert-manager.io/docs/trust/trust-manager/) and the OKDP
cluster issuers (`cert-issuers`). It issues the TLS certificates of the platform
ingresses (`global.okdp.certificateIssuers.selfSigned.name`) and distributes the
issuers' CA certificates to every namespace.

It renders three upstream charts vendored under `vendor/` (see `vendor.yaml`):
cert-manager v1.21.2, trust-manager v0.25.0 and `oci://quay.io/okdp/charts/cert-issuers`
0.2.0, with values computed in `templates/_values.tpl`.

## One chart, three platform components

Helm cannot apply a custom resource whose CRD is created by the same release, and
trust-manager validates Bundles with a webhook (`failurePolicy: Fail`) that must be
running first. KuboCD ordered the modules inside one package; now each part is a
platform component of its own layer (`platform/components/<NN>-<name>`, all in the
`cert-manager` namespace, the one trust-manager reads the CA secrets from):

| Component | Values | Installs |
|---|---|---|
| `00-cert-manager` | `certManager.enabled: true` (default) | cert-manager, its CRDs and trust-manager's Bundle CRD |
| `10-cert-issuers` | `certManager.enabled: false`, `trust.enabled`, `issuers.enabled` | trust-manager, the ClusterIssuers and their CA Certificates |
| `20-trust-bundle` | `certManager.enabled: false`, `trust.bundle.enabled` | the Bundle (sources: the issuers listed in `issuers.*`) |

`ci/*-values.yaml` are the three configurations used by the sandbox.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `certManager.enabled` | `true` | cert-manager, its CRDs (kept on uninstall) and the Bundle CRD. |
| `protected` | `true` | Label CRDs and controllers `okdp.io/protected=true` (deletion refused by the tools chart's ValidatingAdmissionPolicy). |
| `trust.enabled` | `false` | trust-manager. |
| `trust.bundle.enabled` | `false` | The Bundle `trust.bundle.name` of the issuers' CA certificates plus the default CAs. |
| `trust.bundle.name` | `certs-bundle` | Bundle name (also the only Secret trust-manager may write). |
| `trust.bundle.target.configMap` / `.secret` | off, `root-certs.pem` / `ca.crt` | Bundle targets; a PKCS#12 `bundle.p12` is always added. |
| `issuers.enabled` | `false` | Create the ClusterIssuers. |
| `issuers.selfSignedClusterIssuers` | `[]` | `{name, certificate: {commonName, organization, country, validity, algorithm, size}}` |
| `issuers.caClusterIssuers` | `[]` | `{name, ca_crt, ca_key}` (base64 PEM) |

## Upstream values

Any value of the vendored `cert-manager`, `trust-manager` and `cert-issuers`
charts can be set per instance under `upstream.<chart>`, merged over the values
computed from the parameters (okdp-lib-chart `okdp.vendor.render`, option
`upstream`):

```yaml
upstream:
  cert-manager:
    image: {repository: mirror.example.org/jetstack/cert-manager-controller}
    tolerations: [{key: dedicated, operator: Exists, effect: NoSchedule}]
    webhook: {extraArgs: ["--v=2"]}               # appended to the chart's extraArgs
  trust-manager:
    resources: {limits: {memory: 256Mi}}
```

Each layer reads the key of the charts it renders: `upstream.cert-manager` in
`00-cert-manager`, `upstream.trust-manager` in `10-cert-issuers` (and in
`00-cert-manager` for the Bundle CRD, of which only the CRD is kept),
`upstream.cert-issuers` in `10-cert-issuers`.

The paths the platform relies on are refused and the lists the chart sets are
appended to rather than replaced: see `cert-manager.upstream.cert-manager`,
`cert-manager.upstream.trust` and `cert-manager.upstream.issuers` in
`templates/_values.tpl` (also listed in the schema descriptions). The CRDs, the
CA Secrets' namespace, automatic approval, trust-manager's webhook certificate
and secret targets and cert-issuers' issuers, Bundle and replication stay under
the chart's control; set `issuers.*` and `trust.*` for those. No key or value may
contain `{{` (the schema and okdp-lib-chart both refuse it).

## Changes from the KuboCD package

- The modules `main`, `trust`, `issuers` became three components of one chart (above);
  the defaults install cert-manager only (they were `issuers.enabled: true`).
- The Bundle is rendered by this chart (it was part of `cert-issuers`), one layer
  above trust-manager.
- trust-manager's webhook certificate comes from cert-manager (`helmCert` off): the
  chart's generated certificate is non-deterministic (see `okdp-guard-allow.yaml`).
- `protected: true` (KuboCD) is now the `okdp.io/protected` label.
- cert-issuers' `replication` is forced off (upstream default: replicator annotations
  allowing every namespace). The CA Secrets hold the CA private key (`tls.key`): with
  replication any namespace could copy it with a `replicate-from` annotation.
  trust-manager reads the CA certificates in this namespace, so nothing needs the
  copies; the empty `<name>-ca` Secret of self-signed issuers is no longer rendered.

## Upstream versions

cert-manager v1.21.2 and trust-manager v0.25.0 (the KuboCD package had v1.17.1 and
v0.16.0). Upstream changes that matter here:

- cert-manager 1.18: `Certificate.spec.privateKey.rotationPolicy` defaults to `Always`
  (a new key on every renewal) and `revisionHistoryLimit` to 1.
- cert-manager 1.21: the Helm chart no longer grants the controller `serviceaccounts/token`
  (only needed by issuers authenticating as the controller's own ServiceAccount, none
  here), the metrics port is renamed `http-metrics`, and the `cert-manager-edit`
  aggregated role no longer creates ACME challenges and orders.
- trust-manager: `Bundle` (`trust.cert-manager.io/v1alpha1`) is still the served and
  stored API and the only CRD of the chart (the `ClusterBundle` successor is not
  shipped yet), so `20-trust-bundle` is unchanged. The default CA package image is now
  based on Debian Trixie (`useDefaultCAs`).

## Tests

```sh
scripts/vendor-charts.sh packages/system/cert-manager   # download vendor/ (not committed)
helm dependency build packages/system/cert-manager
for f in packages/system/cert-manager/ci/*-values.yaml; do
  helm lint packages/system/cert-manager -f "$f"
  helm template cert-manager-cert-manager packages/system/cert-manager -n cert-manager -f "$f" >/dev/null
done
```
