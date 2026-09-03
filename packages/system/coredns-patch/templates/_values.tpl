{{/* Values of the vendored coredns-patch chart (the former KuboCD module "main"): only its RBAC is rendered. */}}
{{- define "coredns-patch.upstream.values" -}}
{{- include "okdp.require" (dict "ctx" . "keys" (list "ingress.suffix")) -}}
ingressSuffix: {{ .Values.global.okdp.ingress.suffix | quote }}
ingressService: {{ .Values.ingressService | quote }}
{{- end -}}

{{/*
coredns-patch.block: the Corefile block. Every name under the suffix, the suffix
itself included, is answered inside the cluster for every query type with a CNAME
to the ingress controller Service (A, AAAA, ... then follow the Service), so no
query of the suffix leaves the cluster (the upstream block answered A only: AAAA
went to the host resolver, which may not know the suffix and time out).
*/}}
{{- define "coredns-patch.block" -}}
{{- $suffix := .Values.global.okdp.ingress.suffix -}}
template IN ANY {{ $suffix }} {
    match ^(.*\.)?{{ $suffix | replace "." "\\." }}\.$
    answer "{{ "{{ .Name }}" }} 60 IN CNAME {{ .Values.ingressService }}."
    fallthrough
}
{{- end -}}
