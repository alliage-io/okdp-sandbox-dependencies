{{/* Descriptor hooks (okdp-lib-chart): no UI, no output. */}}
{{- define "okdp.instance.usage" -}}
DNS server for local development: every name under `{{ .Values.global.okdp.ingress.suffix }}` resolves to `{{ .Values.target }}`, other names are forwarded to {{ join ", " .Values.forwarders }}.
Point the host resolver at a node on port {{ .Values.nodePort }} (UDP and TCP).
{{- end -}}
