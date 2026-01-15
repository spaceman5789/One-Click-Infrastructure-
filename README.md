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
  - [Quick Start](#quick-start)
  - [Full Walkthrough](#full-walkthrough)
    - [1. Template VM Preparation (UTM)](#1-template-vm-preparation-utm)
    - [2. Infrastructure (Terraform)](#2-infrastructure-terraform)
    - [3. Configuration (Ansible)](#3-configuration-ansible)
    - [4. App + Reverse Proxy](#4-app--reverse-proxy)
    - [5. Verification](#5-verification)
  - [Frontend & CSS](#frontend--css)

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

### Вся эта штука работает только только на macOS, потому что используется гипервизор UTM, который есть только на маке, поэтому не подойдет для других, по типу VMware и так далее.

Установи инструменты:

```bash
brew install terraform ansible make
```

---

## Quick Start

```bash
make up
```

Если команда упадет на первом запуске, смотри полный walkthrough ниже: обычно причина — неготовый UTM шаблон (guest agent, ISO).

---

## Full Walkthrough

Ниже — полная, пошаговая история запуска проекта (как он реально разворачивается).

### 1. Template VM Preparation (UTM)

1) В UTM должен быть шаблон `tmpl-ubuntu` (у меня это Debian 12 ARM64).
2) Внутри шаблона должна быть установленная ОС и **QEMU Guest Agent**:

```bash
sudo apt update
sudo apt install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
sudo systemctl status qemu-guest-agent
```

3) В UTM нужно **отключить ISO** (CD/DVD → Eject/Empty), чтобы VM загружалась в установленную систему, а не в установщик.

Почему это важно:
- Terraform/UTM получают IP через guest agent. Без него IP не будет, и Terraform упадет.

### 2. Infrastructure (Terraform)

Terraform делает три вещи:
- Создает/запускает `app-vm` и `db-vm` из шаблона.
- Получает IP обеих VM через guest agent.
- Генерирует `ansible/inventory.ini`.

Запуск:

```bash
cd terraform && terraform apply -auto-approve
```

Полезные команды:

```bash
terraform output -raw app_ip
terraform output -raw db_ip
```

### 3. Configuration (Ansible)

Ansible подключается по SSH к обеим VM под пользователем `debian` и выполняет роли:
- `docker` — установка Docker
- `app` — копирование исходников, сборка образа, запуск контейнера
- `nginx` — reverse proxy на app
- `db` — контейнер Postgres

Запуск:

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

### 4. App + Reverse Proxy

На `app-vm`:
- FastAPI приложение запускается в Docker.
- Nginx проксирует запросы на `http://127.0.0.1:8000`.

Endpoints:
- `GET /health` → `{"status":"ok"}`
- `GET /health/db` → `{"db":"ok"}` (проверка связи с Postgres)

### 5. Verification

```bash
APP_IP=$(cd terraform && terraform output -raw app_ip)
curl -i http://$APP_IP/health
curl -i http://$APP_IP/health/db
```

Проверка Postgres контейнера:

```bash
DB_IP=$(cd terraform && terraform output -raw db_ip)
ssh -o StrictHostKeyChecking=no debian@$DB_IP "docker ps | grep postgres"
```

---

