# MicroCRM (Orion) — Monorepo Full-Stack (Spring Boot  Angular) avec CI/CD

MicroCRM est une application CRM simplifiée (création/édition/visualisation d'individus et d'organisations) utilisée dans le scénario **Orion** pour mettre en œuvre une chaîne CI/CD : build, tests, contrôle sécurité, analyse qualité, conteneurisation et orchestration.

![Page d'accueil](./misc/screenshots/screenshot_1.png)
![Édition de la fiche d'un individu](./misc/screenshots/screenshot_2.png)

---

## Sommaire

- [Architecture & organisation du dépôt](#architecture--organisation-du-dépôt)
- [Versions retenues](#versions-retenues)
- [Prérequis](#prérequis)
- [Démarrage rapide (Docker Compose — recommandé)](#démarrage-rapide-docker-compose--recommandé)
- [Démarrage en local (sans Docker)]
(#démarrage-en-local-sans-docker)
  - [Back-end (API)](#back-end-api)
  - [Front-end (UI)](#front-end-ui)
- [Tests & contrôles](#tests--contrôles)
- [CI (GitHub Actions) + SonarCloud](#ci-github-actions--sonarcloud)
  - [Déclencheurs](#déclencheurs)
  - [Jobs](#jobs)
  - [Artefacts](#artefacts)
- [SonarCloud — configuration (Secrets + Variables GitHub)](#sonarcloud--configuration-secrets--variables-github)
- [Conteneurisation (Docker) & cibles de build](#conteneurisation-docker--cibles-de-build)
- [Smoke tests (exemples)](#smoke-tests-exemples)
- [Notes sécurité](#notes-sécurité)
[Monitoring (ELK) — centralisation des logs (local)](#monitoring-elk--centralisation-des-logs-local)
  - [Démarrage (app + ELK)](#démarrage-app--elk)
  - [Accès (Elasticsearch / Kibana)](#accès-elasticsearch--kibana)
  - [Logs collectés (Back + Front)](#logs-collectés-back--front)
  - [Kibana — première visualisation (Lens)](#kibana--première-visualisation-lens)
---

## Architecture & organisation du dépôt

Ce dépôt est un **monorepo** :

- `front/` : application **Angular** (UI)
- `back/` : API **Spring Boot** (Gradle)
- `misc/docker/` : configuration **Caddy** / **supervisor**
- `Dockerfile` : build multi-stage (front + back + standalone)
- `docker-compose.yml` : orchestration locale (front + back)
- `.github/workflows/ci.yml` : pipeline CI GitHub Actions (tests, builds, sécurité, qualité)

---

## Versions retenues

- **Front** : Angular 19 (`front/package.json` / `front/package-lock.json`)
- **Back** : Spring Boot 3.5 (`back/build.gradle`)

---

## Prérequis

- **Docker Desktop** (avec Docker Compose v2)
- **Java** : 21 (aligné CI)
- **Node.js / npm** : Node 22 (aligné CI)

---

## Démarrage rapide (Docker Compose — recommandé)

- Depuis la racine du dépôt :

```bash
docker compose up --build
```

- En mode détaché :

```bash
docker compose up -d --build
docker compose ps
```

- Arrêt / nettoyage :

```bash
docker compose down
```

- Endpoints :
  API : http://localhost:8080
  Front : https://localhost (redirigé depuis http://localhost)

## Démarrage en local (sans Docker) :

Ouvrez 2 terminaux : un pour back/, un pour front/.

1. Back-end (API)

- Aller dans le répertoire back :

```bash
cd back
```

- Construire le JAR :

```bash
# Linux / macOS
./gradlew build

# Windows
gradlew.bat build
```

2. Démarrer le service :

```bash
java -jar build/libs/microcrm-0.0.1-SNAPSHOT.jar
```

API disponible sur : http://localhost:8080

3. Front-end (UI)

- Aller dans le répertoire front :

```bash
cd front
```

- Installer les dépendances (première fois / après update) :

```bash
npm install
```

4. Démarrer le serveur de dev :

```bash
npx ng serve
```

UI disponible sur : http://localhost:4200

## Tests & contrôles :

1. Back-end — tests

```bash
cd back
./gradlew clean test

```

2. Front-end — tests (headless, compatible CI)
   Dépendances : Google Chrome ou Chromium

```bash
cd front
npx ng test --watch=false --browsers=ChromeHeadlessNoSandbox
```

3. Sécurité dépendances (front — runtime only)

```bash
cd front
npm audit --omit=dev --audit-level=high
```

## CI (GitHub Actions) + SonarCloud

### Le workflow CI est défini dans : .github/workflows/ci.yml.

### Déclencheurs

- push (toutes branches)
- pull_request (opened, synchronize, reopened)
- schedule (nightly)
- workflow_dispatch (manuel)

> Note : le job "Compose smoke test" est volontairement limité aux Pull Requests afin de servir de contrôle bloquant avant merge, tout en gardant la CI rapide sur les simples pushes de branches.

> Le smoke test Compose ne nécessite pas de secrets : il peut s'exécuter sur PR sans exposer d'informations sensibles.

### Jobs

- Back : Gradle clean test + bootJar + scan SonarCloud
- Front : npm ci + npm audit --omit=dev + tests Angular + build + scan SonarCloud
- Compose smoke test (PR) : build + démarrage via Docker Compose, puis vérification rapide (curl API + front), puis cleanup.

### Ordre d’exécution (front) et justification

Côté **front**, le pipeline applique un **security gate** `npm audit --omit=dev --audit-level=high` **immédiatement après** `npm ci`, avant les tests et le build.
Objectif : **fail fast** sur les vulnérabilités **runtime** High/Critical (celles réellement déployées) et éviter de consommer du temps CI sur des tests/build si la dépendance est bloquante.

Ensuite seulement :
1) tests unitaires Angular (Karma headless),
2) build Angular.

En complément, une exécution **nightly** génère un rapport d’audit plus complet (`npm audit --json`, dev inclus), archivé en artefact, **sans bloquer** la CI.

### Artefacts

La CI publie des artefacts consultables dans l'UI GitHub Actions (selon configuration), par ex. :

- rapports JUnit/HTML (back)
- rapport JSON npm audit (nightly, si activé)

## SonarCloud — configuration (Secrets + Variables GitHub)

### Dans Settings → Secrets and variables → Actions :

1. Secret

- SONAR_TOKEN

2. Variables

- SONAR_ORG
- SONAR_PROJECT_KEY_BACK
- SONAR_PROJECT_KEY_FRONT

### Où trouver les valeurs (SonarCloud)

- SONAR_ORG : clé/organisation SonarCloud (visible dans l'UI SonarCloud et utilisée via sonar.organization)
- SONAR*PROJECT_KEY*\* : clé du projet (Project Settings → General Settings / Project key)

⚠️ Ne jamais afficher un secret dans les logs (ex : pas de echo $SONAR_TOKEN).

## Conteneurisation (Docker) & cibles de build

Le Dockerfile (racine) permet de construire plusieurs cibles.

1. Front

```bash
docker build --target front -t orion-microcrm-front:latest .
docker run -it --rm -p 80:80 -p 443:443 orion-microcrm-front:latest
```

Front disponible sur : https://localhost (redirige depuis http://localhost)

2. Back

```bash
docker build --target back -t orion-microcrm-back:latest .
docker run -it --rm -p 8080:8080 orion-microcrm-back:latest
```

API disponible sur : http://localhost:8080

## Standalone (front + back dans la même image)

```bash
docker build --target standalone -t orion-microcrm-standalone:latest .
docker run -it --rm -p 8080:8080 -p 80:80 -p 443:443 orion-microcrm-standalone:latest
```

## Smoke tests (exemples)

### Smoke test automatisé en CI (Pull Requests)

En plus des exemples ci-dessous, la CI exécute un smoke test Docker Compose sur les Pull Requests :
- `docker compose up -d --build` (démarrage de la stack)
- vérification que l'API répond sur `http://localhost:8080/`
- vérification que le front répond sur `http://localhost/` (redirige vers HTTPS)
- `docker compose down -v --remove-orphans` (cleanup systématique)

Objectif : détecter avant merge tout problème de conteneurisation/orchestration (Dockerfile, ports, healthchecks, dépendances).

```bash
curl -I http://localhost:8080/
curl -I http://localhost/
curl -k -I https://localhost/
```

### Exemple de réponse :

PS <chemin du projet> curl.exe -I http://localhost:8080/

> > HTTP/1.1 204
> > Vary: Origin
> > Vary: Access-Control-Request-Method
> > Vary: Access-Control-Request-Headers
> > Date: Fri, 13 Feb 2026 05:15:41 GMT

- Interprétation : l'API Spring Boot est accessible et répond correctement sur le port 8080.
- 204 No Content signifie : "requête OK, mais pas de contenu à renvoyer”. C'est fréquent quand la route / n'est pas une page ou un endpoint qui retourne une ressource.

PS <chemin du projet> curl.exe -I http://localhost/

> > HTTP/1.1 308 Permanent Redirect
> > Connection: close
> > Location: https://localhost/
> > Date: Fri, 13 Feb 2026 05:15:50 GMT

- Interprétation : le front (Caddy) est joignable en HTTP mais applique une redirection permanente vers HTTPS.
- Location: https://localhost/ : confirme explicitement la destination de redirection.
- Connection: close : normal sur une réponse de redirection ; le serveur ferme la connexion après l'envoi de la réponse.

PS <chemin du projet> curl.exe -k -I https://localhost/

> > HTTP/1.1 200 OK
> > Accept-Ranges: bytes
> > Alt-Svc: h3=":443"; ma=2592000
> > Content-Length: 592
> > Content-Type: text/html; charset=utf-8
> > Etag: "dgdksc0xr8qogg"
> > Last-Modified: Fri, 13 Feb 2026 05:13:27 GMT
> > Server: Caddy
> > Vary: Accept-Encoding
> > Date: Fri, 13 Feb 2026 05:16:00 GMT

- Interprétation : le front est servi correctement en HTTPS (c'est le résultat attendu après la redirection 308).
- Pourquoi -k ? : -k ignore la vérification du certificat TLS. C'est utile ici car Caddy peut générer un certificat "internal” (auto-signé) en local, qui n'est pas reconnu par défaut par curl/Windows.
- Content-Type: text/html : confirme que le serveur renvoie bien une page HTML.
- Alt-Svc: h3=":443" : Caddy annonce la disponibilité de HTTP/3 (QUIC) — information normale.
- Etag / Last-Modified / Accept-Ranges : marqueurs standard de cache/serving statique.

## Politique de versioning

### Format

- Tags au format **SemVer** : `vMAJOR.MINOR.PATCH` (ex : `v1.2.3`).

### Déclenchement des versions (Conventional Commits)

Le workflow de versioning est **automatique**, mais il ne publie une nouvelle version **que si** l'historique contient des commits conformes à **Conventional Commits** :

- `fix: ...` → incrémente **PATCH**
- `feat: ...` → incrémente **MINOR**
- `BREAKING CHANGE: ...` (dans le body/footer) ou `feat!: ...` / `fix!: ...` → incrémente **MAJOR**

⚠️ Par défaut, des types comme `chore:`, `docs:`, `test:`, `style:` ne déclenchent pas de nouvelle version (donc pas de mise à jour de `package.json` / `build.gradle` tant qu'il n'y a pas de `fix`/`feat`/breaking change).

Références :

- SemVer : https://semver.org/
- Conventional Commits : https://www.conventionalcommits.org/en/v1.0.0/

### Flux CI/CD (où / quand / quoi)

1. **CI** — `.github/workflows/ci.yml` (push branches + PR)  
   Objectif : tests + build + contrôles (front/back), qualité & sécurité.

2. **Versioning** — `.github/workflows/semantic-release.yml` (push sur `main`)  
   Objectif : calculer la prochaine version, mettre à jour les fichiers de version, commit, puis créer le tag `vX.Y.Z`.

- Configuration : `.releaserc.yml` (racine)
- Mise à jour versions (monorepo) pendant le "prepar" :
  - `front/` : `npm version ${nextRelease.version} --no-git-tag-version` → met à jour `front/package.json` + `front/package-lock.json`
  - `back/` : remplacement de la ligne `version = '…'` dans `back/build.gradle`
  - Mise à jour du changelog : `CHANGELOG.md`
  - Commit des fichiers ci-dessus via `@semantic-release/git`

**Pourquoi un PAT (`RELEASE_TOKEN`) ?**  
Un push (commit/tag) fait depuis un workflow avec `GITHUB_TOKEN` peut ne pas déclencher d'autres workflows `on: push` (anti-boucle). Un PAT stocké en secret est la solution recommandée pour que le tag déclenche les workflows tag-based.

3. **Release GitHub + artefacts** — `.github/workflows/release.yml` (push tag `v*`)  
   Objectif : créer automatiquement une GitHub Release versionnée + attacher les artefacts (JAR + build Angular).

4. **CD Images Docker (GHCR)** — `.github/workflows/cd-images.yml` (push sur `main` + tags `v*.*.*`)  
   Objectif : build & push des images Docker sur GHCR, taggées avec la version.

### Release "test”

Pour valider la chaîne :

- faire une PR contenant au moins un commit `fix: ...` (ou `feat: ...`)
- merger sur `main`
- vérifier qu'un nouveau tag `v*` est créé, puis que `release.yml` et `cd-images.yml` s'exécutent sur ce tag.

### Sécurité

- Ne jamais afficher un secret dans les logs.
- Les tokens (PAT, Sonar, etc.) doivent rester uniquement dans GitHub Secrets.

## Monitoring (ELK) — centralisation des logs (local)

Objectif : ajouter un monitoring **local** basé sur **ELK** (Elasticsearch, Logstash, Kibana) pour :
- centraliser les logs du **back** (Spring Boot) et du **front** (Caddy)
- analyser facilement : **erreurs**, **volumétrie**, **pics d’activité**, **tendances**
- construire un tableau de bord simple dans Kibana

> ⚠️ ELK est une stack relativement lourde : à garder **hors CI/CD** (pas adapté à un pipeline) et à réserver au poste de dev.

Références (docs officielles / outils utilisés) :
- Elasticsearch (Docker  prérequis) : https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-basic
- Bootstrap checks (ex : `vm.max_map_count` sur Linux) : https://www.elastic.co/docs/deploy-manage/deploy/self-managed/bootstrap-checks
- Logstash input `file` (sincedb) : https://www.elastic.co/guide/en/logstash/current/plugins-inputs-file.html
- Kibana Lens : https://www.elastic.co/docs/explore-analyze/visualize/lens
- Caddy logging : https://caddyserver.com/docs/caddyfile/directives/log
- Logback JSON (logstash-logback-encoder) : https://github.com/logfellow/logstash-logback-encoder

### Démarrage (app  ELK)

Le monitoring se lance via un **docker-compose dédié** `docker-compose-elk.yml` superposé au compose principal :

```bash
docker compose -f docker-compose.yml -f docker-compose-elk.yml up --build
```

Pourquoi superposer 2 compose ?
- le compose “app” reste simple (front  back)
- le compose “ELK” peut être lancé **uniquement quand on en a besoin**
- séparation claire des responsabilités (application vs monitoring)

> Note : dans un contexte dev, on peut désactiver la sécurité Elastic pour simplifier l’accès (pas recommandé en prod).

### Accès (Elasticsearch / Kibana)

- Elasticsearch : http://localhost:9200
- Kibana : http://localhost:5601

### Logs collectés (Back  Front)

#### Back — Spring Boot (logs applicatifs)

But : produire des logs **structurés en JSON** (une ligne = un événement) pour pouvoir filtrer et agréger facilement dans Kibana.

Implémentation typique :
- conserver un log console lisible (dev)
- écrire un fichier de logs JSON (rotation quotidienne)

Référence : `logstash-logback-encoder` (Logback → JSON) :  
https://github.com/logfellow/logstash-logback-encoder

#### Front — Caddy (access logs HTTP)

Les “logs front” collectés ici correspondent aux **access logs HTTP** du serveur Caddy qui sert Angular :
- URL demandée
- code HTTP (200/404/500…)
- user-agent
- durée (selon configuration)

Directive officielle Caddy :  
https://caddyserver.com/docs/caddyfile/directives/log

### Kibana — première visualisation (Lens)

Objectif minimal attendu : une visualisation simple :
- **volume de logs** dans le temps
- **erreurs** dans le temps

#### 1) Vérifier que les logs arrivent (Discover)
1. Kibana → **Discover**
2. Créer/choisir une **Data view** (ex : `microcrm-logs-*`)
3. Vérifier que des documents s’affichent et que le champ temps est `@timestamp`

Doc Data views :  
https://www.elastic.co/docs/explore-analyze/find-and-organize/data-views

#### 2) Créer un graphe dans Lens (volume)
1. Depuis Discover, clique sur un champ agrégeable (ex : `@timestamp` ou `level`)
2. Clique **Visualize** → Kibana ouvre Lens
3. Dans Lens :
   - X = `@timestamp` (Date histogram)
   - Y = `Count`

Doc Lens :  
https://www.elastic.co/docs/explore-analyze/visualize/lens

#### 3) Graphe “erreurs dans le temps”
1. Dans Discover, filtre (KQL) :
   - `level : "ERROR"`
2. Ouvre Lens (Visualize)
3. Même graphe (X=`@timestamp`, Y=Count)

### Dépannage ELK (local)

#### Elasticsearch ne démarre pas
Causes fréquentes :
- RAM insuffisante allouée à Docker (ELK consomme plusieurs Go en local)
- sur Linux : `vm.max_map_count` trop bas (bootstrap checks)

Doc :  
https://www.elastic.co/docs/deploy-manage/deploy/self-managed/bootstrap-checks

#### Logstash “ne relit pas” les fichiers
Comportement souvent normal : l’input `file` suit la lecture via **sincedb** (il mémorise où il s’est arrêté).

Doc Logstash `file` / sincedb :  
https://www.elastic.co/guide/en/logstash/current/plugins-inputs-file.html

Pour repartir de zéro en local (⚠️ destructif : supprime les volumes) :

```bash
docker compose -f docker-compose.yml -f docker-compose-elk.yml down -v --remove-orphans
```
 
#### Logs & données sensibles (monitoring)

Le monitoring (ELK) centralise potentiellement :
- des URLs
- des messages d’erreur
- des informations applicatives pouvant contenir des identifiants ou des données personnelles selon le contenu des logs

Bonnes pratiques :
- éviter de logger des secrets (tokens, mots de passe)
- limiter le niveau de logs en production
- appliquer une politique de rétention adaptée (rotation / purge)

### Rejouer les dashboards Kibana (export/import)

Pour garantir la reproductibilité des visualisations (dashboards), le projet conserve un export Kibana **Saved Objects** (format `.ndjson`) :

- `elk/kibana/kibana-objects.ndjson`

#### Export (depuis Kibana)
1. Ouvrir Kibana → **Stack Management** → **Saved Objects**.
2. Cliquer **Export** et sélectionner le(s) dashboard(s) (ex : dashboard "Logs") + dépendances associées.
3. Sauvegarder le fichier sous `elk/kibana/kibana-objects.ndjson` puis le commit.

#### Import (sur une autre machine)
1. Ouvrir Kibana → **Stack Management** → **Saved Objects**.
2. Cliquer **Import** et sélectionner `elk/kibana/kibana-objects.ndjson`.
3. Vérifier que le dashboard apparaît et que les filtres (ex : `component:"backend"` / `component:"frontend"`) fonctionnent.
