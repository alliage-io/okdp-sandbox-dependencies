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
