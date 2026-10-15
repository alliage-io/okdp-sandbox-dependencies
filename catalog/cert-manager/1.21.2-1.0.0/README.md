# cert-manager

OKDP package of [cert-manager](https://cert-manager.io/) with
[trust-manager](https://cert-manager.io/docs/trust/trust-manager/) and the OKDP
cluster issuers (`cert-issuers`). It issues the TLS certificates of the platform
ingresses (`global.okdp.certificateIssuers.selfSigned.name`) and distributes the
issuers' CA certificates to every namespace.

A package in the okdp-compiler format: `Chart.yaml` names three upstream charts, rendered
from their repositories: cert-manager v1.21.2, trust-manager v0.25.0
(https://charts.jetstack.io) and `oci://quay.io/okdp/charts/cert-issuers` 0.2.0;
`values.cel.yaml` computes their values from the parameters (`config.schema.json`), over
OKDP's defaults (`<chart>.defaults.yaml`, `okdp.yaml`). The trust Bundle is one of OKDP's
own objects (the `objects` section of `okdp.yaml`), rendered by the compiled umbrella
chart (`okdp.objects.yaml`).

## One package, three platform components

Helm cannot apply a custom resource whose CRD is created by the same release, and
trust-manager validates Bundles with a webhook (`failurePolicy: Fail`) that must be
running first. KuboCD ordered the modules inside one package; now each part is a
platform component of its own layer (`platform/components/<NN>-<name>`, all in the
`cert-manager` namespace, the one trust-manager reads the CA secrets from):

| Component | Values | Installs |
|---|---|---|
| `00-cert-manager` | `certManager.enabled: true` (default) | chart `cert-manager` (former module `main`): cert-manager and its CRDs |
| `10-cert-issuers` | `certManager.enabled: false`, `trust.enabled`, `issuers.enabled` | chart `trust-manager` (former module `trust`): trust-manager and its Bundle CRD; chart `cert-issuers` (former module `issuers`): the ClusterIssuers and their CA Certificates |
| `20-trust-bundle` | `certManager.enabled: false`, `trust.bundle.enabled` | OKDP's objects: the Bundle (sources: the issuers listed in `issuers.*`) |

`ci/*-values.yaml` are the three configurations used by the sandbox, over the platform
values of `ci/platform.yaml`; `protected-upstream` must fail.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `certManager.enabled` | `true` | cert-manager and its CRDs (kept on uninstall). |
| `protected` | `true` | Label CRDs and controllers `okdp.io/protected=true` (deletion refused by the tools chart's ValidatingAdmissionPolicy). |
| `trust.enabled` | `false` | trust-manager and its Bundle CRD (kept on uninstall). |
| `trust.bundle.enabled` | `false` | The Bundle `trust.bundle.name` of the issuers' CA certificates plus the default CAs. |
| `trust.bundle.name` | `certs-bundle` | Bundle name (also the only Secret trust-manager may write). |
| `trust.bundle.target.configMap` / `.secret` | off, `root-certs.pem` / `ca.crt` | Bundle targets; a PKCS#12 `bundle.p12` is always added. |
| `issuers.enabled` | `false` | Create the ClusterIssuers. |
| `issuers.selfSignedClusterIssuers` | `[]` | `{name, certificate: {commonName, organization, country, validity, algorithm, size}}` |
| `issuers.caClusterIssuers` | `[]` | `{name, ca_crt, ca_key}` (base64 PEM) |

## Upstream values

Any value of the `cert-manager`, `trust-manager` and `cert-issuers` charts can be
set per instance under `upstream.<chart>`, merged over the values computed from
the parameters (`upstream` in `okdp.yaml`):

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
`00-cert-manager`, `upstream.trust-manager` and `upstream.cert-issuers` in
`10-cert-issuers`.

The paths the platform relies on are refused and the lists the chart sets are
appended to rather than replaced: see `protect` and `append` in `okdp.yaml`
(also listed in the schema descriptions). The CRDs, the CA Secrets' namespace,
automatic approval, trust-manager's webhook certificate and secret targets and
cert-issuers' issuers, Bundle and replication stay under the chart's control; set
`issuers.*` and `trust.*` for those. No key or value may contain `{{` (the schema
and okdp-compile both refuse it).

## Changes from the KuboCD package

- The modules `main`, `trust`, `issuers` became three components of one package (above);
  the defaults install cert-manager only (they were `issuers.enabled: true`).
- The Bundle is rendered by this package (it was part of `cert-issuers`), one layer
  above trust-manager.
- trust-manager's webhook certificate comes from cert-manager (`helmCert` off): the
  chart's generated certificate (`genCA`) is non-deterministic, `helm install` and
  `helm template` would render different objects.
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

## Known gaps

What the okdp-lib-chart chart did to the rendered objects and the okdp-compiler format
can only approximate or cannot express:

- the `okdp.io/protected: "true"` label (`protected`) was added by post-processing to the
  CRDs and the controllers only. It is now set through the charts' label values
  (cert-manager `global.commonLabels`, trust-manager `commonLabels`), which put it on
  every object they render, on the pod templates, and on the ACME HTTP-01 solver
  resources cert-manager creates (`--acme-http01-solver-extra-labels`). The tools
  chart's policies only match CRDs, Namespaces, Deployments, StatefulSets and
  DaemonSets, so what they protect is unchanged. As the controllers' pod templates carry
  the label too, the tools chart's pod-template policy also refuses their deletion:
  removing the label from a Deployment (`kubectl label`) is not enough, set
  `protected: false` (the pods are rolled);
- trust-manager's Bundle CRD is no longer installed by `00-cert-manager`: no value of the
  trust-manager chart renders only its CRD, and a package renders each chart as
  published (the former package vendored a copy of the chart reduced to its CRD,
  `trust-manager-crds`). The CRD now comes with trust-manager in `10-cert-issuers`
  (`crds.enabled`, kept on uninstall: `crds.keep`), still a layer below the Bundle
  (`20-trust-bundle`). On a cluster installed with the former package the CRD belongs
  to the `00-cert-manager` release, which keeps it (`helm.sh/resource-policy: keep`):
  before `10-cert-issuers` can take it over, give it to that release
  (`kubectl annotate crd bundles.trust.cert-manager.io meta.helm.sh/release-name=<release
  of 10-cert-issuers> --overwrite`);
- the values ConfigMaps `<release>-<chart>-values` (`okdp.io/vendor-values`) are gone:
  the compiled values replace them. What the instance publishes (its usage) is
  `okdp.instance.yaml`, next to the compiled umbrella chart, no longer the descriptor
  ConfigMap `<release>-okdp`.

## Tests

```sh
scripts/compile-charts.sh catalog/cert-manager/1.21.2-1.0.0   # compile, check and render ci/*-values.yaml
```
