###########################
# FRONT - build (Angular) #
###########################

FROM node:22.22.0-alpine3.23 AS front-build
WORKDIR /app/front

# 1) Copier d'abord les manifests pour profiter du cache Docker
COPY front/package.json front/package-lock.json ./

# 2) Install reproductible
RUN npm ci

# 3) Copier le reste et builder
COPY front/ ./
RUN npm run build


###############################################
# BACK - build (Spring Boot / Gradle Wrapper) #
###############################################

FROM gradle:8-jdk21 AS back-build
WORKDIR /home/gradle/src/back

# Copier le projet back
COPY back/ ./

# S'assurer que le wrapper est exécutable (Windows -> bit exec parfois perdu)
RUN chmod +x ./gradlew

# Build du jar (bootJar)
RUN ./gradlew --no-daemon clean bootJar


###########################
# FRONT - runtime (Caddy) #
###########################

FROM caddy:2.11-alpine AS front

# Caddyfile du repo : root * /app/front
COPY misc/docker/Caddyfile /etc/caddy/Caddyfile

COPY --from=front-build /app/front/dist/microcrm/browser/ /app/front/


################################
# BACK - runtime (Java 21 JRE) #
################################

FROM eclipse-temurin:21-jre-alpine-3.23 AS back

WORKDIR /app

# Copier le jar sans hardcoder le nom
COPY --from=back-build /home/gradle/src/back/build/libs/*.jar /app/app.jar

EXPOSE 8080

# Permet d'injecter des options via JAVA_OPTS (mémoire, etc.)
ENTRYPOINT ["sh", "-c", "exec java ${JAVA_OPTS:-} -jar /app/app.jar"]


##############
# Standalone #
##############

FROM alpine:3.23 AS standalone

RUN apk add --no-cache caddy openjdk21-jre-headless supervisor

# Alignement avec Caddyfile (root * /app/front)
COPY --from=front-build /app/front/dist/microcrm/browser/ /app/front/

# On garde un nom stable de jar
COPY --from=back-build /home/gradle/src/back/build/libs/*.jar /app/app.jar

COPY misc/docker/Caddyfile /etc/caddy/Caddyfile

COPY misc/docker/supervisor.ini /etc/supervisord.conf

EXPOSE 80 443 8080
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
