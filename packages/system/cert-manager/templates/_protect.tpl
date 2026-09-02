{{/*
Post-processing of a rendered vendored chart (a multi-document YAML stream).

cert-manager.protect: adds okdp.io/protected: "true" to the CRDs and the
controllers (Deployment, StatefulSet, DaemonSet) when .enabled; the
ValidatingAdmissionPolicy of the tools chart refuses to delete them (the
former KuboCD `protected: true`). Pods and ReplicaSets are not protected, so
rollouts are unaffected. Documents left unchanged are passed through as is.

cert-manager.onlyKinds: keeps the documents whose kind is in .kinds.
*/}}
{{- define "cert-manager.protect" -}}
{{- $kinds := list "CustomResourceDefinition" "Deployment" "StatefulSet" "DaemonSet" -}}
{{- range $doc := regexSplit "(?m)^---[ \\t]*$" .rendered -1 -}}
  {{- $obj := fromYaml $doc -}}
  {{- if and $.enabled $obj (not (hasKey $obj "Error")) (has (toString $obj.kind) $kinds) (kindIs "map" $obj.metadata) -}}
    {{- $labels := $obj.metadata.labels | default dict -}}
    {{- $_ := set $labels "okdp.io/protected" "true" -}}
    {{- $_ := set $obj.metadata "labels" $labels }}
---
{{ regexFind "# Source: [^\\n]*" $doc }}
{{ toYaml $obj }}
  {{- else if trim $doc -}}
{{ print "\n---" $doc }}
  {{- end -}}
{{- end -}}
{{- end -}}

{{- define "cert-manager.onlyKinds" -}}
{{- range $doc := regexSplit "(?m)^---[ \\t]*$" .rendered -1 -}}
  {{- $obj := fromYaml $doc -}}
  {{- if and $obj (not (hasKey $obj "Error")) (has (toString $obj.kind) $.kinds) -}}
{{ print "\n---" $doc }}
  {{- end -}}
{{- end -}}
{{- end -}}
