{{/* Descriptor hooks (okdp-lib): the admin console, no output. */}}
{{- define "okdp.instance.url" -}}https://{{ include "keycloak.host" . }}{{- end -}}
{{- define "okdp.instance.usage" -}}
Keycloak provides centralized authentication and authorization.
Admin console: https://{{ include "keycloak.host" . }} (user `{{ .Values.adminUser }}`, password in the Secret `{{ include "keycloak.adminSecret" . }}`).
Realm `{{ .Values.realm.name }}`, issuer https://{{ include "keycloak.host" . }}/realms/{{ .Values.realm.name }}.
{{- end -}}
