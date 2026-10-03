{{/* Values of the vendored keycloakx chart (the former KuboCD module "main"). */}}
{{- define "keycloak.adminSecret" -}}{{ include "okdp.fullname" (dict "ctx" . "suffix" "admin") }}{{- end -}}

{{/* Images: the official Keycloak image, and keycloak-config-cli built for Keycloak 26. */}}
{{- define "keycloak.image" -}}quay.io/keycloak/keycloak:26.7.4{{- end -}}
{{- define "keycloak.configCli.image" -}}quay.io/adorsys/keycloak-config-cli:6.5.1-26.5.5{{- end -}}

{{/* The database-server connection, checked (PostgreSQL, with a credentials Secret). */}}
{{- define "keycloak.db" -}}
{{- $db := include "okdp.connection" (dict "ctx" . "ref" .Values.db "contract" "database-server" "field" "db") | fromYaml -}}
{{- if ne $db.engine "postgresql" -}}
  {{- fail (printf "keycloak: db: connection %q has engine %q, keycloak needs postgresql" .Values.db $db.engine) -}}
{{- end -}}
{{- if not $db.secretRef -}}
  {{- fail (printf "keycloak: db: connection %q has no secretRef: keycloak needs a Secret with the keys username and password" .Values.db) -}}
{{- end -}}
{{- toYaml $db -}}
{{- end -}}

{{- define "keycloak.upstream.values" -}}
{{- include "okdp.require" (dict "ctx" . "keys" (list "ingress.suffix" "ingress.className" "certificateIssuers.selfSigned.name")) -}}
{{- $db := include "keycloak.db" . | fromYaml -}}
{{- $dbSecret := $db.secretRef.name -}}
{{- $host := include "keycloak.host" . -}}
{{- $image := include "keycloak.image" . -}}
fullnameOverride: {{ include "okdp.fullname" . }}
# Labels app.kubernetes.io/name: keycloak (the upstream chart name is keycloakx).
nameOverride: keycloak
image:
  repository: {{ (splitList ":" $image) | first }}
  tag: {{ (splitList ":" $image) | last | quote }}
# Production mode (kc.sh start): plain HTTP behind the ingress, which terminates TLS
# and sets the X-Forwarded-* headers; the hostname fixes the issuer URL.
command: ["/opt/keycloak/bin/kc.sh"]
args: ["start"]
http:
  relativePath: /
proxy:
  enabled: true
  mode: xforwarded
  http:
    enabled: true
# One replica with a local cache (the upstream default is a JDBC-ping cluster).
cache:
  stack: custom
# Keycloak pods repel Keycloak pods only. The upstream default excludes only the
# component "test": it also matches the keycloak-config-cli Job pod (same name and
# instance labels), which then never schedules on a single node. The server pods
# are the only ones of the release without a component label.
affinity: |
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: keycloak
            app.kubernetes.io/instance: {{ .Release.Name }}
          matchExpressions:
            - key: app.kubernetes.io/component
              operator: DoesNotExist
        topologyKey: kubernetes.io/hostname
# Readiness and liveness probes on the management port (9000); /metrics stays inside
# the cluster (the ingress only serves port 8080).
health:
  enabled: true
metrics:
  enabled: true
extraEnv: |
  - name: KC_HOSTNAME
    value: {{ printf "https://%s" $host | quote }}
  - name: KC_CACHE
    value: local
  - name: KC_BOOTSTRAP_ADMIN_USERNAME
    value: {{ .Values.adminUser | quote }}
  - name: KC_BOOTSTRAP_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "keycloak.adminSecret" . }}
        key: admin-password
  # The database-server connection: URL from its fields, credentials from its Secret.
  - name: KC_DB
    value: postgres
  - name: KC_DB_URL
    value: {{ printf "jdbc:postgresql://%s:%v/%s" $db.host $db.port $db.dbName | quote }}
  - name: KC_DB_USERNAME
    valueFrom:
      secretKeyRef:
        name: {{ $dbSecret }}
        key: username
  - name: KC_DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ $dbSecret }}
        key: password
serviceAccount:
  automountServiceAccountToken: false
podSecurityContext:
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
securityContext:
  runAsUser: 1000
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
resources:
  requests:
    cpu: {{ printf "%vm" (mulf (float64 .Values.cpu) 1000) | quote }}
    memory: {{ printf "%vGi" .Values.memoryGi | quote }}
  limits:
    cpu: {{ mulf (float64 .Values.cpu) 2 | quote }}
    memory: {{ printf "%vGi" (mulf (float64 .Values.memoryGi) 2) | quote }}
ingress:
  enabled: true
  ingressClassName: {{ .Values.global.okdp.ingress.className }}
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    {{- include "okdp.ingressAnnotations" . | nindent 4 }}
  rules:
    - host: {{ $host }}
      paths:
        - path: /
          pathType: Prefix
  # Same Secret name as the former bitnami chart: the certificate is kept.
  tls:
    - hosts:
        - {{ $host }}
      secretName: {{ printf "%s-tls" $host }}
{{- end -}}

{{- define "keycloak.host" -}}
{{- printf "%s.%s" .Values.ingressHost .Values.global.okdp.ingress.suffix -}}
{{- end -}}

{{/*
Instance-level upstream values (okdp.vendor.render option `upstream`): an
instance sets any value of the vendored keycloakx chart under
upstream.keycloakx in its values.yaml, over the values computed above, except
the protected paths. Protected: what the platform relies on.
- fullnameOverride, nameOverride, namespaceOverride: keycloak-config-cli
  reaches <release>-http in the release namespace, the anti-affinity matches
  app.kubernetes.io/name: keycloak.
- command, args: production mode (kc.sh start).
- extraEnv: a templated string carrying KC_HOSTNAME (the issuer URL), the
  bootstrap admin from <release>-admin and the database connection, so it
  cannot be appended to: add variables with extraEnvFrom (a ConfigMap or
  Secret of the namespace).
- database: KC_DB_* variables competing with the db connection (and a
  password written into the values).
- http.relativePath, proxy: the issuer URL (/realms/<realm> at the host root)
  and the X-Forwarded-* headers it is built from behind the ingress.
- cache, replicas, autoscaling.enabled: one replica with a local cache
  (KC_CACHE=local); more replicas would not share sessions.
- service.httpPort: keycloak-config-cli calls port 80 of <release>-http.
- ingress.enabled/ingressClassName/rules/tls: the host every OIDC client and
  the platform issuer (global.okdp.oidc.issuerUri) point to.
- secrets.admin, secrets.realm: secrets.<suffix> is named <release>-<suffix>,
  which would shadow the admin password and the realm file Secrets.
- extraManifests: arbitrary objects of any kind and namespace.
The wrapper sets no list an instance would extend: nothing is appended.
*/}}
{{- define "keycloak.upstream.keycloakx" -}}
protect:
  - fullnameOverride
  - nameOverride
  - namespaceOverride
  - command
  - args
  - extraEnv
  - database
  - http.relativePath
  - proxy
  - cache
  - replicas
  - autoscaling.enabled
  - service.httpPort
  - ingress.enabled
  - ingress.ingressClassName
  - ingress.rules
  - ingress.tls
  - secrets.admin
  - secrets.realm
  - extraManifests
{{- end -}}
