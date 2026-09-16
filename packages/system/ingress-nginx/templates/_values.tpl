{{/* Values of the vendored ingress-nginx chart (the former KuboCD module "main"). */}}
{{- define "ingress-nginx.upstream.values" -}}
{{- $class := (include "okdp.platform.get" (dict "ctx" . "path" "ingress.className") | fromYaml).v | default "nginx" -}}
{{- if and (eq .Values.mode "metallb") (not .Values.endpoint) -}}
  {{- fail "ingress-nginx: endpoint is required in metallb mode" -}}
{{- end -}}
controller:
  allowSnippetAnnotations: false
  # No --enable-ssl-passthrough: no platform Ingress uses the ssl-passthrough
  # annotation, and passthrough lets any Ingress bypass TLS termination (and the
  # controller's own L7 checks) for its host.
  admissionWebhooks:
    enabled: true
  # The IngressClass the platform charts use (global.okdp.ingress.className).
  ingressClass: {{ $class }}
  ingressClassResource:
    name: {{ $class }}
    controllerValue: k8s.io/ingress-{{ $class }}
  {{- if eq .Values.mode "metallb" }}
  service:
    annotations:
      metallb.universe.tf/loadBalancerIPs: {{ .Values.endpoint }}
      metallb.universe.tf/allow-shared-ip: "ingress"
  {{- else if eq .Values.mode "hostPort" }}
  hostNetwork: true
  hostPort:
    enabled: true
  service:
    enabled: false
  {{- else }}
  service:
    type: NodePort
    nodePorts:
      http: {{ .Values.httpPort | quote }}
      https: {{ .Values.httpsPort | quote }}
  {{- end }}
{{- end -}}
