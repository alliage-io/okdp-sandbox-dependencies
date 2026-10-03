{{/*
The vendored charts (the former KuboCD modules) have only fixed values:
vendor-values/reloader.yaml and vendor-values/kubernetes-replicator.yaml.
*/}}

{{/*
Instance-level upstream values (okdp.vendor.render option `upstream`): an
instance sets any value of a vendored chart under upstream.<chart> in its
values.yaml, over the fixed values (vendor-values/<chart>.yaml), except the
protected paths. Nothing is appended: the lists of the fixed values
(capabilities.drop) are not extended.

upstream.reloader. Protected: names; the cluster-wide RBAC and ServiceAccount
and watchGlobally (false narrows Reloader to its own namespace, while the
platform relies on it in every namespace); the integrations gated by
.Capabilities.APIVersions (OpenShift, Argo Rollouts, ServiceMonitor, VPA),
accepted by okdp-guard-allow.yaml only while off; deployment.env.secret, which
writes its values into a Secret (by OKDP convention values carry no secret).
*/}}
{{- define "tools.reloader.upstream" -}}
protect:
  - fullnameOverride
  - reloader.rbac.enabled
  - reloader.serviceAccount.create
  - reloader.watchGlobally
  - reloader.isOpenshift
  - reloader.isArgoRollouts
  - reloader.serviceMonitor.enabled
  - reloader.verticalPodAutoscaler.enabled
  - reloader.deployment.env.secret
{{- end -}}

{{/*
upstream.kubernetes-replicator. Protected: names and namespaceOverride
(everything goes to the release namespace); the ServiceAccount and ClusterRole
and what widens it (grantClusterAdmin, serviceAccount.privileges, the verb
lists); Secret replication, which local-secrets-provider and cert-manager rely
on; args, which could pass -allow-all (any namespace could then pull any Secret
with replicate-from) or override the -replicate-* flags;
verticalPodAutoscaler.enabled (.Capabilities.APIVersions, accepted by
okdp-guard-allow.yaml only while off). The other replicationEnabled kinds stay
open: turning them off only narrows the replicator.
*/}}
{{- define "tools.replicator.upstream" -}}
protect:
  - fullnameOverride
  - namespaceOverride
  - grantClusterAdmin
  - serviceAccount.create
  - serviceAccount.privileges
  - namespacesPrivileges
  - replicationEnabled.secrets
  - replicationEnabled.privileges
  - replicationEnabled.rolesPrivileges
  - args
  - verticalPodAutoscaler.enabled
{{- end -}}
