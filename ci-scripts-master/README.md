# CI Scripts

Prepare CI pipeline in a minute!

This scripts helps you with it. CI-scripts are shipped in two ways:

1. As a **Docker image** [`docker.ops.crd.cz/crd-devops/ci-scripts:1`](https://docker.ops.crd.cz/harbor/projects/21/repositories/crd-devops%2Fci-scripts/tags/1)
  where scripts are located in `/ci/` directory.
*This image could be used directly in your CI pipelines, but please note that **Debian version (which is the base of ci-scripts Docker image) may change without previous notice**, and within any ci-scripts release - [major or minor, (not patch)](https://semver.org/). Because of that, make sure that you **do not depend** on any package versions which may be available (or installable) in ci-scripts Docker image.*

2. [Published on web](https://generic.glpages.creditas.cz/ci-scripts/)
  Available on gitlab pages. This could be used locally by
  `curl https://generic.glpages.creditas.cz/ci-scripts/v1/all.tar.gz | tar xzf -`
  Note you need to install ci-scripts dependencies by executing `lib/install-dependencies.sh`

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## What ci-scripts provides

It helps you with:
* [Build docker image](lib/docker-build.sh) by `/ci/docker-build.sh --component $COMPONENT --namespace $NAMESPACE`.
  * internally `docker build` command is called, if you need to pass additional argument you can do it this way: `/ci/docker-build.sh --namespace $NAMESPACE -- --build-arg MYBUILDARG=MYVAL --file=/my/path/Dockerfile.custom`
* Release docker image [to repository](lib/docker-release.sh) or
  [to testing repository](lib/docker-release-ci.sh) by `/ci/docker-release[-ci].sh --component $COMPONENT --namespace $NAMESPACE`.
* [Configure `kubectl`](lib/kubernetes-ci-init.sh) to right access to Kubernetes.
* [Prepare Kubernetes yaml files](lib/kubernetes-config.sh) to deploy app to kubernetes.
* [Prepare Kubernetes yaml files with more custom options](lib/kubernetes-config-custom.sh) to deploy app to kubernetes.
* [Deploy project](lib/kubernetes-deploy.sh) directly to Kubernetes.
* [Deploy project](lib/argocd.sh) to Kubernetes using Argo CD.
* [Release debian package](lib/deb-release.sh) to repo.dev.crd.cz (configurable via both environment variable and switch).
* Release docker image to production registry
  * [using standard docker pull+tag+push mechanism](lib/docker-release-to-production-registry.sh)

and there are some utils scripts to help and check:
* Test installability and uninstallability of deb package
  (see [test-deb-install-uninstall.sh](lib/test-deb-install-uninstall.sh)).
* Test that your git release tag is matching your version in repository
  (see [test-version-match.sh](lib/test-version-match.sh)).
* Obtain all major tags for your version (e.g. `v1.3` -> `v1` and `latest`)
  (see [latest-tags.sh](lib/latest-tags.sh)).
* Sort given [semantic versions](lib/semver-cut.sh)
* Check changes in GIT repository given directories
  (see [git-check-changes.sh](lib/git-check-changes.sh))


## Frequently asked questions

### General recomendations

* Do not create `deb` package if you are deploying only to  Kubernetes/Marathon.
* Do a versioning and changelog if your are providing only Docker image.
* Release on tag! (e.g. `v1.2`)
* There are multiple development deployments (`<product_name>-master` and  `<product-name>-staging`). CI Pipelines automatically deploy to both on:
   * `<product_name>-master`: project is deployed on any commit to master
   * `<product_name>-staging`: project is deployed on release (e.g. on tag)
   * there may be situations when you want to release from branch, in such case use manual deployment to `<product-name>-staging`
* There is initiative to standardize projects directory structure, ci-scripts rely on (more details in [docs/k8s_config_best_practices_v8.pdf](docs/k8s_config_best_practices_v8.pdf)):
   * `<project-dir>`
     * `kubernetes/`
       * `*.yaml`
       * `*.yaml.tmpl`
     * `conf/`
       * app's configuration template file containing production configuration (except secrets)
       * development.env

### How ci-scripts detect[s] component name and/or version?

[ci-scripts common shell library](lib/common.sh) defines unified way how to detect:
 * **component name** is obtained via [common.sh's get_component()](lib/common.sh) from below sources:
   * env. variable `COMPONENT`
   * custom script `ci/component.sh`
   * special target of local makefile (`_print-(COMPONENT|component)`)
   * dockerfile's label `org.label-schema.name`

 * **component's current version** is gathered via [common.sh's get_version()](lib/common.sh) from:
   * env. variable `VERSION`
   * custom script `ci/version.sh`
   * `debian/changelog` version
   * special target of local makefile (`_print-(VERSION|version)`)
   * NPM version from `package.json`
   * `VERSION` file
   * `changelog.md` changelog version
   * dockerfile's label `org.label-schema.version`
   * current git revision hash

Look into [source code for current details and priorities](lib/common.sh), search for functions `get_component()` and `get_version()`.

### Is there a way how to override most common infrastructure hosts?

Yes, it is possible via following environment variables:
 * docker infrastructure
   * development docker registry
     * `CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY` (docker registry host), `CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER` (registry CI user when login needed), `CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE` (registry CI password in a file when login needed)
     * older development docker environment variables are deprecated (as of `v1.46.0`):
       * CI docker registry host: [`CI_SCRIPTS_DOCKER_CI_REGISTRY`](https://repo.creditas.cz/generic/ci-scripts/blob/master/lib/common.sh#L3)
       * development docker registry host: [`CI_SCRIPTS_DOCKER_REGISTRY`](https://repo.creditas.cz/generic/ci-scripts/blob/master/lib/common.sh#L4)
   * production docker registry
     * `CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY` (docker registry host), `CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_USER` (registry CI user when login needed), `CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_PASSWORD_FILE` (registry CI password in a file when login needed)
   * since ci-scripts `v1.48.0` container image copy operation can be done via Harbor docker registry API retag if available, you may use `CI_SCRIPTS_DOCKER_REGISTRY_USE_HARBOR_API_ENABLED=false` to disable Harbor docker registry API operations
 * debian package registry host: [`CI_SCRIPTS_REPO_HOST`](https://repo.creditas.cz/generic/ci-scripts/blob/master/lib/deb-release.sh#L38)

 ### How to set different application kubernetes nodePort for deployment in `<product_name>-master` and `<product_name>-staging`

 Kubernetes does not allow you to bind same node port for two different deployments.
 There is following consensus on node-port assignment (kubernetes skube.dev.dszn.cz):
  * there is allowed node-port range between 10000-12999
  * if the application does not need external access, please use service with ClusterIP type (avoid nodePort type)
  * if the application requires external access you have to specify nodePort service type
    * `<product_name>-staging` application deployment should use the same port as in the production
    * `<product_name>-master` application deployment should use the port as in the production decreased by 1000
  * definition of the nodePort should be done by using environment variable in .gitlab-ci.yaml
    * example: https://repo.creditas.cz/impexp/exporter/blob/42f784e504006cc0afa87561bf45918c55307d31/manager/kubernetes/export-manager-service.yaml.tmpl#L13 https://repo.creditas.cz/impexp/exporter/blob/42f784e504006cc0afa87561bf45918c55307d31/.gitlab-ci.yml#L306

 Both kubernetes application deployments to `<product_name>-staging` and `<product_name>-master` are by default using development application configuration i.e. production defaults defined in application default configuration is tuned by `conf/development.env` file and applied to kubernetes workload using automatically created kubernetes configmap object.

 ### How to deal with multiple subprojects in one git repository?

 Supported, move configs and kubernetes files to separated directories:
  * mujprojekt.git
    * subprojekt-a
      * conf/
      * kubernetes/
    * subprojekt-b
      * conf/
      * kubernetes/

 ### Why do you template configurations?

 There are several places where we suggest to template configuration using `goenvtemplator2` (golang sprig template syntax compatible with kubernetes-helm and others):
  * application configuration conf/*.tmpl
    * should be templated to allow different configuration in development environment
    * please make production vs. development configuration difference as small as possible
    * differences between production vs. development configuration should be stored in `conf/development.env`
  * kubernetes yaml manifests in kubernetes/*.yaml.tmpl
    * should be templated to allow custom configuration of:
      * docker image name
      * kubernetes pod replicas
      * service node-port existence and port value


 ### What are ci-scripts requirements?

 When getting ci-scripts from gitlab pages https://generic.glpages.creditas.cz/ci-scripts/ you need to install ci-scripts dependencies yourself by executing `lib/install-ci-scripts.sh`.
 The installation script assumes you are on Debian/*buntu distros, if that is not your case you need to install dependencies manually.

 ### Deploy does not work, how I set my own kubernetes cluster details?

 You need to set Gitlab CI environments and Gitlab CI kubernetes integratiuon.
 Please see the section [Gitlab CI Example](#gitlab-ci-example) for details.

 ### How to differentiate between production and development configuration?

 There is `conf/development.env` file for that.
 Application configuration file should be templated by env. variables, example
 Development configuration is defined as minimal modification of the production (default) application configuration throug env. variables.

 Example:
  * application configuration is templated
    * https://repo.creditas.cz/impexp/exporter/blob/42f784e504006cc0afa87561bf45918c55307d31/manager/conf/manager.cfg.tmpl
  * there is `conf/development.env` to adjust development configuration
    * https://repo.creditas.cz/impexp/exporter/blob/42f784e504006cc0afa87561bf45918c55307d31/manager/conf/development.env
  * the resulting k8s development configuration is inserted into application deployment using envFrov syntax via configmap:
    * https://repo.creditas.cz/impexp/exporter/blob/42f784e504006cc0afa87561bf45918c55307d31/manager/kubernetes/export-manager-deployment.yaml.tmpl#L55-57
    * configmap is generated by ci-scripts' kubernetes-config*.sh and looks like:

 ```yaml
 apiVersion: v1
 data:
   EXPORTDB_DATABASE: export
   EXPORTDB_TTL: "181"
   SERVER_LOG_LEVEL: DEBUG
   SERVER_MAX_WORKERS_PER_EXPORT: "3"
 kind: ConfigMap
 metadata:
   creationTimestamp: null
   name: export-manager
 ```


## Gitlab CI Example

**NOTE**: You have to enable and set Kubernetes Integration in Gitlab.
See [crd-backend/documentation](https://repo.creditas.cz/crd-backend/documentation/blob/master/kubernetes.md) or/and Gitlab upstream documentation for details.
The specified values are then exposed as
[deployment variables `KUBE_*`](https://docs.gitlab.com/ee/user/project/clusters/deploy_to_cluster.html#deployment-variables)
(used by kubernetes-ci-init.sh).

```diff
--- a/.gitlab-ci.yml
+++ b/.gitlab-ci.yml
@@ -41,6 +41,8 @@
   when: manual
   # ci-scripts are provided in Jessie image only (Stretch image for statserver is in the Docker file)
   image: docker.ops.crd.cz/crd-devops/ci-scripts:1
+  environment:
+    name: master
   script: |
     cd statserver
     /ci/kubernetes-ci-init.sh
```

TODO following snippet is not full and not regulary tested yet:

```yaml
stages:
- build
- release
- config
- deploy
- release-docker-production

image: docker.ops.crd.cz/crd-devops/ci-scripts:1

build:
  stage: build
  before_script:
    - apt-get update
  script: |
    /ci/docker-build.sh --component $COMPONENT --namespace $NAMESPACE
    /ci/docker-release-ci.sh --component $COMPONENT --namespace $NAMESPACE
  artifacts:
    expire_in: 7 days
    name: docker-release-ci.txt
    paths:
    - docker-release-ci.txt

release:
  stage: release
  only:
  - /^v[0-9]+\.[0-9]+\.[0-9]+/
  script: |
    # Keep the assignment on its own line (not to hide failures of latest-tags.sh):
    extra_tags="$(/ci/latest-tags.sh)"
    /ci/docker-release.sh \
        --component $COMPONENT \
        --namespace $NAMESPACE \
        --extra-tags "$extra_tags"
  artifacts:
    expire_in: 7 days
    name: docker-release.uri
    paths:
    - docker-release.uri
    - docker-release.digest

config:
  stage: config
  environment:
    name: config
  script: |
    /ci/kubernetes-ci-init.sh
    export DOCKER_IMAGE=$(cat docker-release.uri docker-release-ci.uri 2>/dev/null | head -1)
    /ci/kubernetes-config.sh --env "development"
    export DOCKER_IMAGE=$(/ci/production-docker-image-name.sh "${DOCKER_IMAGE}")
    /ci/kubernetes-config.sh --env "production"
  artifacts:
    expire_in: 7 days
    name: kubernetes-config
    paths:
    - ./kubernetes/*/*.yaml

.deploy: &deploy
  stage: deploy
  script: |
    /ci/kubernetes-ci-init.sh
    /ci/kubernetes-deploy.sh --env $ENVIRONMENT --namespace $KUBERNETES_NAMESPACE

deploy master:
  <<: *deploy
  variables:
    ENVIRONMENT: development
    KUBERNETES_NAMESPACE: crd-master
  environment:
    name: master
  only:
  - master

deploy staging:
  <<: *deploy
  variables:
    ENVIRONMENT: staging
    KUBERNETES_NAMESPACE: crd-staging
  environment:
    name: staging
  only:
  - tag
  when: manual

# Release docker image to production registry
# Note: action of pushing development docker image to production registry **SHOULD HAVE** dedicated and **LAST** CI stage
release-docker-production:
  stage: release-docker-production
  except:
    - branches
  only:
    - /^v[0-9]+\.[0-9]+\.[0-9]+/
  script: |
    /ci/docker-release-to-production-registry.sh --docker-image-name-file docker-release.uri --docker-image-digest-file docker-release.digest

```

### Docker image publishing, notes on Harbor

As of ci-scripts `v1.56.0`, scripts `docker-release.sh, docker-release-ci.sh, docker-build.sh, production-docker-image-name.sh, docker-release-to-production-registry.sh` use the SCIF docker registry ([docker.ops.crd.cz](https://docker.ops.crd.cz)) by default. It can still be overridden using the following environment variables:
- `CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY`
- `CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY`

In order to authenticate to the registries, use the following variables:
- `CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER`
- `CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_PASSWORD_FILE` (Gitlab CI file variable to avoid leaking the secret)
- `CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_USER`
- `CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_PASSWORD_FILE` (Gitlab CI file variable to avoid leaking the secret)

* Note: Until Gitlab will support so-called raw variables, an escaping needs to be used in order to avoid expansion of dollar sign in Harbor robot account username. value of `CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_USER` would then be for example: `robot$$crd-devops-dev`

Registry path within Docker registry can be then configured explicitly via `--namespace` option for `docker-release.sh, docker-release-ci.sh, docker-build.sh` scripts or via environment variables:

- `CI_SCRIPTS_DEVELOPMENT_DOCKER_REGISTRY_NAMESPACE` (e.g. `crd-devops-dev` references development SCIF registry Harbor project)
- `CI_SCRIPTS_PRODUCTION_DOCKER_REGISTRY_NAMESPACE` (e.g. `crd-devops` references production SCIF registry Harbor project)

*Please note that `namespace` as understood in context of ci-scripts does not translate to any of the Harbor defined terms - project and repository. See the example below to understand the mapping:*

*Given image `docker.ops.crd.cz/crd-devops/monitoring/prometheus:1`, we have:*

* *from Harbor perspective*
  - *project `crd-devops`*
  - *repository `monitoring/prometheus`*
* *from ci-scripts perspective*
  - *namespace `crd-devops/monitoring`*
  - *component `prometheus`*


**We recommend to keep images in two separated projects and benefit from different SCIF registry [Harbor tag retention policies](https://goharbor.io/docs/1.10/working-with-projects/working-with-images/create-tag-retention-rules/) and [tag immutability rules](https://goharbor.io/docs/1.10/working-with-projects/working-with-images/create-tag-immutability-rules/). [Migration example.](https://repo.creditas.cz/crd-DevOps/fake-app/-/compare/d8f29d59...5e019e52) (May differ based on how exactly you have used ci-scripts in your CI pipeline.)**

We suggest to place `CI_SCRIPTS_{DEVELOPMENT,PRODUCTION}_DOCKER_REGISTRY_{USER,PASSWORD_FILE}` in your Gitlab group CI env. variables and remaining `CI_SCRIPTS_{DEVELOPMENT,PRODUCTION}_DOCKER_REGISTRY{,NAMESPACE}` place in the projest which is migrated.

### Multi-version kubectl support

As of ci-scripts `v1.51.0`, there are multiple versions of kubectl binary (1.16.6, 1.18.8). Default version is still 1.16.6, to use 1.18.8 set env. variable `KUBECTL_BIN=/usr/local/bin/kubectl1.18.8`.

## ci-scripts limitations & known issues

There are known following limitations:
 * `conf/*.env` files are goenvtemplator2 configuration files
   * `"` are not allowed
   * shell expansion `env_name=v${xyz}` is not allowed (work for bash but not for goenvtemplator2
 * logs from readiness and liveness probes are not available
 * tag + push to project with same image name may result in situation that kubernetes deployment is not refreshed
 * project Dockerfile requires `ARG BUILD_JOB_NAME`
 * `/ci/docker-release.sh` requires previous execution of `/ci/docker-release-ci.sh`
 * Changelog.md parser requires that `[Unreleased]` section is visually delimited from released versions by single empty line, this is recommended decoration avoiding confusion whether below version is treated as unreleased or not
   * If you face `Error: [Unreleased] tag has to be defined before the first version tag.` issue you typically need this: https://repo.creditas.cz/crd-backend/hbase-schema/commit/ccd82c6687236e97e2ee3426c6c62524b7bd404c
We'are working on the list above, if you feel something is blocking you, feel free to raise an issue with associated MR for us.

## Build customization

For further customization you can create custom scripts for getting info
about:
 * current release version: `ci/version.sh`
 * component: `ci/componet.sh`
 * docker build script: `ci/docker-build.sh`


## ci-scripts maintainers' guide

#### How to release a new ci-scripts version
 * get MR with your changes upvoted
 * describe your changes in the [changelog](./CHANGELOG.md).
 * Cut a new release:
   * tag the release commit (we are using `v` version prefix. So, for example `v1.44.0` would be the new release tag.)
     * if the pipeline fails to build the new version, fix it and use a new version tag (it is fine to have a gap in the version numbers)
   * send an announcement about the new version to
     * tbd@creditas.cz
 * profit :)
