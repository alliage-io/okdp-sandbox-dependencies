# local-secrets-provider

OKDP package provisioning the Kubernetes Secrets the platform services need from a static
list: a local stand-in for an external secret manager in sandbox environments (the
credentials stay out of the platform model). Every Secret carries
`replicator.v1.mittwald.de/replicate-to: "*"`, so the replicator of the `tools` chart
copies it to every namespace. Every value is given explicitly: an empty one is refused.

A package in the okdp-compiler format, with no upstream chart (no dependency in
`Chart.yaml`): `okdp.yaml` writes one Secret per entry of the parameters below
(`config.schema.json`) as OKDP's own objects (its `objects` section, rendered by the
compiled umbrella chart, `okdp.objects.yaml`). The former module `main`, the chart
`oci://quay.io/okdp/charts/local-secrets-provider`, is no longer used: the version the
previous package rendered, 0.2.0 (the per-entry `labels`), was never published, and its
one template is a Secret per entry, which the mapping writes as well.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `secrets` | `[]` | List of `{name, data: {<key>: <value>}, labels: {<key>: <value>}}`, one Secret each; `labels` optional; names unique. |

`labels` are added to the Secret, next to OKDP's labels (which win), and
kubernetes-replicator copies them to the replicas. Database owner Secrets read by
CloudNativePG managed roles (cnpg-postgresql `owner.passwordSecret`) need
`cnpg.io/reload: "true"`: otherwise a role reconciled before the replica of its Secret
reaches the namespace keeps no password (see the cnpg-postgresql README).

In the sandbox it provides `creds-keycloak-db` (keys `username`, `password`), the owner
of the `keycloak` database (cnpg-postgresql) and the credentials Secret of Keycloak's
`database-server` connection, labelled `cnpg.io/reload: "true"`.

## Upstream values

None: the service renders no upstream chart. The former `upstream.local-secrets-provider`
(the chart's `nameOverride`, the `app.kubernetes.io/name` label of the Secrets) is gone;
an instance that sets `upstream` is refused by the schema.

## Changes from the KuboCD package

- Empty values are refused (schema and mapping). The former chart marked them
  `secret-generator.v1.mittwald.de/autogenerate` for kubernetes-secret-generator, which
  the `tools` chart no longer ships; a value generated in the cluster after Helm applied
  the Secret was drift for Flux and Argo CD anyway. Give explicit values, or generate
  passwords with ESO (a `Password` generator and an `ExternalSecret`, as the services
  render them among their own objects).
- Two entries of one name are refused (the former chart merged them into one Secret).
- The Secrets carry OKDP's labels (`app.kubernetes.io/part-of: okdp`, `okdp.io/instance`,
  `okdp.io/service`), no longer the chart's `helm.sh/chart` and
  `app.kubernetes.io/version`.

## Known gaps

What the okdp-lib-chart wrapper did to the rendered objects and a mapping cannot
express (okdp-compiler gap list):

- the values ConfigMap `<release>-local-secrets-provider-values`
  (`okdp.io/vendor-values`) is gone. What the instance publishes (its usage) is
  `okdp.instance.yaml`, next to the compiled umbrella chart, no longer the descriptor
  ConfigMap `<release>-okdp`.

## Tests

No platform value is read: the cases have no `ci/platform.yaml`. `duplicate` and
`empty-value` must fail.

```sh
scripts/compile-charts.sh catalog/local-secrets-provider/1.0.0-1.0.0   # compile, check and render ci/*-values.yaml
```
