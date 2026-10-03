{{/*
Computed values of the vendored charts (the former KuboCD modules main, trust
and issuers); the fixed ones are in vendor-values/<chart>.yaml. cert-manager
(former module "main") has only fixed values (vendor-values/cert-manager.yaml).
*/}}

{{/* trust-manager (former module "trust"). */}}
{{- define "cert-manager.trust.values" -}}
crds:
  # The Bundle CRD is installed with cert-manager, one layer below.
  enabled: {{ .crdsOnly }}
app:
  trust:
    # Where the issuers' CA secrets live: this release's namespace.
    namespace: {{ .ctx.Release.Namespace }}
secretTargets:
  enabled: {{ .ctx.Values.trust.bundle.target.secret.enabled }}
  authorizedSecrets:
    - {{ .ctx.Values.trust.bundle.name }}
{{- end -}}

{{/* cert-issuers (former module "issuers"); the Bundle is rendered by bundle.yaml. */}}
{{- define "cert-manager.issuers.values" -}}
caClusterIssuers: {{ .Values.issuers.caClusterIssuers | default list | toYaml | nindent 2 }}
selfSignedClusterIssuers: {{ .Values.issuers.selfSignedClusterIssuers | default list | toYaml | nindent 2 }}
{{- end -}}

{{/*
Instance-level upstream values (okdp.vendor.render option `upstream`): an
instance sets any value of a vendored chart under upstream.<chart> in its
values.yaml, over the fixed (vendor-values/<chart>.yaml) and computed values,
except the protected paths.

upstream.cert-manager. Protected: names and namespaces (ClusterIssuer CA
Secrets are read from clusterResourceNamespace, the release namespace, where
cert-issuers writes them), the CRDs (installed and kept here, labelled by
cert-manager.protect; without them every Certificate is garbage-collected),
the cainjector (it injects the CA of cert-manager's and trust-manager's
webhooks), automatic approval (the platform issuers' requests would never be
approved), the ServiceAccounts the chart's RBAC binds, and the startupapicheck
hook annotations (hooks are limited to pre/post-install/upgrade). Appended:
webhook.extraArgs (the wrapper's serving-certificate duration) and
approveSignerNames (the issuers and clusterissuers signers).
*/}}
{{- define "cert-manager.upstream.cert-manager" -}}
protect:
  - fullnameOverride
  - nameOverride
  - namespace
  - clusterResourceNamespace
  - installCRDs
  - crds
  - cainjector.enabled
  - disableAutoApproval
  - serviceAccount.create
  - webhook.serviceAccount.create
  - cainjector.serviceAccount.create
  - startupapicheck.jobAnnotations
  - startupapicheck.rbac.annotations
  - startupapicheck.serviceAccount.annotations
append:
  - webhook.extraArgs
  - approveSignerNames
{{- end -}}

{{/*
upstream.trust-manager, for both renders (the Bundle CRD with cert-manager,
trust-manager itself one layer above). Protected: names and namespace, the
CRDs (installed by the cert-manager layer only: crds.enabled is what keeps
one Bundle CRD across the two layers), app.trust.namespace (where the
issuers' CA Secrets are read), the webhook certificate (helmCert runs
genCA/randAlphaNum, accepted by okdp-guard-allow.yaml only while off;
approverPolicy needs approver-policy, not installed), secretTargets (the
Bundle Secret is the only Secret trust-manager may write) and its
ServiceAccount.
*/}}
{{- define "cert-manager.upstream.trust" -}}
protect:
  - fullnameOverride
  - nameOverride
  - namespace
  - crds
  - app.trust.namespace
  - app.webhook.tls.helmCert
  - app.webhook.tls.approverPolicy
  - secretTargets
  - serviceAccount.create
{{- end -}}

{{/*
upstream.cert-issuers. Protected: the issuers (the issuers.* parameters,
also the sources of the Bundle bundle.yaml renders), its own Bundle (bundle.yaml
renders it a layer above) and replication (forced off, see
vendor-values/cert-issuers.yaml: it would let any namespace copy the CA
private keys).
*/}}
{{- define "cert-manager.upstream.issuers" -}}
protect:
  - fullnameOverride
  - nameOverride
  - caClusterIssuers
  - selfSignedClusterIssuers
  - bundle
  - replication
{{- end -}}
