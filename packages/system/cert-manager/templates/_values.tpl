{{/*
Values of the vendored charts (the former KuboCD modules main, trust and issuers).
*/}}

{{/* cert-manager (former module "main"). */}}
{{- define "cert-manager.upstream.values" -}}
crds:
  enabled: true
  keep: true
enableCertificateOwnerRef: true
image:
  repository: quay.io/jetstack/cert-manager-controller
webhook:
  extraArgs:
    # 90 days validity instead of 7 days
    - "--dynamic-serving-leaf-duration=2160h"
{{- end -}}

{{/* trust-manager (former module "trust"). */}}
{{- define "cert-manager.trust.values" -}}
crds:
  # The Bundle CRD is installed with cert-manager, one layer below.
  enabled: {{ .crdsOnly }}
  keep: true
app:
  trust:
    # Where the issuers' CA secrets live: this release's namespace.
    namespace: {{ .ctx.Release.Namespace }}
  webhook:
    tls:
      # The webhook certificate comes from cert-manager: a Helm-generated one
      # (genCA) would change on every render.
      helmCert:
        enabled: false
secretTargets:
  enabled: {{ .ctx.Values.trust.bundle.target.secret.enabled }}
  authorizedSecrets:
    - {{ .ctx.Values.trust.bundle.name }}
image:
  repository: quay.io/jetstack/trust-manager
{{- end -}}

{{/* cert-issuers (former module "issuers"); the Bundle is rendered by bundle.yaml. */}}
{{- define "cert-manager.issuers.values" -}}
caClusterIssuers: {{ .Values.issuers.caClusterIssuers | default list | toYaml | nindent 2 }}
selfSignedClusterIssuers: {{ .Values.issuers.selfSignedClusterIssuers | default list | toYaml | nindent 2 }}
bundle:
  enabled: false
# Never make the CA Secrets replicable: the upstream default (replicator,
# allowedNamespaces ".*") lets any namespace copy the CA private key
# (tls.key) with a replicate-from annotation. trust-manager reads the CA
# certificates in this namespace (see bundle.yaml); nothing needs replication.
replication:
  enabled: false
{{- end -}}
