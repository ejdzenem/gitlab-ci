# gitlab-ci

Repozitar pro gitlab CI/CD templaty



# Zakladni pouziti

## Demo projekt
https://gitlab.seznam.net/tomas.sekanina/cicd-scout

## Secrety
1. secret pro Harbor **robot$mapycz-dev+gitlab**  
    https://docs.gitlab.com/ee/ci/docker/using_docker_images.html#determine-your-docker_auth_config-data  

    FYI: Jak zamaskovat secret v jsonu: https://gitlab.com/gitlab-org/gitlab/-/issues/13514#note_460116599  

## Vytvoreni pipelajny
Pridat do repozitare soubor `.gitlab-ci.yml`


## Vlozeni templatu
```yaml
include: 
  - project: 'tomas.sekanina/gitlab-ci'
    ref: master
    file: '/gitlab-ci/base.yml'
```
## Definice pipeline
```yaml
stages:
  - prep
  - build
  - test
  - development
  - tag
  - testing
  - staging
  - stable
```

## Definice jobu
Priprava -> vytvoreni image -> deploy do masteru
```yaml
### preparation stage, calculate some variables, which are passed via env artifact
prep:
  stage: prep
  extends:
    - .prep

### Build stage
app-build:
  stage: build
  variables:
    COMP: $COMPONENT
  extends: 
    - .docker

### deployment jobs
master:
  stage: development
  variables:
    LOCALITY: ng1
  extends: 
    - .deploy-master
```

# Odkazy
* https://gitlab.seznam.net/mapycz/reloader-deploy/-/blob/master/.gitlab-ci.yml - deploy do provozu
* https://stackoverflow.com/a/64448994 - ci checks
* https://docs.gitlab.com/ee/ci/variables/predefined_variables.html - predefined variables

# TODO
* Pridat globalni config pro mapy na pristup do harboru
* Doladit nasazeni do provozu
* Spravna detekce environmentu
* Zkontrolovat, ze se spousti stop job pro branch deployment
* zbavit se (asi) `only` a `expects` az bude kompatibilni `rules` s `when: manual`
* Pripravit dummy pipelajnu sem do projektu, na testovani zmen konfigurace
  