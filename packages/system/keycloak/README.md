# keycloak

OKDP chart of [Keycloak](https://www.keycloak.org/), the platform OIDC provider: one realm
(users with their realm and client roles, groups, realm roles, clients, client scopes,
the user profile, anonymous client registration policies) applied by keycloak-config-cli.
It **consumes** a `database-server` connection (PostgreSQL) and provides none (the OIDC
coordinates are platform values, `global.okdp.oidc`).

It renders the codecentric chart `keycloakx` 7.3.2
(https://codecentric.github.io/helm-charts), vendored under `vendor/` (see `vendor.yaml`;
its `helm test` hook is removed), running the official image
`quay.io/keycloak/keycloak:26.7.4` in production mode (`kc.sh start`, plain HTTP behind the
ingress, `KC_HOSTNAME` = the ingress URL, local cache, one replica). Values are computed
in `templates/_values.tpl`, the realm file is built in `templates/_realm.tpl`, and
`templates/config-cli.yaml` applies it with the upstream
[keycloak-config-cli](https://github.com/adorsys/keycloak-config-cli) image
`quay.io/adorsys/keycloak-config-cli:6.5.1-26.5.5` (the latest release, built for
Keycloak 26).

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `db` | (required) | `database-server` connection (engine `postgresql`); its Secret holds `username` and `password`. |
| `adminUser` / `adminPassword` | `admin` / `admin` | Bootstrap admin of the master realm (`KC_BOOTSTRAP_ADMIN_*`, created on the first start); the password is in the Secret `<release>-admin`, also used by keycloak-config-cli. |
| `ingressHost` | `keycloak` | Host `<ingressHost>.<ingress suffix>`: the platform issuer `global.okdp.oidc.issuerUri` points here. |
| `cpu` / `memoryGi` | `0.5` / `2` | Requests; limits are twice the requests. |
| `realm` | `{name: master, ...}` | `name` (required), `displayName`, `accessTokenLifespan`, `ssoSessionIdleTimeout`, `ssoSessionMaxLifespan`, `userProfile` (below). |
| `realm.userProfile` | no extra attribute | `attributes`: `{name, displayName, multivalued, permissions: {view, edit}}`, declared after Keycloak's default ones (`username`, `email`, `firstName`, `lastName`), admin only unless `permissions` say otherwise; `unmanagedAttributePolicy`: `""` (Keycloak's default: undeclared attributes are dropped), `ENABLED`, `ADMIN_EDIT` or `ADMIN_VIEW`. |
| `anonymousDCR` | off | `enabled`, `trustedHosts` (default `*.${suffix}`, `*.svc.cluster.local`), `allowedScopes` (default `groups`), `checkSenderHost` (default `false`), `consentRequired` (default `false`), `fullScopeAllowed` (default `true`), see below. Off, the trusted-hosts policy trusts no host. |
| `users` | `[]` | `{username, email, firstName, lastName, password, serviceAccountClientId, roles, clientRoles, groups}`; `roles` are realm roles, `clientRoles` maps a client id to its roles. |
| `groups`, `roles`, `clients`, `clientScopes` | `[]` | Realm content, same shape as the KuboCD package. |
| `clients[].attributes` | none | Keycloak client attributes (string values), e.g. `oauth2.device.authorization.grant.enabled: "true"` lets a public client use the device flow of a command-line tool. |

In `clients[].redirectUris`, `clients[].webOrigins` and `anonymousDCR.trustedHosts`,
`${suffix}` is replaced by `global.okdp.ingress.suffix` (the KuboCD form
`{{ .Context.ingress.suffix }}` is still accepted: values are no longer templates).

Platform values read: `global.okdp.ingress.suffix`, `ingress.className`,
`certificateIssuers.selfSigned.name` (all required).

The Keycloak pods repel only Keycloak pods (required anti-affinity on the release's
pods without a component label): the upstream default also matched the
keycloak-config-cli Job pod, which then never scheduled on a single node.

## Anonymous client registration

With `anonymousDCR.enabled`, a client registers itself without credentials (the
`oidc-dcr` Jobs of `clientProvisioning: dcr`), under two realm policies: Allowed Client
Scopes (`allowedScopes`) and Trusted Hosts, whose `client-uris-must-match` keeps the
client's redirect URIs on `trustedHosts`. The Trusted Hosts check of the sender
(`host-sending-registration-request-must-match`) is off by default
(`checkSenderHost: false`): Keycloak runs behind the ingress (`proxy.mode: xforwarded`),
so the sender is the `X-Forwarded-For` client, a pod IP with no reverse DNS, which never
matches `*.svc.cluster.local`, and every registration from a pod would fail with
"Host not trusted".

The scopes a client may ask for are the realm's default and optional client scopes
(`profile`, `email`, `roles`, `offline_access`...) plus `allowedScopes`, each a client
scope the realm declares (`groups` must be in `clientScopes`). A registered client gets
them as optional scopes: the application requests them at login (`openid` is not a
Keycloak client scope, the oidc-dcr Jobs leave it out of the registration).

Keycloak also applies two anonymous policies of its own, which keycloak-config-cli
never removes (it only removes what it created): Consent Required (users approve each
registered client at their first login) and Full Scope Disabled (the client's tokens
carry none of the user's realm roles, so no `groups` claim and no role mapping in the
services). With `enabled`, the keycloak-config-cli Job removes them first (an init
container on the Keycloak image, `kcadm.sh` against the Admin API), so a registered
client behaves like one declared in `clients`: `consentRequired: true` or
`fullScopeAllowed: false` keep the corresponding policy (declared in the realm file).

Security trade-off: without the sender check, anyone who reaches Keycloak can register
a client (limited to the allowed scopes and to redirect URIs on trusted hosts, so it
cannot capture another client's logins; a client with no redirect URI only gets the
default roles of its own service account).
With `enabled: false` the sender check stays on and no host is trusted: every anonymous
registration is refused. Fine for the sandbox, where DCR must work out
of the box; on a shared network set `checkSenderHost: true` with `trustedHosts` that
the senders' addresses resolve to, or use `clientProvisioning: existing`.

## The realm is declarative

keycloak-config-cli runs as a `post-install,post-upgrade` hook (Argo CD PostSync) with
the realm file of the Secret `<release>-realm`. It skips the import when the file did not
change, and otherwise makes the realm match it: role mappings and user profile settings
made by hand (Admin console or API) are removed. Declare them here instead, e.g. the
console's user management (`30-okdp-control-plane-server`, Keycloak Admin API):

```yaml
realm:
  name: master
  userProfile:
    attributes: [{name: comment}, {name: uid}]    # the console's user fields
users:
  - username: service-account-okdp-control-plane
    serviceAccountClientId: okdp-control-plane
    clientRoles:
      master-realm: [view-users, query-users, manage-users, query-groups]
clients:
  - {clientId: okdp-control-plane, secret: <secret>, serviceAccountsEnabled: true,
     standardFlowEnabled: false, directAccessGrantsEnabled: false}
```

In the master realm the realm-management roles are those of the client `master-realm`; in
another realm, of `realm-management`. The user profile is always part of the realm file
(Keycloak's default profile when nothing is declared).

## The database connection

`database-server` is an external-only contract: `db` names a connection declared in a
values layer (a connection file), e.g. for the sandbox's cnpg-postgresql:

```yaml
connections:
  keycloak-db:
    contract: database-server
    engine: postgresql
    host: cnpg-system-cnpg-postgresql-rw.cnpg-system.svc.cluster.local
    port: 5432
    dbName: keycloak
    secretRef: {name: creds-keycloak-db}   # in the keycloak namespace (replicated)
db: keycloak-db
```

Keycloak reads it as `KC_DB_URL` (`jdbc:postgresql://<host>:<port>/<dbName>`) and
`KC_DB_USERNAME` / `KC_DB_PASSWORD` from the Secret. It starts in the same layer as its
database and restarts until the database answers.

## Changes from the KuboCD package

- The codecentric `keycloakx` chart and the official Keycloak and keycloak-config-cli
  images replace the bitnami chart and its images (frozen, no longer patched).
- `db` names a connection (`keycloak-db`) instead of the KuboCD Connection
  `kcd-cnpg-postgresql-keycloak`; its `secretRef` is `{name}`.
- The admin password Secret is `<release>-admin`, rendered by this chart.
- keycloak-config-cli runs as a `post-install,post-upgrade` hook (Argo CD PostSync) from
  this chart; the bitnami `post-rollback` is gone. Its realm file is a Secret.
- `users[].clientRoles` and `realm.userProfile` are new.
- The realm file is built as data (`toPrettyJson`): values need no JSON escaping.
- Objects are named after the release: the StatefulSet `<release>`, the Services
  `<release>-http` and `<release>-headless`; the ingress TLS Secret stays
  `<host>-tls`. A release of an earlier bitnami-based build of this chart cannot be
  upgraded in place (the StatefulSet selector differs): delete its StatefulSet first, the
  data is in the database.

## Tests

```sh
helm dependency build packages/system/keycloak
for f in packages/system/keycloak/ci/*-values.yaml; do
  helm lint packages/system/keycloak -f "$f"
  helm template keycloak-keycloak packages/system/keycloak -n keycloak -f "$f" >/dev/null
done
scripts/vendor-charts.sh --check packages/system/keycloak
```
