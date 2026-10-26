# School Backend

REST API for school management, built with Spring Boot 3 and PostgreSQL.

> **Project status:** 🚧 Work in progress. The application skeleton is in place, and I'm building the full DevOps workflow around it (containerization, CI/CD, GitOps, observability). See the [DevOps Roadmap](#devops-roadmap).

## Tech Stack

| Area | Technology |
|---|---|
| Language | Java 17 |
| Framework | Spring Boot 3.3.4 (Web, Data JPA) |
| Database | PostgreSQL |
| API docs | springdoc-openapi (Swagger UI) |
| Build | Maven (wrapper included) |

## Prerequisites

- JDK 17
- Docker (for the local database) or a local PostgreSQL instance
- Git

## Configuration

The committed `application.properties` contains **no secrets**. Everything sensitive is read from environment variables.

| Variable | Default | Description |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/db-school` | JDBC URL |
| `DB_USERNAME` | `postgres` | Database user |
| `DB_PASSWORD` | *(none, required)* | Database password |
| `SHOW_SQL` | `false` | Log SQL statements |
| `DDL_AUTO` | `validate` | Hibernate schema mode |
| `SPRING_PROFILES_ACTIVE` | *(unset)* | Active Spring profile |

Server settings: port `8082`, context path `/api`.

## Run Locally

### 1. Start PostgreSQL

**Option A: Homebrew install (macOS)**

```bash
brew services start postgresql@18
pg_isready                      # expect: accepting connections
```

Create a dedicated role and database (the default Homebrew superuser is your macOS username, not `postgres`):

```bash
psql postgres <<'SQL'
CREATE ROLE school_user WITH LOGIN PASSWORD 'change-me-locally';
CREATE DATABASE "db-school" OWNER school_user;
SQL

# verify
psql -U school_user -h localhost -d db-school -c '\conninfo'
```

> The database name contains a hyphen, so it must be double-quoted in SQL.

**Option B: Docker**

```bash
docker run -d --name school-db \
  -e POSTGRES_DB=db-school \
  -e POSTGRES_USER=school_user \
  -e POSTGRES_PASSWORD=change-me-locally \
  -p 5432:5432 \
  -v school_pgdata:/var/lib/postgresql \
  postgres:18
```

> For `postgres:18` and later, mount the volume at `/var/lib/postgresql` (not `/var/lib/postgresql/data`).

### 2. Create the `local` profile

Create `src/main/resources/application-local.properties`. This file is **git-ignored** and must never be committed.

```properties
spring.datasource.username=school_user
spring.datasource.password=change-me-locally
spring.jpa.show-sql=true
spring.jpa.hibernate.ddl-auto=update
```

### 3. Run the application with the `local` profile

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
```

Or with an environment variable:

```bash
SPRING_PROFILES_ACTIVE=local ./mvnw spring-boot:run
```

Or run without the profile by passing everything explicitly:

```bash
DB_USERNAME=school_user DB_PASSWORD=change-me-locally DDL_AUTO=update ./mvnw spring-boot:run
```

### 4. Verify

- API base URL: `http://localhost:8082/api`
- Swagger UI: `http://localhost:8082/api/swagger-ui/index.html`
- OpenAPI spec: `http://localhost:8082/api/v3/api-docs`

## Run with Docker Compose

Runs the app and PostgreSQL together, with no local Java or Postgres needed.

```bash
cp .env.example .env            # then set POSTGRES_PASSWORD in .env
docker compose config -q        # validate the file and required variables
docker compose up -d --build
docker compose ps               # both services should become "healthy"
curl -s localhost:8082/api/actuator/health/liveness
```

Useful commands:

```bash
docker compose logs -f backend
docker compose down             # stop, keep the database volume
docker compose down -v          # stop and DELETE the database volume
```

Ports are bound to `127.0.0.1` only: app on `8082`, Postgres on `5433` (to avoid clashing with a local Postgres on `5432`).

## Build and Test

```bash
./mvnw clean verify          # compile, run tests, package
./mvnw clean package -DskipTests
```

The JAR is generated in `target/school-1.0.0.jar`.

## CI Pipeline (Jenkins)

The pipeline is defined in the [`Jenkinsfile`](Jenkinsfile) and runs as a Jenkins Multibranch Pipeline: feature branches and PRs are built, tested and analysed, while versioning and publishing to Nexus happen only on `main`.

| Stage | What it does |
|---|---|
| Checkout | `checkout scm` from the job's configured repository |
| Bump version | `main` only. Sets the Maven version to `1.<BUILD_NUMBER>` in the workspace (not committed) |
| Build, Test & Coverage | `./mvnw clean verify`, then publishes JUnit results and the JaCoCo report |
| SonarQube Analysis | Sends code and coverage data to SonarQube (`sonar-token` credential) |
| Deploy to Nexus | `main` only. `./mvnw deploy -DskipTests` to the `maven-releases` repository (`nexus-creds` credential) |

After the stages, the pipeline sends Slack and email notifications on success or failure, then wipes the workspace.

Pipeline options: 20-minute timeout, no concurrent builds, last 20 builds and 5 artifact sets kept.

### Jenkins requirements

| Requirement | Details |
|---|---|
| Agent | JDK 17 on the PATH |
| Plugins | Pipeline, Git, JUnit, JaCoCo, Credentials Binding, Timestamper, Slack Notification, Email Extension |
| Credentials | `sonar-token` (secret text), `nexus-creds` (username and password) |
| Services | SonarQube on `127.0.0.1:9000`, Nexus on `127.0.0.1:8081` |
| Notifications | Slack workspace and SMTP settings configured in Jenkins |

Credentials are stored in Jenkins and referenced by ID only. They never appear in the repository.

### Local equivalent of the CI build

```bash
DB_USERNAME=school_user DB_PASSWORD=<your-local-password> DDL_AUTO=update \
  ./mvnw -B clean verify
open target/site/jacoco/index.html
```

## Profiles

| Profile | Purpose | Schema mode |
|---|---|---|
| *(default)* | Production-like, config from env vars | `validate` |
| `local` | Developer machine, SQL logging enabled | `update` |

## DevOps Roadmap

This project is also my playground for building a production-style DevOps workflow end to end. Status:

- [x] Git repository, `.gitignore`, secrets kept out of source control
- [x] Externalized configuration (12-factor style, env vars + profiles)
- [x] Multi-stage `Dockerfile` (non-root user, healthcheck; digest pinning still to do)
- [x] `docker-compose.yml` for the app + PostgreSQL stack
- [x] CI pipeline (Jenkins): build, unit tests, code coverage (JaCoCo)
- [x] Static analysis: SonarQube (quality gate enforcement still to do)
- [x] Build notifications: Slack and email
- [ ] Container image scanning: Trivy
- [x] Maven artifact publishing to Nexus with versioned releases (`1.<build number>`)
- [ ] Docker image publishing to a registry with versioned tags
- [ ] Kubernetes manifests (Deployment, Service, ConfigMap, Secret, probes, resource limits)
- [ ] GitOps deployment with ArgoCD
- [ ] Configuration management with Ansible
- [ ] Observability: Spring Boot Actuator, Prometheus, Grafana dashboards and alerts
- [ ] Database migrations with Flyway (switch to `ddl-auto=validate` everywhere)

## Branching Convention

- `main` is protected. Changes go through pull requests only.
- Feature branches: `feature/<short-description>`
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`, `ci:`, `docs:`).

## Security Notes

- Never commit credentials. Use environment variables or a secret manager.
- `application-local.properties`, `.env` files, and `settings.xml` are git-ignored.
- GitHub secret scanning and push protection should stay enabled on this repo.

## License

This project is licensed under the [MIT License](LICENSE).