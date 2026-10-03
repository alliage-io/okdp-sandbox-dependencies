{{/* Values of the vendored vault chart (the former KuboCD module "main"). */}}
{{- define "vault.upstream.values" -}}
{{- include "okdp.require" (dict "ctx" . "keys" (list "ingress.suffix" "ingress.className" "certificateIssuers.selfSigned.name")) -}}
{{- $host := printf "%s.%s" .Values.ingressHost .Values.global.okdp.ingress.suffix -}}
server:
  dev:
    enabled: {{ .Values.dev }}
  ingress:
    ingressClassName: {{ .Values.global.okdp.ingress.className }}
    annotations:
      {{- include "okdp.ingressAnnotations" . | nindent 6 }}
    hosts:
      - host: {{ $host }}
        paths: []
    tls:
      - secretName: {{ include "okdp.fullname" (dict "ctx" . "suffix" "tls") }}
        hosts:
          - {{ $host }}
ui:
  enabled: {{ .Values.uiEnabled }}
{{- end -}}

{{/*
Instance-level upstream values (okdp.vendor.render option `upstream`): an
instance sets any value of the vendored chart under upstream.vault in its
values.yaml, over the values computed above, except the protected paths.
Protected: the names and the Service port the SecretStores reach Vault at
(<release>-vault:8200), dev mode (the `dev` parameter only, GIT-08: a dev
Vault has the root token "root"), and the ingress host and TLS the wrapper
computes. global (tlsDisable among others) is always protected by
okdp-lib-chart. The wrapper sets no list, so nothing is appended.
*/}}
{{- define "vault.upstream" -}}
protect:
  - fullnameOverride
  - nameOverride
  - server.dev
  - server.service.port
  - server.ingress.enabled
  - server.ingress.ingressClassName
  - server.ingress.hosts
  - server.ingress.tls
{{- end -}}
