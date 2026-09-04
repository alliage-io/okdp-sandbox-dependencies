{{/*
The PostgreSQL cluster and its databases. Former module "main", the chart
oci://quay.io/okdp/charts/cnpg-postgresql 0.1.0, whose templates are taken in
here: it checked the owner Secrets with `lookup`, which renders nothing under
Argo CD. A missing Secret now shows up in the Cluster status instead.
*/}}
{{- define "cnpg-postgresql.clusterName" -}}{{ include "okdp.fullname" . }}{{- end -}}

{{/* host of the read-write Service CloudNativePG creates: <cluster>-rw. */}}
{{- define "cnpg-postgresql.host" -}}
{{- printf "%s-rw.%s.svc.cluster.local" (include "cnpg-postgresql.clusterName" .) .Release.Namespace -}}
{{- end -}}
