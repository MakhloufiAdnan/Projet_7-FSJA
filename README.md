# MicroCRM (Orion) — Monorepo Full-Stack (Spring Boot + Angular) avec CI/CD

MicroCRM est une application CRM simplifiée (création/édition/visualisation d’individus et d’organisations) utilisée dans le scénario **Orion** pour mettre en œuvre une chaîne CI/CD : build, tests, contrôle sécurité, analyse qualité, conteneurisation et orchestration.

![Page d'accueil](./misc/screenshots/screenshot_1.png)
![Édition de la fiche d'un individu](./misc/screenshots/screenshot_2.png)

---

## Sommaire

- [Architecture & organisation du dépôt](#architecture--organisation-du-dépôt)
- [Versions retenues](#versions-retenues)
- [Prérequis](#prérequis)
- [Démarrage rapide (Docker Compose — recommandé)](#démarrage-rapide-docker-compose--recommandé)
- [Démarrage en local (sans Docker)](#démarrage-en-local-sans-docker)
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

1) Back-end — tests
```bash
cd back
./gradlew clean test

```

2) Front-end — tests (headless, compatible CI)
Dépendances : Google Chrome ou Chromium
```bash
cd front
npx ng test --watch=false --browsers=ChromeHeadlessNoSandbox
```

3) Sécurité dépendances (front — runtime only)
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

### Jobs

- Back : Gradle clean test + bootJar + scan SonarCloud
- Front : npm ci + npm audit --omit=dev + tests Angular + build + scan SonarCloud

### Artefacts

La CI publie des artefacts consultables dans l’UI GitHub Actions (selon configuration), par ex. :
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
- SONAR_ORG : clé/organisation SonarCloud (visible dans l’UI SonarCloud et utilisée via sonar.organization)
- SONAR_PROJECT_KEY_* : clé du projet (Project Settings → General Settings / Project key)

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
```bash
curl -I http://localhost:8080/
curl -I http://localhost/
curl -k -I https://localhost/
```

### Exemple de réponse :

PS <chemin du projet> curl.exe -I http://localhost:8080/
>> 
HTTP/1.1 204 
Vary: Origin
Vary: Access-Control-Request-Method
Vary: Access-Control-Request-Headers
Date: Fri, 13 Feb 2026 05:15:41 GMT

- Interprétation : l’API Spring Boot est accessible et répond correctement sur le port 8080.
- 204 No Content signifie : “requête OK, mais pas de contenu à renvoyer”. C’est fréquent quand la route / n’est pas une page ou un endpoint qui retourne une ressource.

PS <chemin du projet> curl.exe -I http://localhost/
>> 
HTTP/1.1 308 Permanent Redirect
Connection: close
Location: https://localhost/
Date: Fri, 13 Feb 2026 05:15:50 GMT

- Interprétation : le front (Caddy) est joignable en HTTP mais applique une redirection permanente vers HTTPS.
- Location: https://localhost/ : confirme explicitement la destination de redirection.
- Connection: close : normal sur une réponse de redirection ; le serveur ferme la connexion après l’envoi de la réponse.

PS <chemin du projet> curl.exe -k -I https://localhost/
>>
HTTP/1.1 200 OK
Accept-Ranges: bytes
Alt-Svc: h3=":443"; ma=2592000
Content-Length: 592
Content-Type: text/html; charset=utf-8
Etag: "dgdksc0xr8qogg"
Last-Modified: Fri, 13 Feb 2026 05:13:27 GMT
Server: Caddy
Vary: Accept-Encoding
Date: Fri, 13 Feb 2026 05:16:00 GMT

- Interprétation : le front est servi correctement en HTTPS (c’est le résultat attendu après la redirection 308).
- Pourquoi -k ? : -k ignore la vérification du certificat TLS. C’est utile ici car Caddy peut générer un certificat “internal” (auto-signé) en local, qui n’est pas reconnu par défaut par curl/Windows.
- Content-Type: text/html : confirme que le serveur renvoie bien une page HTML.
- Alt-Svc: h3=":443" : Caddy annonce la disponibilité de HTTP/3 (QUIC) — information normale.
- Etag / Last-Modified / Accept-Ranges : marqueurs standard de cache/serving statique.