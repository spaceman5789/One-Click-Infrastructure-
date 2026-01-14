# One-Click Infrastructure (UTM, 2 VMs) — Terraform + Ansible + Nginx + Postgres

Поднимаем окружение “с нуля” одной командой на macOS, используя **UTM**:
- **VM `app-vm`**: Nginx (reverse proxy) + Docker-контейнер приложения (FastAPI)
- **VM `db-vm`**: Docker-контейнер Postgres

Цель проекта — показать полный DevOps-цикл:
- IaC (Terraform)
- конфигурация (Ansible, идемпотентно)
- деплой приложения (Docker)
- reverse proxy (Nginx)
- pipeline проверки (GitHub Actions)

---

## Contents

- [One-Click Infrastructure (UTM, 2 VMs) — Terraform + Ansible + Nginx + Postgres](#one-click-infrastructure-utm-2-vms--terraform--ansible--nginx--postgres)
  - [Contents](#contents)
  - [Architecture](#architecture)
    - [Components](#components)
    - [Network Model](#network-model)
  - [Prerequisites](#prerequisites)
    - [On macOS](#on-macos)

---

## Architecture

### Components

- **Terraform**
  - управляет жизненным циклом VM в UTM через скрипты (`osascript`)
  - генерирует `ansible/inventory.ini`

- **Ansible**
  - ставит Docker + compose plugin
  - поднимает Postgres на `db-vm`
  - билдит и запускает приложение на `app-vm`
  - настраивает Nginx reverse proxy → `http://<APP_IP>/health`

### Network Model

Обе VM должны быть в режиме сети UTM:
- **Network Mode = macOS Shared Network**

Это позволяет:
- macOS (хосту) обращаться к VM по IP
- VM “видеть” друг друга

> Примечание: IP VM вытягивается из UTM через QEMU Guest Agent, поэтому он обязателен внутри шаблонной VM.

---

## Prerequisites

### On macOS

Установи инструменты:

```bash
brew install terraform ansible make