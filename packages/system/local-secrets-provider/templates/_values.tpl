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

{{/*
Extra labels per Secret name, from the entries' `labels` (the upstream chart has
no such field: every key but name/description is Secret data). Entries sharing a
name merge, as the upstream chart merges their data.
*/}}
{{- define "local-secrets-provider.extraLabels" -}}
{{- $byName := dict }}
{{- range $s := .Values.secrets }}
{{- with $s.labels }}
{{- $_ := set $byName $s.name (mergeOverwrite (get $byName $s.name | default dict) (deepCopy .)) }}
{{- end }}
{{- end }}
{{- with $byName }}{{ toYaml . }}{{ end }}
{{- end -}}

{{/*
Adds the extra labels to the Secrets of the rendered stream (e.g.
cnpg.io/reload: "true", so that CloudNativePG reconciles a managed role when its
password Secret appears or changes; kubernetes-replicator copies the labels to
the replicas). Documents without extra labels are passed through untouched; the
others are re-serialised (same content, keys sorted).
*/}}
{{- define "local-secrets-provider.addLabels" -}}
{{- $labels := .labels }}
{{- range $doc := regexSplit "(?m)^---[ \\t]*$" .rendered -1 }}
{{- $obj := fromYaml $doc }}
{{- $extra := dict }}
{{- if and $obj (not (hasKey $obj "Error")) (eq (toString $obj.kind) "Secret") (kindIs "map" $obj.metadata) }}
{{- $extra = get $labels (toString $obj.metadata.name) | default dict }}
{{- end }}
{{- if $extra }}
{{- $_ := set $obj.metadata "labels" (mergeOverwrite ($obj.metadata.labels | default dict) $extra) }}
---
{{ regexFind "# Source: [^\\n]*" $doc }}
{{ toYaml $obj }}
{{- else }}
{{ print "\n---" $doc }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Instance-level upstream values (okdp.vendor.render option `upstream`): an
instance sets any value of the vendored chart under
upstream.local-secrets-provider in its values.yaml, over the values computed
above, except the protected paths. Protected: names, and `secrets`, the list
computed from the `secrets` parameter (an upstream entry would skip the refusal
of empty values, which the vendored chart marks for kubernetes-secret-generator,
no longer shipped, and the extra labels, which addLabels applies by Secret
name). Nothing is appended: `secrets` is the only list.
*/}}
{{- define "local-secrets-provider.upstream" -}}
protect:
  - fullnameOverride
  - secrets
{{- end -}}
