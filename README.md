# 🚀 Terraform + GitHub Actions Demo (Azure)

Este proyecto es una **demo básica** para desplegar un **Grupo de Recursos en Azure** usando **Terraform** y **GitHub Actions** con autenticación OIDC.

---

## 📂 Estructura del proyecto

.github/
└── workflows/
├── plan.yaml # Workflow para generar un plan
└── apply.yaml # Workflow para aplicar los cambios
.gitignore
main.tf # Infraestructura principal
variables.tf # Variables de Terraform

## README.md

---

## ⚙️ Infraestructura

Actualmente, solo se despliega:

- **Grupo de Recursos**: `GrupoDojo`  
- **Región**: `eastus2`

Definido en [`main.tf`](main.tf).

---

## 🔑 Variables

Definidas en [`variables.tf`](variables.tf):

- `resource_group_name`: Nombre del grupo de recursos.
- `location`: Región donde se creará el recurso.

Estas variables se pasan mediante **GitHub Secrets**:

- `TF_VAR_resource_group_name`
- `TF_VAR_location`

---

## 🔒 Secrets requeridos en GitHub

En tu repositorio → **Settings → Secrets and variables → Actions**:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TF_VAR_resource_group_name` = `GrupoDojo`
- `TF_VAR_location` = `eastus2`

---

## ▶️ Uso local

1. Autentícate en Azure:

   ```bash
   az login
