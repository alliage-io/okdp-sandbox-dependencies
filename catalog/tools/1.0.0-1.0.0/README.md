# tools

OKDP package of the sandbox cluster tools, plus the OKDP deletion protection:

- [Reloader](https://github.com/stakater/Reloader) (chart 2.2.17, Reloader v1.4.22):
  restarts pods when their ConfigMaps or Secrets change;
- [kubernetes-replicator](https://github.com/mittwald/kubernetes-replicator) 2.12.4:
  copies Secrets and ConfigMaps between namespaces (`replicator.v1.mittwald.de/*`
  annotations, used by `local-secrets-provider` and `cert-manager`);
- three `ValidatingAdmissionPolicies` refusing to delete objects labelled
  `okdp.io/protected=true`, controllers whose pod template carries that label, and the
  CRDs of protected API groups (replace the KuboCD package flag `protected: true`).

A package in the okdp-compiler format: the upstream charts (`Chart.yaml`, rendered from
their repositories) take OKDP's defaults (`<chart>.defaults.yaml`, `okdp.yaml`);
`values.cel.yaml` computes none of their values, it only selects them
(`reloader.enabled`, `replicator.enabled`). The deletion protection policies are OKDP's
own objects (the `objects` section of `okdp.yaml`), rendered by the compiled umbrella
chart (`okdp.objects.yaml`):

| Part | Now | Compiled when |
|---|---|---|
| Reloader | chart `reloader` (stakater 2.2.17) | `reloader.enabled` |
| kubernetes-replicator | chart `kubernetes-replicator` (mittwald 2.12.4) | `replicator.enabled` |
| deletion protection | OKDP's objects: the ValidatingAdmissionPolicies and their bindings | `protection.enabled` |

## Deletion protection

The first policy matches `DELETE` of CustomResourceDefinitions, Namespaces,
Deployments, StatefulSets and DaemonSets carrying `<protection.label>: "true"`. Pods and
ReplicaSets are not matched, so rollouts are unaffected. The `cert-manager` chart labels
its CRDs and controllers (`protected: true`, through the upstream charts' `commonLabels`);
the `external-secrets` component labels its controllers through the upstream
`commonLabels`.

The second policy (`<release>-protected-workloads`) matches `DELETE` of Deployments,
StatefulSets and DaemonSets whose pod template carries `<protection.label>: "true"`
(`spec.template.metadata.labels`), whatever their own labels. It is for the charts that
have a label value for their pods only, not for the metadata of their controllers: the
`vault` chart (`protected: true` sets `server.extraLabels` and `injector.extraLabels`).
The `objectSelector` of a policy sees the metadata labels only, so this one has no
selector and tests the pod template in its `matchConditions` (every field guarded with
`has()`: an evaluation error would refuse the deletion, `failurePolicy: Fail`). The pods
carry the label too, but Pods and ReplicaSets are not matched.

The third policy refuses to delete any CRD of an API group listed in
`protection.crdGroups` or one of its subgroups (`acme.cert-manager.io`,
`generators.external-secrets.io`): the upstream charts used directly as platform
components (external-secrets, cloudnative-pg) cannot label their CRDs, and deleting a
CRD deletes every object of that kind.

Helm, Flux and Argo CD are refused like anyone else: to uninstall a protected component,
remove the label (or the group) first, e.g.

```sh
kubectl label deployment -n <namespace> <name> okdp.io/protected-
```

A controller whose pod template carries the label is refused by the second policy as
well, whatever its own labels: vault's, and cert-manager's (its `commonLabels` reach the
pods). It loses the label with its chart's parameter (`protected: false`, then an
upgrade), which changes the pod template: its pods are rolled before it can be deleted.

`ValidatingAdmissionPolicy` is `admissionregistration.k8s.io/v1` (Kubernetes 1.30+).
No controller, no CRD.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `reloader.enabled` | `true` | Reloader. |
| `replicator.enabled` | `true` | kubernetes-replicator. |
| `protection.enabled` | `true` | The deletion protection policies and their bindings. |
| `protection.label` | `okdp.io/protected` | Label whose value `"true"` protects an object (a controller also through its pod template). |
| `protection.crdGroups` | `cert-manager.io`, `external-secrets.io`, `postgresql.cnpg.io` | API groups whose CRDs (subgroups included) cannot be deleted. |

## Upstream values

Any value of the `reloader` and `kubernetes-replicator` charts can be set per instance
under `upstream.<chart>`, merged over OKDP's defaults (`<chart>.defaults.yaml`)
(`upstream` in `okdp.yaml`):

```yaml
upstream:
  reloader:
    reloader:
      logLevel: debug
      ignoreNamespaces: scratch
      deployment: {resources: {limits: {memory: 128Mi}}}
  kubernetes-replicator:
    image: {repository: mirror.example.org/mittwald/kubernetes-replicator}
    tolerations: [{key: dedicated, operator: Exists, effect: NoSchedule}]
```

The paths the platform relies on are refused: see `protect` in `okdp.yaml` (also
listed in the schema descriptions). Among them: the RBAC, ServiceAccounts and
`reloader.watchGlobally` (both tools work across every namespace), what widens the
replicator's ClusterRole (`grantClusterAdmin`, `serviceAccount.privileges`, the verb
lists), Secret replication and `args` (`-allow-all` would let any namespace pull any
Secret), and the integrations gated by `.Capabilities` (kept off: `helm install` and `helm
template` would render them differently). Nothing
is appended: the chart sets no list. `global` is refused too, so the Reloader image is
changed with `image`, not `global.imageRegistry`. No key or value may contain `{{` (the
schema and okdp-compile both refuse it).

## Changes from the KuboCD package

- `namespace` is gone (it was unused): everything goes to the release namespace.
- kubernetes-secret-generator is gone (`secretGenerator`): nothing in OKDP used it any
  more (local-secrets-provider no longer generates empty values), and the values it
  wrote into Secrets after Helm applied them were drift for Flux and Argo CD. Generated
  passwords come from ESO (`Password` generators among the services' own objects).
  Its CRDs (`*.secretgenerator.mittwald.de`) are not removed from a cluster that had them.
- Reloader is the 2.x chart (was 1.0.72) and kubernetes-replicator 2.12.4 (was 2.9.2);
  the Reloader 3.x chart is still a beta.
- The deletion protection policies are new; cloudnative-pg's CRDs are protected too
  (they were not: deleting them deletes every PostgreSQL cluster).

## Known gaps

What the okdp-lib-chart chart did and the okdp-compiler format cannot express:

- the okdp-lib-chart `vault` chart labelled its StatefulSet and injector Deployment
  themselves (post-processing); the vault chart's values can only label their pods, so
  they are protected by the second policy (pod template) and a selector on
  `okdp.io/protected=true` lists their pods, not them;
- the values ConfigMaps `<release>-<chart>-values` (`okdp.io/vendor-values`) are gone:
  the compiled values replace them. What the instance publishes (its usage) is
  `okdp.info.yaml`, next to the compiled umbrella chart, no longer the descriptor
  ConfigMap `<release>-okdp`.

## Tests

No platform value is read: the cases have no `ci/platform.yaml`. `protected-upstream`
must fail.

```sh
scripts/compile-charts.sh catalog/tools/1.0.0-1.0.0   # compile, check and render ci/*-values.yaml
```
