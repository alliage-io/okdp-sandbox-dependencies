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

{{/*
Instance-level upstream values (okdp.vendor.render option `upstream`): an
instance sets any value of the vendored chart under upstream.ingress-nginx in
its values.yaml, over the values computed above, except the protected paths.
Protected:
- names (the controller Service <release>-controller is coredns-patch's
  ingressService) and the namespace;
- the IngressClass every platform chart uses (class, resource name, controller
  value, and the controller flags that would change them or the namespaces
  watched);
- the exposure chosen by mode and published by the descriptor (Service on or
  off and its type, node ports, host networking; the metallb IP, whose
  annotation keys contain dots, is checked below);
- the hardening: no SSL passthrough (GIT-14), no snippet annotations and no
  higher annotation risk level, the admission webhook on;
- autoscaling (.Capabilities.APIVersions, accepted by okdp-guard-allow.yaml
  only while off), and the RBAC and ServiceAccount the controller needs.
The wrapper sets no list, so nothing is appended.
*/}}
{{- define "ingress-nginx.upstream.options" -}}
{{- $node := .Values.upstream -}}
{{- range $k := list "ingress-nginx" "controller" "service" "annotations" -}}
  {{- $node = and (kindIs "map" $node) (index $node $k) -}}
{{- end -}}
{{- if kindIs "map" $node -}}
  {{- range $k, $_ := $node -}}
    {{- if hasPrefix "metallb.universe.tf/" $k -}}
      {{- fail (printf "ingress-nginx: upstream.ingress-nginx.controller.service.annotations.%s is set by the platform and cannot be changed (use endpoint)" $k) -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
protect:
  - fullnameOverride
  - nameOverride
  - namespaceOverride
  - controller.ingressClass
  - controller.ingressClassResource.enabled
  - controller.ingressClassResource.name
  - controller.ingressClassResource.controllerValue
  - controller.scope
  - controller.extraArgs.enable-ssl-passthrough
  - controller.extraArgs.ingress-class
  - controller.extraArgs.controller-class
  - controller.extraArgs.watch-namespace
  - controller.extraArgs.watch-namespace-selector
  - controller.allowSnippetAnnotations
  - controller.config.allow-snippet-annotations
  - controller.config.annotations-risk-level
  - controller.admissionWebhooks.enabled
  - controller.service.enabled
  - controller.service.type
  - controller.service.nodePorts.http
  - controller.service.nodePorts.https
  - controller.service.loadBalancerIP
  - controller.hostNetwork
  - controller.hostPort.enabled
  - controller.autoscaling.enabled
  - defaultBackend.autoscaling.enabled
  - rbac.create
  - serviceAccount.create
{{- end -}}
