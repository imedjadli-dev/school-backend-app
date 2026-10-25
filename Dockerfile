
ARG MAVEN_IMAGE=maven:3.9.9-eclipse-temurin-17
ARG JRE_IMAGE=eclipse-temurin:17-jre

# build stage

FROM ${MAVEN_IMAGE} AS build
WORKDIR /workspace

# install dependencies
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q dependency:go-offline

COPY src ./src
RUN --mount=type=cache,target=/root/.m2 \
    mvn -B -q clean package -DskipTests

# runtime stage
FROM ${JRE_IMAGE}
RUN groupadd -g 10001 app \
    && useradd -u 10001 -g app -s /usr/sbin/nologin -d /app app

WORKDIR /app
COPY --from=build --chown=10001:10001 /workspace/target/*.jar app.jar

ENV SERVER_PORT=8082 \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

USER 10001:10001
EXPOSE 8082

HEALTHCHECK --interval=30s --timeout=3s --start-period=45s --retries=3 \
           CMD wget -q --spider "http://127.0.0.1:${SERVER_PORT}/api/actuator/health/liveness" || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
