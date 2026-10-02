{{/* Descriptor hooks (okdp-lib-chart): no UI; one database-server output per database. */}}
{{- define "okdp.instance.usage" -}}
PostgreSQL cluster `{{ include "cnpg-postgresql.clusterName" . }}` (CloudNativePG), read-write endpoint `{{ include "cnpg-postgresql.host" . }}:5432`.
{{- if .Values.databases }}

| Connection | Database | Owner | Credentials Secret |
|---|---|---|---|
{{- range .Values.databases }}
| `{{ $.Release.Name }}-{{ .name | replace "_" "-" }}` | `{{ .name }}` | `{{ .owner.username }}` | `{{ .owner.passwordSecret }}` |
{{- end }}

`database-server` is an external-only contract: a consumer in another namespace
declares the connection in a connection file with these values, and its credentials
Secret must exist in the consumer's namespace (replicated or delivered by ESO).
{{- end }}
{{- end -}}

{{- define "okdp.instance.outputs" -}}
{{- $out := list -}}
{{- range $db := .Values.databases -}}
{{- $out = concat $out (include "okdp.contract.database-server.provide" (dict "ctx" $ "name" (printf "%s-%s" $.Release.Name ($db.name | replace "_" "-")) "secretRef" $db.owner.passwordSecret "values" (dict "engine" "postgresql" "host" (include "cnpg-postgresql.host" $) "port" 5432 "dbName" $db.name)) | fromYamlArray) -}}
{{- end -}}
{{- toYaml $out -}}
{{- end -}}
