# seaweedfs

OKDP chart of [SeaweedFS](https://github.com/seaweedfs/seaweedfs), a simple and highly
scalable distributed file system with an S3 API: the platform object store. It
**provides** one `s3` connection; each consumer brings its own identity (a grant).

It renders the chart `seaweedfs` 4.47.0 (https://seaweedfs.github.io/seaweedfs/helm, image
`chrislusf/seaweedfs:4.47`), vendored under `vendor/` (see `vendor.yaml`), with values
computed in `templates/_values.tpl`: master, volume, filer (UI behind basic auth) and the
standalone S3 gateway; its bucket hook creates `buckets`. Its pre-install Secret
`templates/shared/secret-seaweedfs-db.yaml` (a random password, unused with the default
filer store) is removed from the vendored copy.

`buckets[].paths` are seeded by `templates/provisioning.yaml`: a post-install/post-upgrade
hook Job, idempotent, running the store's own image. `weed shell` waits for each bucket and
`weed filer.copy` writes an empty `<path>/.keep` object through the filer, so no S3
identity is needed. It replaces the former `seaweedfs-provisioning` chart and its MinIO
client image (`quay.io/minio/mc`, archived).

The former `auth-config` module (`oci://quay.io/okdp/charts/seaweedfs-auth-config`) is
part of this chart (`templates/auth.yaml`): it read the grants' Secrets with `lookup` and
hashed the filer password with `htpasswd` (random salt), both of which differ between
Helm and Argo CD. Now:

- the S3 configuration Secret `<release>-s3-config` is written by **ESO**: a SecretStore of
  the kubernetes provider (same namespace, a ServiceAccount allowed to read the root and
  grant Secrets only) and an ExternalSecret templating the identities JSON. It refreshes
  every 5 minutes; Reloader restarts the S3 gateway when it changes;
- the filer basic auth Secret `<release>-filer-basic-auth` uses nginx's `{PLAIN}` scheme;
- the IAM/STS configuration is the Secret `<release>-auth-config` (`iam.json`), also
  written by ESO: SeaweedFS serves no STS without a signing key, so the key is generated
  once by an ESO Password generator (`okdp.generatedSecret`, the Secret
  `<release>-sts-signing-key`, frozen once written) and templated into `iam.json`. The S3
  gateway waits for that Secret at its first start; Reloader restarts it when ESO
  changes the file, and a checksum of the IAM template rolls it on a chart change.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `username` / `password` | `admin` / (required) | Basic auth of the filer UI. |
| `rootAccessKey` / `rootSecretKey` | `okdpadmin` / (required) | Root (Admin) identity of the S3 gateway, in the Secret `<release>-root-credentials`. |
| `stsRoleArn` | `arn:aws:iam::000000000000:role/S3WriteRole` | Role assumed through STS. |
| `consoleHost` / `apiHost` | `seaweedfs-<ns>` / `seaweedfs-<ns>-api` | Host names; the ingress suffix is appended. |
| `volumeReplicas` | `1` | Volume servers. |
| `masterStorage`, `masterLogStorage`, `volumeStorage`, `filerStorage`, `filerLogStorage` | `1`, `0.5`, `2`, `0.5`, `0.5` | Sizes in GiB, class `global.okdp.storageClass.workspace`. |
| `grants` | `[]` | `{principal, credentialsSecret: {name, accessKeyKey, secretKeyKey}, actions, buckets, sts}`: one S3 identity each, keys read by ESO from the Secret (in this namespace). |
| `buckets` | `[]` | `{name, anonymousRead, paths}`: created at startup; `paths` are seeded. |
| `outputSecretRef` | `""` | `secretRef` of the published connection; empty: none (consumers bring their own identity). |

Platform values read: `global.okdp.ingress.suffix`, `ingress.className`,
`certificateIssuers.selfSigned.name`, `storageClass.workspace` (all required). Needs ESO
(component `00-external-secrets`; the SecretStore and ExternalSecret are
`external-secrets.io/v1`, served by ESO 0.17 and later) and Reloader (`tools`).

## Upstream values

Any value of the vendored `seaweedfs` chart can be set per instance under
`upstream.seaweedfs`, merged over the values computed from the parameters
(okdp-lib-chart `okdp.vendor.render`, option `upstream`):

```yaml
upstream:
  seaweedfs:
    image: {registry: mirror.example.org}
    volume: {resources: {limits: {memory: 1Gi}}}
    s3:
      extraArgs: [-v=2]                            # appended to the chart's arguments
      createBuckets: [{name: scratch}]             # appended to the buckets parameter
    filer:
      ingresses:
        http:
          annotations: {nginx.ingress.kubernetes.io/proxy-read-timeout: "600"}
```

The paths the platform relies on are refused, and the lists the chart sets are
appended to rather than replaced: see `seaweedfs.okdp.upstream` in
`templates/_values.tpl` (also listed in the schema description). Annotation
keys carry dots, so the define itself refuses the filer ingress basic auth
annotations (`nginx.ingress.kubernetes.io/auth-*`) and the Reloader annotation
of the S3 gateway. `s3.extraVolumes` and `s3.extraVolumeMounts` are strings
(they mount the IAM/STS file), so they are refused rather than appended to. An
upstream value wins over the parameter it overlaps (`volume.replicas` over
`volumeReplicas`). No key or value may contain `{{` (the schema and
okdp-lib-chart both refuse it).

## Provided connection: `s3`, external only

One output named after the release:

```yaml
- name: default-storage
  contract: s3
  values: {apiUrl: https://<apiHost>, internalUrl: http://<release>-s3.<ns>.svc.cluster.local:8333,
           consoleUrl: https://<consoleHost>, region: us-east-1, pathStyle: true}
  secretRef: {name: <outputSecretRef>}      # only when outputSecretRef is set
```

`s3` has no internal naming convention: the store is a platform component in its own
namespace, so consumers declare it in a connection file with these values and, as
`secretRef`, a Secret of their namespace holding their own identity's keys (a grant here).

## Changes from the KuboCD package

- The output was named `s3` (connection `kcd-<release>-s3`); it is the release name.
- Secrets and ConfigMaps are named after the release (`creds-seaweedfs-filer-basic` is
  `<release>-filer-basic-auth`, the TLS Secrets `<release>-filer-tls` / `<release>-s3-tls`,
  the ServiceAccount `<release>`).
- The S3 configuration follows grant Secret changes (ESO refresh + Reloader); it was
  rewritten only on a Helm upgrade.
- Hosts are parameters (default `seaweedfs-<ns>[-api]`, were `<release>-<ns>[-api]`).
- The volume PVC resize hook is off (it compared live PVCs with `lookup`).
- `outputSecretRef` is new.
- Seeded paths are written with the SeaweedFS image (`weed`) instead of the MinIO client.

## Tests

```sh
scripts/vendor-charts.sh packages/services/seaweedfs   # download vendor/ (not committed)
helm dependency build packages/services/seaweedfs
for f in packages/services/seaweedfs/ci/*-values.yaml; do
  helm lint packages/services/seaweedfs -f "$f"
  helm template default-storage packages/services/seaweedfs -n default -f "$f" >/dev/null
done
```
