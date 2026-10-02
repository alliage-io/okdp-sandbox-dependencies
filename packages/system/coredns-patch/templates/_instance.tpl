{{/* Descriptor hooks (okdp-lib-chart): no UI, no output. */}}
{{- define "okdp.instance.usage" -}}
CoreDNS resolves every name under `{{ .Values.global.okdp.ingress.suffix }}` to `{{ .Values.ingressService }}` inside the cluster.
{{- end -}}
