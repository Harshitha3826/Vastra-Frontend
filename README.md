# Vastra Frontend

## Overview
The **Frontend Service** is a React (Vite) single-page application for the VastraCo e-commerce platform. It is built into static assets and served via Nginx in production.

| Property | Value |
|----------|-------|
| **Framework** | React + Vite |
| **Serving** | Nginx (Alpine) |
| **Port** | 80 |
| **Docker Image** | `harshithasrinivas03/frontend-service` |

---

## Repository Structure
```
Vastra-Frontend/
├── .github/workflows/
│   └── ci.yml              # CI trigger — calls reusable template
├── src/
│   ├── components/         # React components
│   ├── pages/              # Page-level components
│   ├── services/           # API call functions
│   ├── App.jsx             # Root component
│   └── main.jsx            # Entry point
├── public/                 # Static assets
├── Dockerfile              # Multi-stage Docker build
├── vite.config.js          # Vite configuration
├── package.json
└── README.md
```

---

## Environment Variables

| Variable | Source | Description |
|----------|--------|-------------|
| `NODE_ENV` | ConfigMap | Environment (`dev` / `main`) |
| `USER_SERVICE_URL` | ConfigMap | Internal URL to User Service |
| `PRODUCT_SERVICE_URL` | ConfigMap | Internal URL to Product Service |
| `ORDER_SERVICE_URL` | ConfigMap | Internal URL to Order Service |

---

## CI/CD Pipeline

### Trigger
```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
```

### Pipeline Flow
```
ci.yml (this repo) ──calls──► ci-template.yml (Reusable-template repo)

Prepare → Test → SonarQube → Snyk → Docker Build (with npm run build) → Trivy → Docker Push → Update Helm → Release → Notify
```

Note: This service sets `run_build: true` in the CI config, which triggers `npm run build` before Docker build to generate the `dist/` folder.

### Branch-Based Deployment
| Branch | Values File | K8s Namespace | Environment |
|--------|-------------|---------------|-------------|
| `main` | `values-main.yaml` | `main` | Production |
| `develop` | `values-dev.yaml` | `dev` | Development |

---

## Dockerfile — Multi-Stage Build
```
Stage 1 (builder): node:20-alpine
  → npm install
  → COPY source code
  → npm run build → generates /app/dist

Stage 2 (runtime): nginx:alpine
  → COPY /app/dist → /usr/share/nginx/html
  → EXPOSE 80
  → CMD ["nginx", "-g", "daemon off;"]
```

**Security hardening:**
- Multi-stage build (Node.js not in final image — only Nginx + static files)
- Nginx Alpine — minimal attack surface
- No source code in production image

---

## Kubernetes Resources

| Resource | Name | Purpose |
|----------|------|---------|
| Deployment | `frontend-service` | Runs Nginx pods |
| Service | `frontend-service` | ClusterIP for gateway routing |
| ConfigMap | `frontend-service-config` | Service URLs and env config |
| HPA | `frontend-service-hpa` | Auto-scaling (2–10 pods, 60% CPU) |

### Health Probes
- **Liveness**: `GET /` (port 80) — Nginx serves index.html
- **Readiness**: `GET /` (port 80) — Nginx is ready to serve

---

## API Gateway Routing (Envoy)
The frontend is served as the **default route** via the Envoy Gateway:
```
External → Envoy Gateway → HTTPRoute:
  /api/auth/*      → user-service:3001
  /api/products/*  → product-service:3002
  /api/orders/*    → order-service:3003
  /*               → frontend-service:80  ← (default catch-all)
```

---

## Connection Verification

```bash
# Check pods
kubectl get pods -n main -l app=frontend-service

# Check service
kubectl get svc frontend-service -n main

# Check logs
kubectl logs -l app=frontend-service -n main --tail=50

# Test frontend is serving
kubectl run test --rm -it --image=curlimages/curl -- curl -s http://frontend-service.main.svc.cluster.local:80 | head -20

# Check gateway routing
kubectl get gateway -n main
kubectl get httproute -n main
```
