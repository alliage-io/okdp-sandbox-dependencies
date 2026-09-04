# cnpg-postgresql

OKDP chart of one PostgreSQL cluster managed by the
[CloudNativePG](https://cloudnative-pg.io/) operator (component `00-cloudnative-pg`),
hosting several logical databases, each with its owner role. It **provides** one
`database-server` connection per database.

The templates of the former module (`oci://quay.io/okdp/charts/cnpg-postgresql` 0.1.0)
are part of this chart: that chart checked the owner Secrets with `lookup`, which renders
nothing under Argo CD, and no value disables it. A missing Secret now shows in the
`Cluster` status.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `databases` | (required) | `[{name, owner: {username, passwordSecret}, schemas: []}]`. |
| `instances` | `1` | PostgreSQL instances (1 primary + standbys). |
| `storageSize` | `2Gi` | Volume of each instance; class `global.okdp.storageClass.data` (cluster default when unset). |
| `databaseReclaimPolicy` | `delete` | `delete` or `retain` a database removed from the list. |

`owner.passwordSecret` is a Secret of the release namespace with the keys `username` and
`password`, created by someone else (`local-secrets-provider` in the sandbox, replicated to
every namespace).

## Provided connections: `database-server`, external only

For each database, an output named `<release>-<database>` (`_` becomes `-`):

```yaml
- name: cnpg-system-cnpg-postgresql-keycloak
  contract: database-server
  values: {engine: postgresql, driver: org.postgresql.Driver, sslMode: prefer, port: 5432,
           host: cnpg-system-cnpg-postgresql-rw.cnpg-system.svc.cluster.local, dbName: keycloak}
  secretRef: {name: creds-keycloak-db}
```

`database-server` has no internal naming convention (okdp-lib `okdp.connection`): the
cluster lives in another namespace than its consumers and publishes several outputs. A
consumer therefore references it through an **external connection**, a values layer
carrying these values, whose `secretRef` names a Secret of the consumer's namespace (here
the replicated `creds-keycloak-db`):

```yaml
connections:
  keycloak-db:
    contract: database-server
    engine: postgresql
    host: cnpg-system-cnpg-postgresql-rw.cnpg-system.svc.cluster.local
    port: 5432
    dbName: keycloak
    secretRef: {name: creds-keycloak-db}
```

The console offers these outputs from the descriptor ConfigMap `<release>-okdp` and turns
the selected one into such a connection file.

## Changes from the KuboCD package

- The connections were `kcd-<release>-<database>` with `secretRef: <name>`; they are
  `<release>-<database>` with `secretRef: {name}`, plus `driver` and `sslMode` defaults.
- `instances`, `storageSize` and `databaseReclaimPolicy` are parameters (were fixed:
  1 instance, 2Gi on class `standard`); the class comes from `global.okdp.storageClass.data`.
- The `Database` objects are named `<release>-<database>` (were `<database>`).
- The owner Secret is always external (the old chart could create it from `owner.password`,
  which the package never used).

## Tests

```sh
helm dependency build packages/system/cnpg-postgresql
for f in packages/system/cnpg-postgresql/ci/*-values.yaml; do
  helm lint packages/system/cnpg-postgresql -f "$f"
  helm template cnpg-system-cnpg-postgresql packages/system/cnpg-postgresql -n cnpg-system -f "$f" >/dev/null
done
```
