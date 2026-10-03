{{/* Values of the vendored seaweedfs chart (the former KuboCD module "main"). */}}
{{- define "seaweedfs.okdp.upstream.values" -}}
{{- include "okdp.require" (dict "ctx" . "keys" (list "ingress.suffix" "ingress.className" "certificateIssuers.selfSigned.name" "storageClass.workspace")) -}}
{{- $class := .Values.global.okdp.storageClass.workspace -}}
{{- $consoleHost := include "seaweedfs.okdp.consoleHost" . -}}
{{- $apiHost := include "seaweedfs.okdp.apiHost" . -}}
{{- $issuer := .Values.global.okdp.certificateIssuers.selfSigned.name -}}
nameOverride: {{ .Release.Name }}
fullnameOverride: {{ .Release.Name }}
global:
  seaweedfs:
    image:
      name: chrislusf/seaweedfs
    # Named after the release (upstream default: seaweedfs).
    serviceAccountName: {{ .Release.Name }}
    # Off (upstream default): the security ConfigMap reads the cluster with lookup.
    enableSecurity: false
image:
  tag: {{ include "seaweedfs.okdp.imageTag" . | quote }}
master:
  enabled: true
  replicas: 1
  data:
    type: persistentVolumeClaim
    storageClass: {{ $class | quote }}
    size: {{ printf "%sGi" .Values.masterStorage | quote }}
  logs:
    type: persistentVolumeClaim
    storageClass: {{ $class | quote }}
    size: {{ printf "%sGi" .Values.masterLogStorage | quote }}
volume:
  enabled: true
  replicas: {{ .Values.volumeReplicas }}
  # The resize hook compares the PVCs with lookup: off, resize by hand.
  resizeHook:
    enabled: false
  dataDirs:
    - name: data
      type: persistentVolumeClaim
      storageClass: {{ $class | quote }}
      size: {{ printf "%sGi" .Values.volumeStorage | quote }}
      maxVolumes: 0
filer:
  enabled: true
  replicas: 1
  enablePVC: true
  port: 8888
  data:
    type: persistentVolumeClaim
    storageClass: {{ $class | quote }}
    size: {{ printf "%sGi" .Values.filerStorage | quote }}
  logs:
    type: persistentVolumeClaim
    storageClass: {{ $class | quote }}
    size: {{ printf "%sGi" .Values.filerLogStorage | quote }}
  ingresses:
    http:
      enabled: true
      className: {{ .Values.global.okdp.ingress.className }}
      annotations:
        nginx.ingress.kubernetes.io/proxy-body-size: "130m"
        cert-manager.io/cluster-issuer: {{ $issuer | quote }}
        nginx.ingress.kubernetes.io/auth-type: basic
        nginx.ingress.kubernetes.io/auth-secret: {{ include "seaweedfs.okdp.filerAuthSecret" . }}
        nginx.ingress.kubernetes.io/auth-realm: "Authentication Required"
      host: {{ $consoleHost }}
      path: "/"
      pathType: Prefix
      tls:
        - secretName: {{ include "okdp.fullname" (dict "ctx" . "suffix" "filer-tls") }}
          hosts:
            - {{ $consoleHost }}
s3:
  enabled: true
  enableAuth: true
  # Rendered by ESO from the grants' Secrets (templates/auth.yaml).
  existingConfigSecret: {{ include "seaweedfs.okdp.s3ConfigSecret" . }}
  # The S3 gateway reads its configuration at startup: Reloader restarts it when
  # ESO updates a Secret (a grant added or its keys changed, the IAM/STS file
  # changed); the checksum of the IAM/STS template rolls it on a Helm change.
  annotations:
    secret.reloader.stakater.com/reload: {{ printf "%s,%s" (include "seaweedfs.okdp.s3ConfigSecret" .) (include "seaweedfs.okdp.iamSecret" .) }}
  podAnnotations:
    checksum/iam: {{ include "seaweedfs.okdp.iamTemplate" . | sha256sum }}
  createBuckets:
    {{- range $b := .Values.buckets | default list }}
    - name: {{ $b.name | quote }}
      anonymousRead: {{ $b.anonymousRead | default false }}
    {{- else }} []
    {{- end }}
  extraVolumes: |
    - name: auth-config
      secret:
        secretName: {{ include "seaweedfs.okdp.iamSecret" . }}
  extraVolumeMounts: |
    - name: auth-config
      mountPath: /etc/seaweed/iam
      readOnly: true
  {{- if include "seaweedfs.okdp.stsEnabled" . }}
  extraArgs:
    - "-iam.config=/etc/seaweed/iam/iam.json"
  {{- end }}
  ingress:
    enabled: true
    className: {{ .Values.global.okdp.ingress.className }}
    annotations:
      nginx.ingress.kubernetes.io/proxy-body-size: "130m"
      cert-manager.io/cluster-issuer: {{ $issuer | quote }}
    host: {{ $apiHost }}
    path: "/"
    pathType: Prefix
    tls:
      - secretName: {{ include "okdp.fullname" (dict "ctx" . "suffix" "s3-tls") }}
        hosts:
          - {{ $apiHost }}
{{- end -}}

{{/*
Instance-level upstream values (okdp-lib-chart okdp.vendor.render option
`upstream`): an instance sets any value of the vendored chart under
upstream.seaweedfs in its values.yaml, over the values computed above, except
the protected paths (global, with enableSecurity, is always protected).
Protected: the names and ports the s3 connection and the provisioning Job
address (<release>-s3, -master, -filer-client) and the components they need;
the S3 authentication (the ESO-written configuration Secret, the IAM/STS file
mounted through s3.extraVolumes/extraVolumeMounts, strings that cannot be
appended to); the hosts and TLS of the ingresses; and every switch
okdp-guard-allow.yaml relies on (lookup, random or templated hooks while off:
filer.s3, volume.resizeHook, sftp, allInOne, networkPolicy.enabled) plus cosi
(cluster-scoped objects). Appended: the buckets and the S3 gateway arguments.
Annotation keys carry dots, out of reach of the dotted protect paths: this
helper refuses the basic auth annotations of the filer ingress and the
Reloader annotation of the S3 gateway.
*/}}
{{- define "seaweedfs.okdp.upstream" -}}
{{- $up := index (.Values.upstream | default dict) "seaweedfs" | default dict -}}
{{- $refused := list
     (list "filer.ingresses.http.annotations" ((($up.filer | default dict).ingresses | default dict).http | default dict).annotations "nginx.ingress.kubernetes.io/auth-")
     (list "s3.annotations" ($up.s3 | default dict).annotations "secret.reloader.stakater.com/reload") -}}
{{- range $r := $refused -}}
  {{- if kindIs "map" (index $r 1) -}}
    {{- range $k, $_ := index $r 1 -}}
      {{- if hasPrefix (index $r 2) $k -}}
        {{- fail (printf "seaweedfs: upstream.seaweedfs.%s.%s is set by the platform and cannot be changed" (index $r 0) $k) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
protect:
  - nameOverride
  - fullnameOverride
  - master.enabled
  - master.port
  - volume.enabled
  - volume.resizeHook
  - filer.enabled
  - filer.port
  - filer.s3
  - filer.ingresses.http.enabled
  - filer.ingresses.http.className
  - filer.ingresses.http.host
  - filer.ingresses.http.tls
  - s3.enabled
  - s3.port
  - s3.enableAuth
  - s3.existingConfigSecret
  - s3.extraVolumes
  - s3.extraVolumeMounts
  - s3.ingress.enabled
  - s3.ingress.className
  - s3.ingress.host
  - s3.ingress.tls
  - sftp
  - allInOne
  - networkPolicy.enabled
  - cosi
append:
  - s3.createBuckets
  - s3.extraArgs
{{- end -}}
