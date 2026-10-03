{{/*
Values of the vendored CoreDNS chart (the former KuboCD module "main", which ran
dnsmasq with address=/<suffix>/<target> and two upstream servers).

Two server blocks on port 53: the ingress suffix, answered by the template
plugin (every name under it, and the suffix itself, resolves to target; other
record types get an empty answer), and the root zone, forwarded. Named
dns-server (nameOverride): the Deployment selector stays the one of the former
chart. Not the cluster DNS (isClusterService: false), no Kubernetes plugin, so
no RBAC.
*/}}
{{- define "dns-server.upstream.values" -}}
{{- include "okdp.require" (dict "ctx" . "keys" (list "ingress.suffix")) -}}
{{- $suffix := trimSuffix "." .Values.global.okdp.ingress.suffix -}}
{{- $type := ternary "AAAA" "A" (contains ":" .Values.target) -}}
{{- if not .Values.forwarders -}}
  {{- fail "dns-server: forwarders needs at least one upstream DNS server" -}}
{{- end -}}
fullnameOverride: {{ include "okdp.fullname" . }}
nameOverride: dns-server
isClusterService: false
serviceType: NodePort
rbac:
  create: false
serviceAccount:
  create: false
replicaCount: 1
resources:
  requests:
    memory: 32Mi
    cpu: 50m
  limits:
    memory: 128Mi
    cpu: 100m
servers:
  - zones:
      - zone: {{ printf "%s." $suffix }}
        use_tcp: true
    port: 53
    nodePort: {{ .Values.nodePort }}
    plugins:
      - name: errors
      - name: log
      - name: template
        parameters: {{ printf "IN %s %s" $type $suffix }}
        configBlock: {{ printf "answer \"{{ .Name }} 60 IN %s %s\"" $type .Values.target | quote }}
      - name: template
        parameters: {{ printf "ANY ANY %s" $suffix }}
        configBlock: rcode NOERROR
  - zones:
      - zone: .
        use_tcp: true
    port: 53
    nodePort: {{ .Values.nodePort }}
    plugins:
      - name: errors
      - name: health
        configBlock: lameduck 5s
      - name: ready
      - name: log
      - name: forward
        parameters: {{ printf ". %s" (join " " .Values.forwarders) }}
      - name: cache
        parameters: 30
      - name: loop
      - name: reload
      - name: loadbalance
{{- end -}}

{{/*
Instance-level upstream values (okdp.vendor.render option `upstream`): an
instance sets any value of the vendored coredns chart under upstream.coredns in
its values.yaml, over the values computed above, except the protected paths.
Protected: the names and the Deployment selector (app.kubernetes.io/name:
dns-server, immutable), the NodePort Service the host resolver points at, the
ConfigMap carrying the computed server blocks (deployment.enabled, skipConfig),
isClusterService (labels and selector of a cluster DNS), rbac.create (a
ClusterRole, while this server needs none) and hpa.enabled (its template reads
.Capabilities, accepted by okdp-guard-allow.yaml only while disabled).
Appended: servers, so an instance adds server blocks (another zone, a
conditional forward) next to the two computed from the parameters.
*/}}
{{- define "dns-server.upstream.options" -}}
protect:
  - fullnameOverride
  - nameOverride
  - deployment.enabled
  - deployment.skipConfig
  - deployment.name
  - deployment.selector
  - service.name
  - serviceType
  - isClusterService
  - rbac.create
  - hpa.enabled
append:
  - servers
{{- end -}}
