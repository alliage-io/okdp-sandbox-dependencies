{{/* Descriptor hooks (okdp-lib): no UI, no output. */}}
{{- define "okdp.instance.usage" -}}
NGINX Ingress Controller ({{ .Values.mode }} mode) for the IngressClass `{{ (include "okdp.platform.get" (dict "ctx" . "path" "ingress.className") | fromYaml).v | default "nginx" }}`.
{{- if eq .Values.mode "nodePort" }}
HTTP on node port {{ .Values.httpPort }}, HTTPS on {{ .Values.httpsPort }}.
{{- else if eq .Values.mode "metallb" }}
LoadBalancer IP {{ .Values.endpoint }}.
{{- else }}
Ports 80 and 443 on every node.
{{- end }}
In-cluster Service: `{{ include "okdp.fullname" (dict "ctx" . "suffix" "controller") }}.{{ .Release.Namespace }}.svc.cluster.local`.
{{- end -}}
