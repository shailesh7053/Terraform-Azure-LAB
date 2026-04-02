## 🚀 Azure Virtual Desktop (AVD) – Terraform Deployment

This project provides a complete **Terraform-based deployment of Azure Virtual Desktop (AVD)** in a **cloud-only (Entra ID joined) architecture**, without any on-premises dependency.

It automates the provisioning of core AVD components including networking, host pool, session hosts, workspace, application group, monitoring, and RBAC.

---

## 📌 Key Features

* ✅ Cloud-only AVD deployment (Entra ID Join – no Active Directory required)
* ✅ Pooled Host Pool with Breadth-first load balancing
* ✅ Windows 11 Multi-session optimized VMs
* ✅ Secure networking with NSG rules (No public RDP exposure)
* ✅ Auto-registration of session hosts using DSC extension
* ✅ Entra ID RBAC integration for user access
* ✅ Azure Monitor + Log Analytics for diagnostics
* ✅ Scalable design using Terraform variables

---

## 🏗️ Architecture Overview

* **Resource Group** for all AVD resources
* **Virtual Network & Subnet** for session hosts
* **Network Security Group** restricting inbound traffic
* **AVD Host Pool (Pooled)** with session limits
* **Workspace + Application Group (Desktop access)**
* **Session Host VMs** (Windows 11 multi-session)
* **Entra ID Integration** for authentication
* **Log Analytics Workspace** for monitoring

---

## 🔐 Security Highlights

* No direct RDP access from the internet
* Users connect securely via AVD Gateway
* Role-based access using Entra ID groups
* HTTPS outbound allowed for required services only

---

## ⚙️ Deployment Details

* **Terraform Version:** >= 1.3.0

* **Providers:**

  * azurerm (~> 3.0)
  * azuread (~> 2.0)

* **Default Configuration:**

  * 2 Session Host VMs
  * VM Size: Standard_D4s_v3
  * Max sessions per host: 3
  * Region: East US

---

## 🔄 End-to-End Flow

1. User signs in via AVD Web Client
2. Authentication handled by Entra ID (MFA/SSO)
3. AVD Gateway routes traffic securely
4. Session host (Entra ID joined) provides desktop session

---

## 📤 Outputs

* Host Pool Name & ID
* Workspace ID
* Session Host VM Names
* AVD Client URL
* Log Analytics Workspace ID

---

## 🧠 Use Case

Ideal for:

* Cloud-first organizations
* Secure remote workforce setups
* No on-prem AD environments
* Scalable virtual desktop infrastructure

---

```mermaid
flowchart TD

    User[Entra ID User] -->|Login| WebClient[AVD Web Client]
    WebClient -->|Auth (MFA/SSO)| EntraID[Microsoft Entra ID]

    EntraID --> Gateway[AVD Gateway]
    Gateway --> HostPool[AVD Host Pool (Pooled)]

    HostPool --> VM1[Session Host VM 1]
    HostPool --> VM2[Session Host VM 2]

    VM1 -->|Entra Join| AADLogin[AADLoginForWindows Extension]
    VM2 -->|Entra Join| AADLogin

    VM1 -->|Register| DSC[AVD DSC Extension]
    VM2 -->|Register| DSC

    VM1 --> Monitor[Azure Monitor Agent]
    VM2 --> Monitor

    Monitor --> LogAnalytics[Log Analytics Workspace]

    subgraph Networking
        VNet[Virtual Network]
        Subnet[Subnet]
        NSG[Network Security Group]
    end

    VM1 --> Subnet
    VM2 --> Subnet
    Subnet --> VNet
    Subnet --> NSG
