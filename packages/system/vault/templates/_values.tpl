{{/* Values of the vendored vault chart (the former KuboCD module "main"). */}}
{{- define "vault.upstream.values" -}}
{{- include "okdp.require" (dict "ctx" . "keys" (list "ingress.suffix" "ingress.className" "certificateIssuers.selfSigned.name")) -}}
{{- $host := printf "%s.%s" .Values.ingressHost .Values.global.okdp.ingress.suffix -}}
server:
  dev:
    enabled: {{ .Values.dev }}
  ingress:
    enabled: true
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
