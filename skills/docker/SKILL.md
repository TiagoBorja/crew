---
name: docker
description: Image hygiene, multi-stage builds, compose for local development and container security basics. Use when writing or reviewing a Dockerfile or compose file, slimming or hardening an image, or setting up a local multi-service environment.
tags: [docker, containers]
---

# Docker

## Dockerfile principles
- Pin the base image to a specific version tag (ideally also a digest for production); avoid `latest`. Prefer small, maintained bases (slim or distroless variants) that fit the runtime's needs.
- Order instructions from least to most frequently changing to maximise layer cache: base, system packages, dependency manifests and install, then source copy, then build.
- Copy only dependency manifests first, install dependencies, then copy the rest, so code edits do not invalidate the dependency layer.
- Combine related commands in one `RUN` and clean up in the same layer (for example remove package lists and caches). Use `--no-install-recommends` style options where relevant.
- Prefer `COPY` over `ADD`. Be explicit about paths; never `COPY . .` without a good `.dockerignore`.
- Use exec-form `CMD` and `ENTRYPOINT` (`["app", "--flag"]`) so signals reach the process; make the app handle SIGTERM for graceful shutdown.
- Add `HEALTHCHECK` where the platform does not provide its own probes.
- Set `WORKDIR`, avoid `cd` in `RUN`.

## Multi-stage builds
```dockerfile
# build stage: toolchain, dev dependencies, compilation
FROM example-builder:1.2 AS build
WORKDIR /src
COPY manifest-files ./
RUN install-dependencies
COPY . .
RUN build-the-app

# runtime stage: only what is needed to run
FROM example-runtime:1.2
WORKDIR /app
COPY --from=build /src/dist ./dist
USER app
CMD ["run", "dist/main"]
```
- Build tools, compilers, test dependencies and source stay in the build stage; the final image holds only runtime artifacts.
- Name stages; use `--target` to build a test or debug stage.
- Use build cache mounts where supported to speed up package installs.

## `.dockerignore`
Always provide one. Exclude version-control data, local env files, dependency directories rebuilt in the image, build output, logs, IDE files and test artifacts. A small context builds faster and cannot leak local secrets into layers.

## Security
- Run as a non-root user (`USER`) with a fixed numeric id; make only needed paths writable.
- Never put secrets in the image: not in `ENV`, `ARG`, `COPY`d files or layers (they persist in history). Use runtime environment variables, mounted secrets or the build tool's secret mounts.
- Install only needed packages; remove build tools from the final image. Scan images with the project's scanner and rebuild regularly for base updates.
- Prefer a read-only root filesystem and dropped capabilities at runtime where the platform allows.
- Verify downloaded artifacts with checksums or signatures; avoid piping remote scripts to a shell.

## Compose for local development
```yaml
services:
  app:
    build: .
    ports: ["8080:8080"]
    environment:
      DATABASE_URL: postgres://app:${DB_PASSWORD}@db:5432/app
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./src:/app/src
  db:
    image: example-db:16
    environment:
      DB_PASSWORD: ${DB_PASSWORD}
    healthcheck:
      test: ["CMD", "db-ready-check"]
      interval: 5s
      retries: 10
    volumes:
      - dbdata:/var/lib/data
volumes:
  dbdata:
```
- Compose is for local development and tests, not a production orchestrator recipe.
- Use health checks with `depends_on` conditions instead of sleep loops.
- Keep values in a git-ignored `.env` file and commit an `.env.example` with placeholders only.
- Use named volumes for data, bind mounts for source in dev. Bind only to localhost for ports that need not be public.
- Use profiles or override files for optional services and dev-only settings.
- Services reach each other by service name on the compose network.

## Debugging and size
- Inspect layers with `docker history` and check what is large; look for caches, build tools and duplicated files.
- Reproduce a failing build with `--progress=plain --no-cache` once to rule out stale layers.
- `docker run --rm -it --entrypoint sh <image>` to look inside; remove debug tooling from production images.
- Logs go to stdout and stderr, not files inside the container.

## Rules for agents
- Building and running local containers is fine. Pushing images, deploying, deleting images or volumes holding data, and any production access require explicit approval.
- Verify the result by building and running it (skill:verification-loop) and report the image size and the commands used.
