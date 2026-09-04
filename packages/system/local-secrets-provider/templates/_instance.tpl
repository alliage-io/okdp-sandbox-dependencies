{{/* Descriptor hooks (okdp-lib): no UI, no output. */}}
{{- define "okdp.instance.usage" -}}
Local stand-in for a secret manager. Secrets provisioned and replicated to every namespace:
{{- range .Values.secrets }}
- `{{ .name }}`
{{- end }}
{{- end -}}
