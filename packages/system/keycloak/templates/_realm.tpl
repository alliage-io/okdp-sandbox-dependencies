{{/*
keycloak.suffix: replaces the ingress suffix placeholders in a string:
${suffix} and, for values written for the KuboCD package, {{ .Context.ingress.suffix }}.
*/}}
{{- define "keycloak.suffix" -}}
{{- .s | replace "${suffix}" .suffix | replace "{{ .Context.ingress.suffix }}" .suffix -}}
{{- end -}}

{{/*
keycloak.realm: the realm file keycloak-config-cli applies (the former inline
master.json template), built as data and serialised with toPrettyJson, so
values need no JSON escaping.
*/}}
{{- define "keycloak.realm" -}}
{{- $suffix := .Values.global.okdp.ingress.suffix -}}
{{- $sub := dict "suffix" $suffix -}}
{{- $users := list -}}
{{- range $u := .Values.users | default list -}}
  {{- $user := dict "username" $u.username "enabled" true "emailVerified" true
        "email" ($u.email | default "") "firstName" ($u.firstName | default "") "lastName" ($u.lastName | default "")
        "realmRoles" ($u.roles | default list) -}}
  {{- if $u.password -}}
    {{- $_ := set $user "credentials" (list (dict "type" "password" "value" $u.password)) -}}
  {{- end -}}
  {{- with $u.serviceAccountClientId }}{{ $_ := set $user "serviceAccountClientId" . }}{{ end -}}
  {{- with $u.clientRoles }}{{ $_ := set $user "clientRoles" . }}{{ end -}}
  {{- if $u.groups -}}
    {{- $groups := list -}}
    {{- range $g := $u.groups }}{{ $groups = append $groups (printf "/%s" $g) }}{{ end -}}
    {{- $_ := set $user "groups" $groups -}}
  {{- end -}}
  {{- $users = append $users $user -}}
{{- end -}}
{{- $groups := list -}}
{{- range .Values.groups | default list }}{{ $groups = append $groups (dict "name" .name) }}{{ end -}}
{{- $roles := list -}}
{{- range .Values.roles | default list }}{{ $roles = append $roles (dict "name" .name) }}{{ end -}}
{{- $clients := list -}}
{{- range $c := .Values.clients | default list -}}
  {{- $client := dict "clientId" $c.clientId "name" ($c.name | default "") -}}
  {{- if $c.publicClient -}}
    {{- $_ := set $client "publicClient" true -}}
  {{- else -}}
    {{- $_ := set $client "secret" ($c.secret | default "") -}}
  {{- end -}}
  {{- $uris := list -}}
  {{- range $c.redirectUris | default list }}{{ $uris = append $uris (include "keycloak.suffix" (merge (dict "s" .) $sub)) }}{{ end -}}
  {{- $origins := list -}}
  {{- range $c.webOrigins | default list }}{{ $origins = append $origins (include "keycloak.suffix" (merge (dict "s" .) $sub)) }}{{ end -}}
  {{- $_ := set $client "redirectUris" $uris -}}
  {{- $_ := set $client "webOrigins" $origins -}}
  {{- with $c.defaultClientScopes }}{{ $_ := set $client "defaultClientScopes" . }}{{ end -}}
  {{- with $c.optionalClientScopes }}{{ $_ := set $client "optionalClientScopes" . }}{{ end -}}
  {{- if $c.serviceAccountsEnabled }}{{ $_ := set $client "serviceAccountsEnabled" true }}{{ end -}}
  {{- range $k := list "standardFlowEnabled" "implicitFlowEnabled" "directAccessGrantsEnabled" -}}
    {{- if hasKey $c $k }}{{ $_ := set $client $k (index $c $k) }}{{ end -}}
  {{- end -}}
  {{- $clients = append $clients $client -}}
{{- end -}}
{{- $scopes := list -}}
{{- range $s := .Values.clientScopes | default list -}}
  {{- $attrs := dict -}}
  {{- range $k, $v := $s.attributes | default dict }}{{ $_ := set $attrs $k (toString $v) }}{{ end -}}
  {{- $mappers := list -}}
  {{- range $m := $s.protocolMappers | default list -}}
    {{- $config := dict -}}
    {{- range $k, $v := $m.config | default dict }}{{ $_ := set $config $k (toString $v) }}{{ end -}}
    {{- $mappers = append $mappers (dict "id" (printf "%s-mapper-id" $m.name) "name" $m.name "protocol" ($m.protocol | default "") "protocolMapper" ($m.protocolMapper | default "") "consentRequired" false "config" $config) -}}
  {{- end -}}
  {{- $scopes = append $scopes (dict "id" (printf "%s-scope-id" $s.name) "name" $s.name "description" ($s.description | default "") "protocol" ($s.protocol | default "") "attributes" $attrs "protocolMappers" $mappers) -}}
{{- end -}}
{{- $dcr := .Values.anonymousDCR | default dict -}}
{{- $trusted := list -}}
{{- if $dcr.enabled -}}
  {{- range $dcr.trustedHosts | default (list "*.${suffix}" "*.svc.cluster.local") }}{{ $trusted = append $trusted (include "keycloak.suffix" (merge (dict "s" .) $sub)) }}{{ end -}}
{{- end -}}
{{- $policies := list
      (dict "name" "Trusted Hosts" "providerId" "trusted-hosts" "subType" "anonymous" "config" (dict
          "host-sending-registration-request-must-match" (list (ternary "true" "false" (or (not $dcr.enabled) ($dcr.checkSenderHost | default false))))
          "client-uris-must-match" (list "true")
          "trusted-hosts" $trusted))
      (dict "name" "Allowed Client Scopes" "providerId" "allowed-client-templates" "subType" "anonymous" "config" (dict
          "allow-default-scopes" (list "true")
          "allowed-client-scopes" ($dcr.allowedScopes | default (list "groups")))) -}}
{{- /* Keycloak's own anonymous policies, when kept: declared, so the realm file says so. */ -}}
{{- if and $dcr.enabled $dcr.consentRequired -}}
  {{- $policies = append $policies (dict "name" "Consent Required" "providerId" "consent-required" "subType" "anonymous" "config" dict) -}}
{{- end -}}
{{- if and $dcr.enabled (ne (include "keycloak.dcr.fullScopeAllowed" $) "true") -}}
  {{- $policies = append $policies (dict "name" "Full Scope Disabled" "providerId" "scope" "subType" "anonymous" "config" dict) -}}
{{- end -}}
{{- /*
The user profile (applied by keycloak-config-cli when the realm attribute
userProfileEnabled is set): Keycloak 26's default attributes, as Keycloak
creates them (email, firstName and lastName are required for users except in
the master realm: its admin has none, and would be locked out), then the
declared ones (admin only by default), and the unmanaged attribute policy.
Always rendered, so the realm file is the whole profile.
*/ -}}
{{- $up := .Values.realm.userProfile | default dict -}}
{{- $any := dict "view" (list "admin" "user") "edit" (list "admin" "user") -}}
{{- $upAttrs := list (dict "name" "username" "displayName" "${username}" "multivalued" false "permissions" $any
      "validations" (dict "length" (dict "min" 3 "max" 255) "username-prohibited-characters" dict "up-username-not-idn-homograph" dict)) -}}
{{- range $name, $v := dict "email" (dict "email" dict "length" (dict "max" 255))
                           "firstName" (dict "length" (dict "max" 255) "person-name-prohibited-characters" dict)
                           "lastName" (dict "length" (dict "max" 255) "person-name-prohibited-characters" dict) -}}
  {{- $attr := dict "name" $name "displayName" (printf "${%s}" $name) "multivalued" false "permissions" $any "validations" $v -}}
  {{- if ne $.Values.realm.name "master" }}{{ $_ := set $attr "required" (dict "roles" (list "user")) }}{{ end -}}
  {{- $upAttrs = append $upAttrs $attr -}}
{{- end -}}
{{- range $a := $up.attributes | default list -}}
  {{- $perms := $a.permissions | default dict -}}
  {{- $upAttrs = append $upAttrs (dict "name" $a.name "displayName" ($a.displayName | default $a.name)
        "multivalued" ($a.multivalued | default false)
        "permissions" (dict "view" ($perms.view | default (list "admin")) "edit" ($perms.edit | default (list "admin")))) -}}
{{- end -}}
{{- $userProfile := dict "attributes" $upAttrs
      "groups" (list (dict "name" "user-metadata" "displayHeader" "User metadata" "displayDescription" "Attributes, which refer to user metadata")) -}}
{{- with $up.unmanagedAttributePolicy }}{{ $_ := set $userProfile "unmanagedAttributePolicy" . }}{{ end -}}
{{- $realm := dict
      "realm" .Values.realm.name
      "enabled" true
      "displayName" (.Values.realm.displayName | default "")
      "users" $users
      "groups" $groups
      "roles" (dict "realm" $roles)
      "clients" $clients
      "clientScopes" $scopes
      "accessTokenLifespan" (.Values.realm.accessTokenLifespan | default 3600)
      "ssoSessionIdleTimeout" (.Values.realm.ssoSessionIdleTimeout | default 3600)
      "ssoSessionMaxLifespan" (.Values.realm.ssoSessionMaxLifespan | default 36000)
      "attributes" (dict "userProfileEnabled" "true")
      "userProfile" $userProfile
      "components" (dict "org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy" $policies) -}}
{{- toPrettyJson $realm -}}
{{- end -}}

{{/*
keycloak.dcr.removedPolicies: the providers of Keycloak's anonymous client
registration policies the keycloak-config-cli Job removes (space separated,
empty when none): consent-required unless anonymousDCR.consentRequired, scope
(Full Scope Disabled) when anonymousDCR.fullScopeAllowed. Only with
anonymousDCR.enabled.
*/}}
{{- define "keycloak.dcr.removedPolicies" -}}
{{- $dcr := .Values.anonymousDCR | default dict -}}
{{- $out := list -}}
{{- if $dcr.enabled -}}
  {{- if not $dcr.consentRequired }}{{ $out = append $out "consent-required" }}{{ end -}}
  {{- if eq (include "keycloak.dcr.fullScopeAllowed" .) "true" }}{{ $out = append $out "scope" }}{{ end -}}
{{- end -}}
{{- join " " $out -}}
{{- end -}}

{{/* anonymousDCR.fullScopeAllowed, default true. */}}
{{- define "keycloak.dcr.fullScopeAllowed" -}}
{{- $dcr := .Values.anonymousDCR | default dict -}}
{{- if hasKey $dcr "fullScopeAllowed" }}{{ $dcr.fullScopeAllowed | toString }}{{ else }}true{{ end -}}
{{- end -}}
