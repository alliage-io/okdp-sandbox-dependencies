{{/* Descriptor hooks (okdp-lib-chart): no UI, no output. */}}
{{- define "okdp.instance.usage" -}}
Local stand-in for a secret manager. Secrets provisioned and replicated to every namespace:
{{- range .Values.secrets }}
- `{{ .name }}`
{{- end }}
{{- end -}}
