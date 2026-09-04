{{/*
Values of the vendored local-secrets-provider chart (the former KuboCD module
"main"): each {name, data} entry flattened to {name, <key>: "<value>"...}
(values as strings: Secret data is text). An empty value is refused: the upstream
chart would mark it for kubernetes-secret-generator, which OKDP no longer ships.
*/}}
{{- define "local-secrets-provider.upstream.values" -}}
secrets:
{{- range $s := .Values.secrets }}
{{- $entry := dict "name" $s.name }}
{{- range $k, $v := $s.data | default dict }}
{{- if eq (toString $v) "" }}
{{- fail (printf "local-secrets-provider: secrets[%s].data.%s is empty: give a value (nothing generates it)" $s.name $k) }}
{{- end }}
{{- $_ := set $entry $k (toString $v) }}
{{- end }}
  - {{ toYaml $entry | nindent 4 | trim }}
{{- end }}
{{- end -}}
