# 🏰 Server Inventory & Status Report

**Host:** `GorevYoneticisi` (Task Manager)
**Role:** Primary Compute Node / Hybrid-Cloud Gateway
**Date Generated:** December 5, 2025

## 1. Hardware Specifications
The system is optimized for high-performance computing within a compact thermal envelope (Lenovo Tiny form factor).

| Component | Specification |
| :--- | :--- |
| **OS** | Ubuntu 24.04.3 LTS (Linux Kernel 6.8.0-88-generic) |
| **CPU** | Intel(R) Core(TM) i3-6300 CPU @ 3.80GHz (4 Threads) |
| **RAM** | 12 GB DDR4 (11Gi Usable) |
| **Uptime** | > 99.9% Availability |

## 2. Storage Architecture
Hybrid storage layout separating OS/Boot from persistent application data.

* **Boot/EFI:** `/dev/sda` (2GB)
* **System Root (LVM):** `/dev/mapper/ubuntu--vg-ubuntu--lv` (437GB) - *Hosting Docker OverlayFS*
* **Fast Storage (NVMe):** `/mnt/nvme256_nvme0n1p1` (234GB) - *Hosting VM Disks (QCOW2)*
* **Bulk Storage (HDD):** `/mnt/sdd2` (466GB) - *Media & Backups*

## 3. Virtualization & Containerization Layer
The architecture utilizes a dual-layer strategy: **KVM** for heavy OS virtualization and **Docker** for microservices.

### A. KVM/Libvirt (Virtual Machines)
| ID | Name | State | OS | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| 3 | `win2016` | **Running** | Windows Server 2016 | Legacy Game Servers (Assetto Corsa / BeamMP) |

### B. Docker Containers (Active Services)
| Service | Image | Status | Role |
| :--- | :--- | :--- | :--- |
| **Nginx Proxy Mgr** | `jc21/nginx-proxy-manager` | Up | SSL Termination & Ingress Routing |
| **Homepage** | `ghcr.io/gethomepage/homepage` | Healthy | Dashboard UI |
| **Stirling PDF** | `stirlingtools/stirling-pdf` | Up | PDF Manipulation Tool |
| **Navidrome** | `deluan/navidrome` | Healthy | FLAC Audio Streaming |
| **Nextcloud** | `bigbeartechworld/nextcloud` | Up | Private Cloud Storage |
| **WordPress** | `wordpress:latest` | Up | Web Hosting |
| **Crafty** | `crafty-controller` | Up | Minecraft Server Management |
| **Uptime Kuma** | `louislam/uptime-kuma` | Healthy | Service Monitoring |
| **Watchtower** | `containrrr/watchtower` | Healthy | Auto-Updates Containers |
| **Dashdot** | `mauricenino/dashdot` | Up | Server Resource Monitoring |
| **Duplicati** | `linuxserver/duplicati` | Up | Encrypted Offsite Backups |

## 4. Security & Network Telemetry
Security is enforced at the kernel and application level.

* **Tunnel Interface:** `10.88.88.2/24` (WireGuard Site-to-Site to VPS)
* **Management Backdoor:** `100.x.x.x` (Tailscale)
* **Intrusion Prevention:**
    * ✅ **CrowdSec:** Collaborative IPS parsing logs.
    * ✅ **Fail2Ban:** SSH brute-force protection.
* **Malware Defense:**
    * ✅ **ClamAV:** Daily filesystem scans.
    * ✅ **Rkhunter:** Rootkit detection.

## 5. Management Layer (CasaOS)
The system runs the CasaOS message bus and gateway services for simplified UI management over the underlying Ubuntu Server core.
* `casaos-gateway.service`: Active
* `casaos-app-management.service`: Active
