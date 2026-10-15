# cnpg-postgresql

OKDP package of one PostgreSQL cluster managed by the
[CloudNativePG](https://cloudnative-pg.io/) operator (component `00-cloudnative-pg`),
hosting several logical databases, each with its owner role. It **provides** one
`database-server` connection per database.

A package in the okdp-compiler format, with no upstream chart (no dependency in
`Chart.yaml`): `okdp.yaml` computes the `Cluster` and the `Database` objects from the
parameters below (`config.schema.json`) as OKDP's own objects (its `objects` section,
rendered by the compiled umbrella chart, `okdp.objects.yaml`), and the connections the
instance publishes (`provides`, in `okdp.info.yaml`):

| Former module | Now | Compiled when |
|---|---|---|
| `main` | OKDP's objects: the `Cluster` and one `Database` per database | always |

The templates of the former module (`oci://quay.io/okdp/charts/cnpg-postgresql` 0.1.0)
are part of the mapping (`okdp.yaml`): that chart checked the owner Secrets with `lookup`, which renders
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

**Label the owner Secrets `cnpg.io/reload: "true"`.** CloudNativePG reconciles a managed
role when the `Cluster` changes, and when a Secret it uses changes only if that Secret
carries this label. A Secret that appears after the role was reconciled (a replicated
Secret in a new namespace arrives some time after the chart) otherwise leaves the role
without a password for good (`passwordStatus` of the role without `resourceVersion`), and
every client fails with `password authentication failed`. With the label, CloudNativePG
sets the password as soon as the Secret appears, and again when it changes. In the
sandbox, `local-secrets-provider` sets it per Secret (`labels`), and
kubernetes-replicator copies the labels to the replicas.

## Provided connections: `database-server`

For each database, an output named `<release>-<database>` (`_` becomes `-`), in
`okdp.info.yaml`:

```yaml
- name: cnpg-system-cnpg-postgresql-keycloak
  contract: database-server
  values: {engine: postgresql, driver: org.postgresql.Driver, sslMode: prefer, port: 5432,
           host: cnpg-system-cnpg-postgresql-rw.cnpg-system.svc.cluster.local, dbName: keycloak}
  secretRef: {name: creds-keycloak-db}
```

`database-server` has no internal naming convention (the contract's `x-okdp-internal`): a
cluster publishes several outputs, one per database. An instance of the same namespace
references one by its name (e.g. `db: demo-pg-hive`, the database `hive` of the release
`demo-pg`): it resolves to the output's values and `secretRef`, and the consumer's release
waits for the cluster's. A consumer of another namespace (the platform's cluster lives in
`cnpg-system`) references an **external connection**, a context file (`--context`, e.g.
`platform/connections/<name>.yaml`) carrying these values, whose `secretRef` names a Secret
of the consumer's namespace (here the replicated `creds-keycloak-db`):

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

The console's connection picker offers the outputs of the project's instances (their
`okdp.info.yaml`, no longer the descriptor ConfigMap `<release>-okdp`) and writes the
name of the selected one in the parameter.

## Changes from the KuboCD package

- The connections were `kcd-<release>-<database>` with `secretRef: <name>`; they are
  `<release>-<database>` with `secretRef: {name}`, plus `driver` and `sslMode` defaults.
- `instances`, `storageSize` and `databaseReclaimPolicy` are parameters (were fixed:
  1 instance, 2Gi on class `standard`); the class comes from `global.okdp.storageClass.data`.
- The `Database` objects are named `<release>-<database>` (were `<database>`).
- The owner Secret is always external (the old chart could create it from `owner.password`,
  which the package never used).

## Tests

`ci/platform.yaml` holds the platform values of every case, without a storage class;
`sandbox` adds the sandbox's (`ci/sandbox-platform.yaml`).

```sh
scripts/compile-charts.sh catalog/cnpg-postgresql/18.3.0-1.0.0   # compile, check and render ci/*-values.yaml
```
