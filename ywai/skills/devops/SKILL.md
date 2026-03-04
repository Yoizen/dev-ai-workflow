---
name: devops
description: >
  Azure Pipelines and Helm chart conventions for multi-service projects.
  Trigger: When the user asks about CI/CD pipelines, Docker build/push, Helm charts, Kubernetes deployments, versioning strategy, or DevOps configuration.
license: Apache-2.0
metadata:
  author: Yoizen
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "pipeline"
    - "azure pipelines"
    - "helm"
    - "docker"
    - "devops"
    - "kubernetes"
    - "k8s"
    - "deploy"
    - "ci/cd"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash
---

## When to Use

- Creating or updating Azure Pipelines for multi-service projects
- Structuring Helm charts (Umbrella + sub-charts)
- Defining `values.yaml` with environment variable contracts
- Setting up versioning strategy for Docker images and Helm charts
- Configuring build & push pipelines triggered by version tags

---

## Azure Pipelines

### Trigger Strategy

- **Production pipeline**: triggered on tag creation matching `version/*`
- **Dev pipeline**: uses a predefined static version (e.g. `0.0.0-dev`)
- **NEVER** trigger production builds on branch pushes — only tags

### Version Extraction from Tag

The version is derived from the tag name by stripping the `version/` prefix:

| Tag | Extracted Version |
|-----|-------------------|
| `version/9.1.0` | `9.1.0` |
| `version/9.1.0-1` | `9.1.0-1` |
| `version/1.0.0-rc.1` | `1.0.0-rc.1` |

```yaml
# azure-pipelines.yml
trigger:
  tags:
    include:
      - version/*
  branches:
    exclude:
      - '*'

variables:
  - name: imageVersion
    value: $[ replace(variables['Build.SourceBranch'], 'refs/tags/version/', '') ]
```

### Pipeline Responsibilities

Each pipeline MUST:
1. **Build & push** Docker image for each service/API
2. **Package & push** the Umbrella Helm chart (containing all sub-charts + common-helpers)

Both the Docker image tags and the Helm chart version use the **same version** extracted from the git tag.

### Docker Build & Push Pattern

```yaml
steps:
  - task: Docker@2
    displayName: 'Build & Push $(serviceName)'
    inputs:
      containerRegistry: '$(acrServiceConnection)'
      repository: '$(productName)/$(serviceName)'
      command: buildAndPush
      Dockerfile: 'src/$(serviceName)/Dockerfile'
      tags: |
        $(imageVersion)
        latest
```

### Helm Package & Push Pattern

```yaml
steps:
  - script: |
      # Replace version placeholder in Chart.yaml
      sed -i "s/{{chartversion}}/$(imageVersion)/g" DevOps/Helm/values.yaml
      helm dependency update DevOps/Helm
      helm package DevOps/Helm --version $(imageVersion) --app-version $(imageVersion)
    displayName: 'Package Helm chart'

  - script: |
      helm push $(productName)-$(imageVersion).tgz oci://$(acrHost)/helm
    displayName: 'Push Helm chart to ACR'
```

---

## Helm Chart Structure

### Umbrella Chart Pattern

The project uses an **Umbrella Helm chart** that contains all service sub-charts and `common-helpers` as dependencies.

```
DevOps/Helm/
├── Chart.yaml                  # Umbrella chart — lists all sub-charts as dependencies
├── templates/
│   └── utils.yaml              # Defines shared ConfigMap and Secret templates
├── charts/
│   ├── api1/
│   │   ├── Chart.yaml          # Generic chart — name matches the service (api1)
│   │   └── templates/
│   │       ├── deployment.yaml # Generic deployment — no manual changes required
│   │       └── utils.yaml      # Declares common-helpers dependency hooks
│   ├── api2/                   # Same structure as api1
│   └── api3/                   # Same structure as api1
└── values.yaml                 # Unified values for all services
```

### Umbrella Chart.yaml

```yaml
apiVersion: v2
name: product-name
description: Umbrella Helm chart for all services
type: application
version: "{{chartversion}}"   # Replace key — substituted by pipeline
appVersion: "{{chartversion}}"

dependencies:
  - name: common-helpers
    version: "x.x.x"
    repository: "oci://your-registry/helm"
  - name: api1
    version: "0.1.0"
    repository: "file://charts/api1"
  - name: api2
    version: "0.1.0"
    repository: "file://charts/api2"
  - name: api3
    version: "0.1.0"
    repository: "file://charts/api3"
```

### Sub-chart Chart.yaml

```yaml
# DevOps/Helm/charts/api1/Chart.yaml
apiVersion: v2
name: api1        # MUST match the directory name and the values.yaml node name
description: Chart for api1 service
type: application
version: "0.1.0"

dependencies:
  - name: common-helpers
    version: "x.x.x"
    repository: "oci://your-registry/helm"
```

### Sub-chart deployment.yaml

The deployment template is **generic** — it reads values from `values.yaml` via the parent chart.
No manual modification is needed per service.

```yaml
# DevOps/Helm/charts/api1/templates/deployment.yaml
{{- include "common-helpers.deployment" . }}
```

### Sub-chart utils.yaml

```yaml
# DevOps/Helm/charts/api1/templates/utils.yaml
{{- include "common-helpers.configmap" . }}
{{- include "common-helpers.secret" . }}
```

---

## values.yaml Contract

### Structure Rules

- **One top-level node per service**, named identically to the service (e.g. `api1`, `api2`)
- `appName` inside each node MUST match the node key and the chart directory name
- `global.appVersion` uses `{{chartversion}}` as a replace key — substituted by the pipeline
- Values defined here are **defaults** — they MUST NOT be overridden at deploy time
- Deploy-time values ONLY extend this file (add new keys), never override existing ones

### Environment Variable Categories

| Key | Type | Purpose |
|-----|------|---------|
| `requiredConfigMapEnv` | list | Non-sensitive vars REQUIRED for startup. Pod won't start if missing. |
| `optionalConfigMapEnv` | list | Non-sensitive vars that are OPTIONAL. |
| `requiredSecretEnv` | list | Sensitive vars (secrets) REQUIRED for startup. |
| `optionalSecretEnv` | list | Sensitive vars (secrets) that are OPTIONAL. |

### values.yaml Template

```yaml
global:
  productName: productName          # Static value — used for k8s resource naming
  appVersion: "{{chartversion}}"    # Replace key — substituted by pipeline

api1:
  appName: api1                     # MUST match the top-level node name
  requiredConfigMapEnv:
    - client
    # Add all required non-sensitive env vars
  optionalConfigMapEnv:
    - NODE_ENV
    # Add all optional non-sensitive env vars
  requiredSecretEnv:
    - exampleSecretKey
    # Add all required sensitive env vars
  optionalSecretEnv: []
    # Add all optional sensitive env vars

api2:
  appName: api2
  requiredConfigMapEnv:
    - client
  optionalConfigMapEnv:
    - NODE_ENV
  requiredSecretEnv:
    - anotherSecretKey
  optionalSecretEnv: []

# Repeat for each service...
```

### Maintenance Rules

- **ALWAYS** update `values.yaml` when a service's environment variables change
- Add new env vars to the correct category (`required` vs `optional`, `ConfigMap` vs `Secret`)
- **NEVER** move a var from `required` to `optional` without coordinating with the team
- Sensitive values (passwords, tokens, API keys) → `*SecretEnv`
- Non-sensitive values (feature flags, URLs, names) → `*ConfigMapEnv`

---

## Critical Patterns

- **NEVER** hardcode versions in `Chart.yaml` or `values.yaml` — always use `{{chartversion}}` and replace via pipeline
- **ALWAYS** keep the service node key in `values.yaml`, the `appName` value, and the sub-chart directory name **in sync**
- **ALWAYS** package Helm chart after updating the version placeholder, before pushing
- **NEVER** override `values.yaml` defaults at deploy time — only extend with new keys
- **Pod startup is blocked** if `requiredConfigMapEnv` or `requiredSecretEnv` variables are not provided at deploy time
- The Umbrella chart version and all Docker image versions **MUST be identical** for the same release

---

## Resources

- **Templates**: See [assets/](assets/) for pipeline and chart templates
- **References**: See [references/](references/) for Helm and Azure Pipelines docs
