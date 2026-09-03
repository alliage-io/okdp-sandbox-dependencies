{{/* Descriptor hooks (okdp-lib): no UI, no output. */}}
{{- define "okdp.instance.usage" -}}
Cluster tools:
{{- if .Values.reloader.enabled }}
- Reloader: restarts pods when their ConfigMaps or Secrets change.
{{- end }}
{{- if .Values.replicator.enabled }}
- Replicator: copies Secrets and ConfigMaps between namespaces.
{{- end }}
{{- if .Values.protection.enabled }}
- Deletion protection: objects labelled `{{ .Values.protection.label }}=true` cannot be deleted.
{{- end }}
{{- end -}}
