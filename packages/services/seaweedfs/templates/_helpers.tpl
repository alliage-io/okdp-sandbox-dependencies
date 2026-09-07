{{/* Names, hosts and computed flags. */}}
{{- define "seaweedfs.okdp.name" -}}{{ include "okdp.fullname" (dict "ctx" .ctx "suffix" .suffix) }}{{- end -}}
{{- define "seaweedfs.okdp.s3ConfigSecret" -}}{{ include "okdp.fullname" (dict "ctx" . "suffix" "s3-config") }}{{- end -}}
{{- define "seaweedfs.okdp.iamSecret" -}}{{ include "okdp.fullname" (dict "ctx" . "suffix" "auth-config") }}{{- end -}}
{{- define "seaweedfs.okdp.stsKeySecret" -}}{{ include "okdp.fullname" (dict "ctx" . "suffix" "sts-signing-key") }}{{- end -}}
{{- define "seaweedfs.okdp.filerAuthSecret" -}}{{ include "okdp.fullname" (dict "ctx" . "suffix" "filer-basic-auth") }}{{- end -}}
{{- define "seaweedfs.okdp.rootSecret" -}}{{ include "okdp.fullname" (dict "ctx" . "suffix" "root-credentials") }}{{- end -}}
{{/* Image tag of the store, also used by the provisioning Job (weed shell). */}}
{{- define "seaweedfs.okdp.imageTag" -}}4.47{{- end -}}
{{- define "seaweedfs.okdp.grantsReader" -}}{{ include "okdp.fullname" (dict "ctx" . "suffix" "grants") }}{{- end -}}

{{/* Ingress hosts: <consoleHost|apiHost>.<suffix>, default seaweedfs-<namespace>[-api]. */}}
{{- define "seaweedfs.okdp.consoleHost" -}}
{{- if .Values.consoleHost -}}
{{- printf "%s.%s" .Values.consoleHost .Values.global.okdp.ingress.suffix -}}
{{- else -}}
{{- include "okdp.ingressHost" (dict "ctx" . "name" "seaweedfs") -}}
{{- end -}}
{{- end -}}
{{- define "seaweedfs.okdp.apiHost" -}}
{{- if .Values.apiHost -}}
{{- printf "%s.%s" .Values.apiHost .Values.global.okdp.ingress.suffix -}}
{{- else -}}
{{- printf "seaweedfs-%s-api.%s" .Release.Namespace .Values.global.okdp.ingress.suffix -}}
{{- end -}}
{{- end -}}
{{- define "seaweedfs.okdp.internalUrl" -}}
{{- printf "http://%s.%s.svc.cluster.local:8333" (include "okdp.fullname" (dict "ctx" . "suffix" "s3")) .Release.Namespace -}}
{{- end -}}

{{- define "seaweedfs.okdp.stsEnabled" -}}
{{- range .Values.grants | default list }}{{ if .sts }}true{{ end }}{{ end -}}
{{- end -}}

{{/*
seaweedfs.okdp.identities: the S3 identities as YAML, credentials left out:
the root identity, then one per grant (the former auth-config module values).
An action is a SeaweedFS verb, scoped as <Verb>:<bucket> when the grant lists
buckets; sts implies Admin (SeaweedFS only lets an Admin assume the role).
*/}}
{{- define "seaweedfs.okdp.identities" -}}
{{- $ids := list (dict "name" "seaweedfs" "actions" (list "Admin")) -}}
{{- range $g := .Values.grants | default list -}}
  {{- $buckets := $g.buckets | default list -}}
  {{- $actions := list -}}
  {{- range $a := $g.actions | default list -}}
    {{- $verb := title $a -}}
    {{- if eq $verb "Admin" -}}
      {{- $actions = append $actions "Admin" -}}
    {{- else if $buckets -}}
      {{- range $b := $buckets }}{{ $actions = append $actions (printf "%s:%s" $verb $b) }}{{ end -}}
    {{- else -}}
      {{- $actions = append $actions $verb -}}
    {{- end -}}
  {{- end -}}
  {{- if $g.sts }}{{ $actions = append $actions "Admin" }}{{ end -}}
  {{- $ids = append $ids (dict "name" $g.principal "actions" ($actions | uniq)) -}}
{{- end -}}
{{- toYaml $ids -}}
{{- end -}}

{{/*
seaweedfs.okdp.iamTemplate: iam.json as an ESO template, the STS signing key
read from the generated Secret (.signingKey, already base64: the JSON of a
[]byte). The rest is data, rendered by Helm (no "{{" in it).
*/}}
{{- define "seaweedfs.okdp.iamTemplate" -}}
{{- $iam := dict
      "sts" (dict "tokenDuration" "1h" "maxSessionLength" "12h" "issuer" "seaweedfs-sts" "signingKey" "@SIGNING_KEY@")
      "providers" list
      "policies" (list (dict "name" "S3WritePolicy" "document" (dict "Version" "2012-10-17" "Statement" (list (dict "Effect" "Allow" "Action" (list "s3:List*" "s3:Get*" "s3:Put*" "s3:DeleteObject") "Resource" (list "*"))))))
      "roles" (list (dict "roleName" "S3WriteRole" "roleArn" .Values.stsRoleArn "attachedPolicies" (list "S3WritePolicy")
                 "trustPolicy" (dict "Version" "2012-10-17" "Statement" (list (dict "Effect" "Allow" "Principal" "*" "Action" (list "sts:AssumeRole")))))) -}}
{{- $json := toPrettyJson $iam -}}
{{- if contains "{{" $json -}}
  {{- fail "seaweedfs: the IAM configuration contains \"{{\", which ESO would read as a template" -}}
{{- end -}}
{{- $json | replace "\"@SIGNING_KEY@\"" "{{ .signingKey | toJson }}" -}}
{{- end -}}
