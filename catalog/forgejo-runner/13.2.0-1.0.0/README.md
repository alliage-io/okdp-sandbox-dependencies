# forgejo-runner

OKDP package of a [Forgejo Actions](https://forgejo.org/docs/latest/admin/actions/)
runner dedicated to OKDP's CI: on every push to an input repository of the deployments
layout, the workflow [okdp-gitops](https://github.com/OKDP/okdp-gitops) generates runs
`okdp-gitops compile` on this runner, which compiles the whole layout and pushes the
compiled tree to the output repository. The package implements the **runner contract**
of okdp-gitops (below): the label `okdp-gitops` on the host executor, the `okdp-gitops`
binary on the jobs' `PATH`, the topology, the git credentials and a chart cache.

A package in the okdp-compiler format, with no upstream chart (no dependency in
`Chart.yaml`): `okdp.yaml` computes the runner as OKDP's own objects (its `objects`
section, rendered by the compiled umbrella chart, `okdp.objects.yaml`), from the
parameters below (`config.schema.json`). New in this catalog: there is no KuboCD
package before it.

| Object | Name | Content |
|---|---|---|
| ConfigMap | `<release>` | `config.yml`, the runner configuration; `topology.yaml`, the topology of okdp-gitops |
| Deployment | `<release>` | one replica, `Recreate`; init container `okdp-gitops` (copies the binary), container `runner` (forgejo-runner 13.2.0) |
| ServiceAccount | `<release>` | no RBAC, no API token mounted: okdp-gitops talks to git only |

## The runner contract

The workflow okdp-gitops generates has one job, `runs-on: okdp-gitops`, whose step runs
`okdp-gitops compile --config /etc/okdp/gitops/topology.yaml --charts
/var/cache/okdp/charts` with `shell: sh`.

| Contract | In the pod |
|---|---|
| label `okdp-gitops`, host executor | `runner.labels: [okdp-gitops:host]`: the jobs run in the runner container itself (a shell forked from the runner, no isolation); the sandbox (kind) has no Docker daemon |
| `sh` | the runner image is Alpine: `/bin/sh` (busybox), also `bash` and `git` |
| `okdp-gitops` on the `PATH` | the init container copies `/usr/local/bin/okdp-gitops` of the okdp-gitops image (a static binary, go-git: no git binary needed) into the emptyDir `/okdp/bin`; `runner.envs.PATH` puts it first (the environment of host jobs is `runner.envs` over the runner's own) |
| topology `/etc/okdp/gitops/topology.yaml` | the parameter `topology`, key `topology.yaml` of the ConfigMap, mounted with `subPath` |
| git credentials `/etc/okdp/gitops/credentials` | the Secret `credentialsSecret`, every key a file (`username`, `password`, or `bearerToken`); `runner.envs.GITOPS_CREDENTIALS_DIR` |
| chart cache `/var/cache/okdp/charts` | an emptyDir, writable (a cache: lost with the pod) |

The jobs also get the platform proxy (`global.okdp.proxy`, as `HTTP_PROXY`,
`HTTPS_PROXY`, `NO_PROXY` in `runner.envs`), and inherit the runner's own environment
(`HOME=/data`): the pod sets `enableServiceLinks: false` and mounts no ServiceAccount
token.

## Registration

The runner uses Forgejo's
[offline registration](https://forgejo.org/docs/latest/admin/actions/registration/#offline-registration):
one shared secret of 40 hexadecimal characters. On the Forgejo side (the sandbox
scripts):

```sh
forgejo forgejo-cli actions register --name okdp-gitops --scope okdp --labels okdp-gitops --secret <hex>
```

On the runner side, the secret is a key of an existing Secret of the release namespace
(`registrationSecret`, sandbox: `okdp-forgejo-runner`, key `secret`), mounted as a file.
The container's script derives the runner's UUID from it as Forgejo does (its first 16
characters, as the 16 bytes of the UUID: `7c31591e8b67225a...` is
`37633331-3539-3165-3862-363732323561`), then runs:

```sh
forgejo-runner daemon --config /etc/forgejo-runner/config.yml \
  --url <forgejoUrl> --uuid <uuid> --token-url file:/etc/forgejo-runner/registration/token
```

The connection options of `daemon` (forgejo-runner 12.8.0 and later) replace
`forgejo-runner create-runner-file`, deprecated since 12.8.0 ("declare connections in
the runner configuration instead"); they are what a `server.connections` entry of the
configuration holds (`url`, `uuid`, `token_url`), without writing the UUID into the
ConfigMap: it depends on the Secret. The runner reads the token from the file itself,
and declares its labels (`okdp-gitops`) at every start. Its name is Forgejo's, given at
registration (`--name`): the runner side has none to set.

The runner configuration (`config.yml`, keys of `forgejo-runner generate-config` 13.2.0):
`runner.capacity` (the parameter), `runner.envs`, `runner.labels`, `runner.timeout: 1h`,
`runner.shutdown_timeout: 2m` (a job running when the pod stops gets two minutes to
finish; `terminationGracePeriodSeconds: 150`), `cache.enabled: false` (no action, no
cache server), `host.workdir_parent: /data/.cache/act` (the jobs' directories, in the
emptyDir `/data`).

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `forgejoUrl` | `http://forgejo-http.forgejo.svc.cluster.local:3000` | URL the runner reaches Forgejo at (its Actions API), also the jobs' `GITHUB_SERVER_URL`. |
| `registrationSecret.name` / `.key` | `okdp-forgejo-runner` / `secret` | Secret of the release namespace holding the offline registration secret (40 hexadecimal characters). |
| `topology` | (required) | The topology file of okdp-gitops, as YAML text: the repositories of the platform, of the projects and of the output. |
| `credentialsSecret` | `okdp-gitops-credentials` | Secret of the release namespace with the git credentials of okdp-gitops (`username` and `password`, or `bearerToken`), allowed to push to the output repository. |
| `capacity` | `1` | Jobs run at once. Every compile pushes to the output repository: above 1, two compiles can race and one push be refused. |
| `resources` | `{}` | Resources of the runner container, where the compiles run. |
| `image.repository` / `image.tag` | `code.forgejo.org/forgejo/runner` / `13.2.0` | The runner image. |
| `okdpGitopsImage.repository` / `okdpGitopsImage.tag` | `repo.alliage.io:8082/okdp/images/okdp-gitops` / `0.1.0` | The image the `okdp-gitops` binary is copied from (`/usr/local/bin/okdp-gitops`). |

Platform values read: `global.okdp.proxy` (optional), none required.

The pod runs as `1000:1000` (the runner image's user), with a read-only root file
system (Pod Security `restricted`): the runner and its jobs write to `/data`, `/tmp` and
the chart cache only, all emptyDirs. The configuration and the topology are read at
start: a change restarts the pod (`checksum/config`).

## Version

forgejo-runner 13.2.0 (2026-09-18), the latest release at least two weeks old. Forgejo
from the forgejo-helm chart 17.1.7 (component `20-forgejo`) is 15.0.9; the runner's
integration tests run against Forgejo 11.0 (LTS) and its development branch, and the
runner protocol (`Declare`, then fetching tasks) is the one of every Forgejo since 1.21.
The 13.0 breaking changes (workflow syntax errors fail, `set-output`, `set-env` and
`add-path` removed, `GITEA_*` variables ignored) do not concern a workflow of one `run`
step.

## Known gaps

- Host executor: no isolation. Every workflow of the registration scope with
  `runs-on: okdp-gitops` runs in the pod and can read the git credentials: register the
  runner on the organization of the deployments repositories (`--scope okdp`), whose
  workflows are trusted, never instance-wide.
- No probe: the runner serves no health endpoint. It exits when Forgejo refuses its
  declaration (a wrong secret, Forgejo down at start) and Kubernetes restarts it.
- `registrationSecret` and `credentialsSecret` are not created by the package: they must
  exist in the release namespace (the pod waits for them).

## Tests

No platform value is required: the cases have no `ci/platform.yaml`. `sandbox` is the
sandbox's io topology over the defaults; `custom` sets every parameter, with a
platform proxy (`ci/custom-platform.yaml`) and a topology without a final line break;
`no-topology` must fail.

```sh
scripts/compile-charts.sh catalog/forgejo-runner/13.2.0-1.0.0   # compile, check and render ci/*-values.yaml
```
