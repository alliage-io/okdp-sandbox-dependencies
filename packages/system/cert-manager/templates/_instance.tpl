{{/* Descriptor hooks (okdp-lib-chart): no UI, no output. */}}
{{- define "okdp.instance.usage" -}}
cert-manager issues the TLS certificates of the platform ingresses.
{{- with .Values.issuers.selfSignedClusterIssuers }}

Cluster issuers: {{ range $i, $x := . }}{{ if $i }}, {{ end }}`{{ $x.name }}`{{ end }}.
{{- end }}
{{- if .Values.trust.bundle.enabled }}

CA bundle `{{ .Values.trust.bundle.name }}` distributed to every namespace.
{{- end }}
{{- end -}}
