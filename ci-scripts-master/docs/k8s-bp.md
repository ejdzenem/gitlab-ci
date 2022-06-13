## Jednotná konfigurace aplikace v kubernetes pro různá nasazení

## Jaké jsou možnosti při konfigurování 

### Špatné konce aneb takhle ne

- **různé konfigurace projektu jsou v různých konfiguračních souborech s velkou mírou duplikace**
- každý projekt má vlastní sadu CICD skriptů používající vlastní fáze
- každý projekt má vlastní adresářovou strukturu (nekompatibilní s ostatními projekty)
- jednu konfigurační volbu v projektu lze nastavit různými způsoby v několika různých souborech
- každý projekt volí jinou cestu jak se finální balík (deb, docker image) dostává do produkce
- každý projekt má různý způsob jak poznat že daný balík odpovídá konkrétnímu stavu zdrojového repozitáře
- neexistují doporučení jak správně konfigurovat aplikace v kubernetes i jinde

#### Aplikace většinou respektuje konfiguraci prostřednictvím:

- konfiguračního souboru
- ten je statický nebo generovaný z šablony konfiguračního souboru na základě proměnných prostředí `goenvtemplatorem2`.
- přímo proměnných prostředí

#### Pokud chceme být jako tým/produkt/firma úspěšní

- Nesnažme se
- Poučme se jak z interních projektů tak externích open-source projektů
- Komunikujme a sdílejme napříč týmy více

#### Pojďme sjednocovat CICD postupy

- Používejme společnou CICD knihovnu ci-scripts
- Používejme kompatibilní způsoby automatického nasazování
- na devu různé jmenné prostory pro master a pro staging
  - příklad (nasazování do devového kubernetes):
    - master komit nasazuje do jmenného prostoru `_master`
    - komit v masteru zatagovaný dle konvence nasazuje do jmenného prostoru  `_staging`
- směřujeme k automatickému nasazování i v produkci v budoucnu (autoadmins app) 

##### Výhody
- zamezení duplikace CICD kódu
- snažší udržování
- standardizace

Pojďme sjednocovat adresářovou strukturu

- Používejme kompatibilní adresářovou strukturu
- konfigurace aplikace v adresáři `conf` (konfigurační soubory)
- rozdíly mezi implicitní (provozní) konfigurací a devel konfigurací v souborech `conf/*.env` (např. `confdevelopment.env`)
- kubernetes manifesty v souborech `kubernetes\*.yaml\*`
- mtail programy v adresáři `mtail\*.mtail\*`
#### Výhody
- snazší orientace v projektech napříč týmy, usnadnění znovupoužití kódu jiným týmem

Pojďme používat konfigurační šablony

- Při nasazování aplikace existuje hned několik prostředí do nichž chceme aplikaci nasadit:
- produkční prostředí
- testovací či lokální prostředí
- vývojářské prostředí
- předprodukční prostředí
- ...
- Abychom zabránili duplikaci jednotlivých konfiguračních sad je třeba používat konfigurační šablony.
- Používáme GOLANG šablony (`goenvtemplator2`, `helm`, golang sprig, ...)
- Rozlišujeme tva typy šablon
- šablony aplikačních konfiguračních souborů (v `conf`)
- šablony kubernetes manifestů (v `kubernetes`)
- Odlišení jednotlivých sad konfiguračních souborů se děje na dvou místech:
  - souborem `conf/*.env` (příklad confdevelopment.env)
    - tímto způsobem se ovlivňují šablony aplikačních konfiguračních souborů
- proměnnými prostředí v CI souboru (`.gitlab-ci.yaml`, Jenkinsfile,...)
  - tímto způsobem se ovlivňují šablony kubernetes manifestů
#### Výhody
- zamezení duplikace konfiguračních souborů
- flexibilní testování (konfigurace závislá pouze na proměnných prostředí)
- šablony jsou zavedený způsob řešení konfiguračního hellu

##### Pojďme sjednocovat jednotlivé aplikační konfigurace

- Udržujme implicitní konfiguraci shodnou s produkční konfigurací aplikace
  - výjimku tvoří hesla, certifikáty a generované konfigmapy (z conf/*.env)
- Uložme implicitní (produkční) konfiguraci na jednom místě (v jednom konfiguračním souboru)
- vyhněme se několika implicitním konfiguracím v různých souborech (např. entrypoint + Dockerfile + kubernetes manifest)
- Generujme další konfigurace (devová) prostřednictvím souborů `conf/*.env`
- Udržujme ostatní konfigurace co nejvíce stejné (soubory `conf/*.env` co nejkratší)

##### Výhody

- je zřejmé jaká je produkční konfigurace
- je zřejmé jak se liší konkrétní (testovací) konfigurace od té provozní
- Nevýhody
- při změně produkční konfigurace je třeba tuto zpětně zanést do implicitní konfigurace aplikace

Pojďme udržet pořádek v generovaných 

balících  artefaktech  verzích

- Používejme důsledně semantické verzování v2 [https://semver.org](https://semver.org)
  - tagujme verzi podle schématu `vX.Y.Z` nebo `<komponenta>-X.Y.Z`
- Používejme docker labely dle schematu `label-schema.orgrc1`
  - info o projektu, verzi, komitu, git repozitáři, ...
- Důsledně dodržujme tři úložiště generovaných balíků  docker obrazy  artefaktů
- dočasné úložiště pojme artefakty generované z CI pro každý komit, automaticky je promazáváno (repo.devtemporary, cid.dev)
- vývojářské úložiště pojme artefakty generované z CI pro komit z masteru který je správně zatagován (repo.devtesting, docker.dev)
- produkční úložiště, přesun artefaktů z toho co má patřičnou kvalitu  (repo.devstable, doc.ker)

#### Dodržujme (kubernetes) konvence

- Ukládejme kubernetes manifesty do správně pojmenovaných souborů `<app>-<objekt>.yaml`
- příklady: `export-manager-sentry-secret.yaml.example`, `frontend-api- deployment.yaml.tmpl`
- Vždy směřujme aplikace na kubernetes service objekty
- uvnitř kubernetes je daná aplikace k dispozici na PQDN `<service- name>` nebo `<service-name>.<namespace-name>`
- pro závislost na externí službě (např. databázi) použijeme `externalName` service

#### Nezapomínejme na vyplněná metadata a ostatní požadavky:
- label `app`
- vývojářský tým (emailová adresa)
- logovací formát
- vystavování a sběr metrik
- definované resources
- definované readinesslivenessProbe

#### Shrnutí 

- Nejsme v tom sami a tak není třeba vymýšlet již vymyšlené
- Existují cesty jak efektivně konfigurovat aplikace
- sjednoťme konfigurace aplikací, vyjděme z provozní konfigurace
- používejme konfigurační šablony pro zamezení duplikace
- používejme standardizované CICD (ci-scripts)
- používejme sémantické verzování (v2)
- sjednoťme adresářové struktury

#### Příklad adresářové struktury


