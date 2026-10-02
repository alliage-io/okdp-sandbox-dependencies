{{/* Descriptor hooks (okdp-lib-chart): the filer UI, one s3 output. */}}
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
brings its own identity (grants); okdp-lib-chart adds a secretRef only when one is
given, here outputSecretRef (a Secret consumers can use), when set.
*/}}
{{- define "okdp.instance.outputs" -}}
{{ include "okdp.contract.s3.provide" (dict "ctx" . "secretRef" .Values.outputSecretRef "values" (dict
      "apiUrl" (printf "https://%s" (include "seaweedfs.okdp.apiHost" .))
      "internalUrl" (include "seaweedfs.okdp.internalUrl" .)
      "consoleUrl" (printf "https://%s" (include "seaweedfs.okdp.consoleHost" .))
      "region" "us-east-1"
      "pathStyle" true)) }}
{{- end -}}
