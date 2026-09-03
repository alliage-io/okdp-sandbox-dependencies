{{/* Values of the vendored charts (the former KuboCD modules). */}}

{{- define "tools.reloader.values" -}}
reloader:
  deployment:
    securityContext:
      seccompProfile:
        type: RuntimeDefault
    containerSecurityContext:
      capabilities:
        drop:
          - ALL
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
{{- end -}}

{{- define "tools.replicator.values" -}}
podSecurityContext:
  seccompProfile:
    type: RuntimeDefault
securityContext:
  capabilities:
    drop:
      - ALL
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
livenessProbe:
  initialDelaySeconds: 10
readinessProbe:
  initialDelaySeconds: 10
{{- end -}}
