{{/* Descriptor hooks (okdp-lib): the Vault UI, no output. */}}
{{- define "okdp.instance.url" -}}
https://{{ .Values.ingressHost }}.{{ .Values.global.okdp.ingress.suffix }}
{{- end -}}
{{- define "okdp.instance.usage" -}}
Vault is reachable at {{ include "okdp.instance.url" . }}.
{{- if .Values.dev }}
In dev mode the root token is "root" and the store is emptied on every restart.
{{- end }}
{{- end -}}
