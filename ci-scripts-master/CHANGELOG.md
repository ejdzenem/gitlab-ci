# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.61.0] - 2022-05-31
### Changed
- upgrade Kustomize to 4.5.5

## [1.60.1] - 2022-05-24
### Fixed
- extract version form git tag

## [1.60.0] - 2022-05-04
### Added
- get version from Cargo
- get version from CI_COMMIT_TAG

## [1.59.0] - 2022-04-05
### Added
- basic support for ArgoCD

## [1.58.0] - 2022-02-22
### Changed
- upgrade kubectl to 1.19.9

## [1.57.0] - 2022-02-07
### Changed
- dropped docker-release-to-production-registry-dirt.sh

## [1.56.3] - 2022-01-25
### Fixed
- simplify and fix the release pipeline; maybe this release will build ;)

## [1.56.2] - 2022-01-25
### Fixed
- do not use docker.dev.dszn.cz when releasing ci-scripts

## [1.56.1] - 2022-01-25
### Fixed
- fixed CI/CD config; this version should not fail to build

## [1.56.0] - 2022-01-25
### Changed
- docker.ops.iszn.cz is now the default image registry, previous defauts
  pointed to services that have been turned off

## [1.55.1] - 2021-12-13
### Fixed
- `kubernetes-config{,-custom}.sh` now properly handle `--no-validate` option

## [1.55.0] - 2021-12-10
### Changed
- `docker-release-to-production-registry.sh` now fails when the source and
  destination images are the same, rather than succeeding

## [1.54.0] - 2021-10-27
### Changed
- use new gitlab pages base hostname: glpages.seznam.net

## [1.53.0] - 2021-10-14
### Changed
- kubernetes-config.sh and kubernetes-config-custom.sh now perform validation of generated manifests
  (can be disabled with --no-validate)

## [1.52.0] - 2021-01-21
### Changed
- `docker-release-to-production-registry.sh` outputs docker image digest and URI

## [1.51.0] - 2020-11-23
### Added
- install kubectl multiple versions, added 1.18.8 to use it set KUBECTL_BIN=/usr/local/bin/kubectl1.18.8

## [1.50.0] - 2020-11-11
### Added
- kubernetes-ci-init.sh now by default make sure that kubectl trusts any root szn ca signed certificate

## [1.49.0] - 2020-11-10
- new kubectl version (1.16.6)

## [1.48.1] - 2020-10-14
### Fixed
- help msg of docker-release.sh, docker-release-ci.sh
  - Docker registry related env variables

## [1.48.0] - 2020-10-13
### Added
- common.sh `docker_image_copy()` is now able to perform image copying with Harbor retag

## [1.47.1] - 2020-10-13
### Fixed
- drop possibly misleading err output of docker_image_copy
- poluted environment of unit tests

## [1.47.0] - 2020-10-13
### Changed
- release Docker image of ci-sripts solely to Harbor, projects used are:
  - sklik-devops-dev
  - sklik-devops

## [1.46.1] - 2020-10-05
### Fixed
- common.sh `docker_image_copy()` now detects docker image digest correctly

## [1.46.0] - 2020-10-05
### Added
- new release to production registry without DIRT docker-release-to-production-registry.sh
### Changed
- refactored support for docker login (SCIF docker.ops.iszn.cz)
- SCIF docker.ops.iszn.cz support in production-docker-image-name.sh

## [1.45.1] - 2020-09-29
### Fixed
- syntax error in support for docker login

## [1.45.0] - 2020-09-29
### Added
- support for docker login

## [1.44.0] - 2020-08-17
### Changed
- ci-scripts Docker image migrated to debian:buster
- git-lfs dependency is now installed as deb package rather than fetching built binary on specified URL


For previous version changes see the repository tags release notes.
