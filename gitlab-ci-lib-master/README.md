# Gitlab Ci Library

Collection of common gitlab CI tasks

Each task should document the set of ENV variables and artifacts it depends on

## Usage

See Gitlab CI yaml reference for [`include`](https://docs.gitlab.com/ee/ci/yaml/#includefile).

TL;DR:

You can include your own bespoke set of tasks:

```yml
include:
  - project: 'sklik-backend/sklik.stats/gitlab-ci-lib'
    file: 'ci/tag-debian-version-check.yml'

  - project: 'sklik-backend/sklik.stats/gitlab-ci-lib'
    file: 'ci/tag-gradle-version-check.yml'

  ...
```

The version of the task used by default is from the HEAD of the master branch.
You can use a specific commit of HEAD of a branch using a `ref`

```yml
- project: 'sklik-backend/sklik.stats/gitlab-ci-lib'
  ref: pv-TP-1761-init-for-stataggregator-dummy
  file: 'ci/tag-debian-version-check.yml'
```

#### Gitlab CI tasks

##### generate-release-email
The task generates issue based on given template and sends email to author containing link of the issue.
To include the task in a component pipeline just extend chosen job and define variables used in issue or email template.
The list of variables possible to override is specified for each [job separately](https://gitlab.seznam.net/sklik-backend/sklik.stats/gitlab-ci-lib/-/blob/master/ci/generate-release-email.yml#L27).
Example of usage follows:
```yml
job-name-in-your-pipeline:
  variables:
    COMPONENT: your-awesome-component
    SERVERS: skotchlauncher.ko.seznam.cz
  extends: .generate-release-email-a6-issue
```


#### Pages
Additional scripts and templates, which need to be used directly in a pipeline, are available on gitlab pages compressed in tar file.
They could be used locally by:
 ```
 curl https://sklik-backend.glpages.seznam.net/sklik.stats/gitlab-ci-lib/ci-lib.tar.gz | tar xzf
```

### Automatically generated neighbourhood graph from [AutoGen](https://gitlab.seznam.net/sklik-backend/sklik.stats/auto-gen)
[![neighbourhood graph](https://sklik-backend.glpages.seznam.net/sklik.stats/auto-gen/output/per_component/sklik-backend/sklik.stats/gitlab-ci-lib/graph_plantuml_depth_1.png)](https://sklik-backend.glpages.seznam.net/sklik.stats/auto-gen/output/per_component/sklik-backend/sklik.stats/gitlab-ci-lib)
