{{/* Descriptor hooks (okdp-lib): the console URL, one s3 output. */}}
{{- define "okdp.instance.url" -}}
https://{{ include "okdp-rustfs.consoleHost" . }}
{{- end -}}

{{- define "okdp.instance.usage" -}}
RustFS S3-compatible object storage.

- S3 endpoint: https://{{ include "okdp-rustfs.s3Host" . }}
- In-cluster: `{{ include "okdp-rustfs.internalUrl" . }}`
- Console: https://{{ include "okdp-rustfs.consoleHost" . }}

The s3 output `{{ .Release.Name }}` is published with the credentials Secret
`{{ include "okdp-rustfs.credentialsSecret" . }}`{{ if not .Values.outputSecretRef }} (read/list/write on every
bucket){{ end }}. s3 connections are external only: consumers declare a connection
file (`projects/<project>/connections/<name>.yaml`) with these endpoints and
their own identity (a grant of this store).
{{- end -}}

{{- define "okdp.instance.outputs" -}}
{{ include "okdp.contract.s3.provide" (dict "ctx" . "values" (dict
     "apiUrl" (printf "https://%s" (include "okdp-rustfs.s3Host" .))
     "internalUrl" (include "okdp-rustfs.internalUrl" .)
     "consoleUrl" (printf "https://%s" (include "okdp-rustfs.consoleHost" .))
     "region" "us-east-1"
     "pathStyle" true)
   "secretRef" (include "okdp-rustfs.credentialsSecret" .)
   "secret" (ternary nil (dict "generate" (list
     (dict "key" "accessKey" "length" 20 "symbols" 0)
     (dict "key" "secretKey" "length" 40 "symbols" 0))) (not (empty .Values.outputSecretRef)))) }}
{{- end -}}
