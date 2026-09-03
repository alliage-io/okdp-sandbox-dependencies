# tools

OKDP chart of the sandbox cluster tools, plus the OKDP deletion protection:

- [Reloader](https://github.com/stakater/Reloader) (chart 2.2.17, Reloader v1.4.22):
  restarts pods when their ConfigMaps or Secrets change;
- [kubernetes-replicator](https://github.com/mittwald/kubernetes-replicator) 2.12.4:
  copies Secrets and ConfigMaps between namespaces (`replicator.v1.mittwald.de/*`
  annotations, used by `local-secrets-provider` and `cert-manager`);
- a `ValidatingAdmissionPolicy` refusing to delete objects labelled
  `okdp.io/protected=true` (replaces the KuboCD package flag `protected: true`).

The upstream charts are vendored under `vendor/` (see `vendor.yaml`) and rendered with
`okdp.vendor.render`, values in `templates/_values.tpl`.

## Deletion protection

The policy matches `DELETE` of CustomResourceDefinitions, Namespaces, Deployments,
StatefulSets and DaemonSets carrying `<protection.label>: "true"`. Pods and ReplicaSets
are not matched, so rollouts are unaffected. The `cert-manager` and `vault` charts label
their CRDs and controllers (`protected: true`); the `external-secrets` component does it
through the upstream `commonLabels`. Helm, Flux and Argo CD are refused like anyone
else: to uninstall a protected component, remove the label first, e.g.

```sh
kubectl label crd certificates.cert-manager.io okdp.io/protected-
```

`ValidatingAdmissionPolicy` is `admissionregistration.k8s.io/v1` (Kubernetes 1.30+).
No controller, no CRD.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `reloader.enabled` | `true` | Reloader. |
| `replicator.enabled` | `true` | kubernetes-replicator. |
| `protection.enabled` | `true` | The deletion protection policy and its binding. |
| `protection.label` | `okdp.io/protected` | Label whose value `"true"` protects an object. |

## Changes from the KuboCD package

- `namespace` is gone (it was unused): everything goes to the release namespace.
- kubernetes-secret-generator is gone (`secretGenerator`): nothing in OKDP used it any
  more (local-secrets-provider no longer generates empty values), and the values it
  wrote into Secrets after Helm applied them were drift for Flux and Argo CD. Generated
  passwords come from ESO (`okdp.generatedSecret` in okdp-lib). Its CRDs
  (`*.secretgenerator.mittwald.de`) are not removed from a cluster that had them.
- Reloader is the 2.x chart (was 1.0.72) and kubernetes-replicator 2.12.4 (was 2.9.2);
  the Reloader 3.x chart is still a beta.
- The deletion protection policy is new.

## Tests

```sh
helm dependency build packages/system/tools
for f in packages/system/tools/ci/*-values.yaml; do
  helm lint packages/system/tools -f "$f"
  helm template kube-tools-tools packages/system/tools -n kube-tools -f "$f" >/dev/null
done
scripts/vendor-charts.sh --check packages/system/tools
```
