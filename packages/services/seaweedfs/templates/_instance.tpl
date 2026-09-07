{{/* Descriptor hooks (okdp-lib): the filer UI, one s3 output. */}}
{{- define "okdp.instance.url" -}}https://{{ include "seaweedfs.okdp.consoleHost" . }}{{- end -}}

{{- define "okdp.instance.usage" -}}
SeaweedFS is a simple and highly scalable distributed file system.
Access the console at https://{{ include "seaweedfs.okdp.consoleHost" . }} (user `{{ .Values.username }}`).
S3 API: https://{{ include "seaweedfs.okdp.apiHost" . }} (in-cluster `{{ include "seaweedfs.okdp.internalUrl" . }}`), path-style, region us-east-1.

`s3` is an external-only contract: consumers in other namespaces declare this store
in a connection file, with their own identity (a grant of this store) as secretRef.
{{- end -}}

{{/*
One s3 output named after the release. No credentials by default: each consumer
brings its own identity (grants), so the secretRef okdp-lib would default to is
removed, unless outputSecretRef names a Secret consumers can use.
*/}}
{{- define "okdp.instance.outputs" -}}
{{- $out := include "okdp.contract.s3.provide" (dict "ctx" . "secretRef" .Values.outputSecretRef "values" (dict
      "apiUrl" (printf "https://%s" (include "seaweedfs.okdp.apiHost" .))
      "internalUrl" (include "seaweedfs.okdp.internalUrl" .)
      "consoleUrl" (printf "https://%s" (include "seaweedfs.okdp.consoleHost" .))
      "region" "us-east-1"
      "pathStyle" true)) | fromYamlArray -}}
{{- if not .Values.outputSecretRef -}}
  {{- $_ := unset (index $out 0) "secretRef" -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}
