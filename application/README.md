# Hello World Next.js service

This directory contains the Next.js frontend, BFF health endpoint, and Docker
build context.

## Endpoints

- `/` serves the Hello World page.
- `/api/health` returns HTTP 200 and `{"status":"ok"}`.

## Local development

```bash
npm ci
npm run lint
npm run build
npm run dev
```

## Container

From the repository root, build and run the application with Docker Compose:

```bash
docker compose up --build
```

The image uses a multi-stage build, runs as UID 1001, and includes a Docker
health check for `/api/health`. Kubernetes readiness and liveness probes use
the same endpoint.
