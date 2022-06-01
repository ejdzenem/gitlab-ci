# CI Templates

Gitlab CI templates for common use-cases. Check [examples](https://gitlab.seznam.net/cns/examples) for the specific usage.

## Usage

You can include the templates from this repository to your project by adding following lines into your `.gitlab-ci.yml` file.

```yaml
include:
  - project: 'cns/ci-templates'
    ref: docker@1
    file: '/packages/docker/templates.yml'
  - project: 'cns/ci-templates'
    ref: kubernetes@1
    file: '/packages/kubernetes/templates.yml'
  - project: 'cns/ci-templates'
    ref: nodejs@1
    file: '/packages/nodejs/templates.yml'
  - project: 'cns/ci-templates'
    ref: python@1
    file: '/packages/python/templates.yml'
```

### Versioning

For each package we create a tag for patch, minor and major version. This way, you can reference to a minor, or a major package version and recieve patch, or even minor updates automatically. Each package has its own version.

You can define following values in `include.[].ref` field as displayed above.

```
<package>@<major> # docker@1
<package>@<major>.<minor> # docker@1.0
<package>@<major>.<minor>.<patch> # docker@1.0.0
```

## Examples

Check [example projects](https://gitlab.seznam.net/cns/examples) to see suggested project setup, when using CI templates from this repository.

## Docker

Project or parent group must contain following **Gitlab CI/CD variables** to be able to login to harbor docker registry.:
- `DOCKER_REGISTRY`
- `HARBOR_TOKEN_DEV`
- `HARBOR_USER_DEV`
- `HARBOR_NAMESPACE_DEV`
- `HARBOR_TOKEN_PROD`
- `HARBOR_USER_PROD`
- `HARBOR_NAMESPACE_PROD`

Required gitlab **stages** are:
- `build`
- `deploy`

Please set these stages in your .gitlab-ci.yml or override stage in job configurations.

There are following templates available.

- `.build-image`
  - Builds docker image
  - Runs in `build` stage
  - Variables:
    - `COMPONENT` - defines for which component you want run docker build
    - `COMPONENT_PATH` - component path. **Default** is `.`
    - `DOCKERFILE_PATH` - path of your Dockerfile. **Default** is `./Dockerfile`
    - `EXTRA_BUILD_ARGS` - adds more arguments for docker build command
- `.release-image`
  - Releases prod image
  - Runs in `deploy` stage for `tag` only
  - Variables:
    - `COMPONENT` - defines for which component you want release prod image

## Kubernetes

There are following templates available.

- `.deploy-envsubst`
  - Deployment job template, which uses [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html) to update kubernetes template files
  - Variables:
    - `YAML_PATHS: 'kubernetes/*.yml'` - template files that should be deployed with this job
    - `YAML_PATHS_ROLLOUT_CHECK: 'kubernetes/deployment.yml'` - template files, which should be awaited via `kubectl rollout status`
    - `ENV_FILE` (optional) - env file, which will be loaded before template files processing
- `.deploy-clear-envsubst`
  - Clear deployment job template to clear deployments deployed via `.deploy-envsubst` job
  - Variables (values should be same as in `.deploy-envsubst` job):
    - `YAML_PATHS`
    - `ENV_FILE`

The above job templates expect Gitlab integration with Kubernetes to be configured via certificate-based authentication method. Check for example [seoapi configuration](https://gitlab.seznam.net/cns/seoapi/-/clusters).

## Node.js

Required gitlab **stages** are:
- `test`

You need to define following global variables:

```yaml
variables:
  NODEJS_VERSION: 16 # Node version to be used in CI (note that appropriate node docker image has to exist in harbor registry)
  NODEJS_INSTALL_METHOD: "ci" # "install", or "ci" - installation method for npm
```

There are following templates available.

- `.npm-install`
  - Installs dependencies
- `.npm-run`
  - Runs `npm run <script>`
  - Variables:
    - `SCRIPT` - which script from package.json should be run

Don't forget add `needs: [{ job: "npm-install", optional: true }]` for all jobs which require installed nodejs dependencies.  
If you don't set `needs` as above then command `npm install` will run in the job and install npm dependencies again.

## Python

## Development

Check `.nvmrc` file for supported Node.js version to run commands in this repository.

**Commands**

- `npm run lint -- [--fix]` - keeps codestyle in yaml files
- `npm run changeset` - generates changelog entry, each MR should have a changelog file
- `npm run release` - releases a new version of changed packages

**Naming conventions**

It is always prefered to use dashes when naming templates, or jobs. For example `npm-run-lint`.

Configurable variables extending CI templates defined in this repository should always use capital letters and words should be seperated with `_` (underscore). If the variable is defined globally, because it is used in multiple jobs in the same package, then the first word should be also the name of the package (`NODEJS_*`, `PYTHON_*`, `DOCKER_*`, `KUBERNETES_*`).

**Examples**

All templates should be used in examples to showcase, how they should be used. This also serves as a test to see, if the template works as expected.

If child-pipeline fails for some of the examples, you might need to run the failing commands directly from the specific example directory.

**Docker Images**

We should use only images defined in [cns/doc](https://gitlab.seznam.net/cns/doc/-/merge_requests/75).

**Scripts**

Folder `scripts` contains scripts to manage this repository.
