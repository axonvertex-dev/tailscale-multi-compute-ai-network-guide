# Tailscale Multi-Compute AI Network Guide

A practical repository for connecting Linux GPU servers, macOS workstations, and Windows systems using WSL to one private Tailscale network, then using that network for SSH administration and private AI model routing.

## Scope

This repository configures Tailscale connectivity, SSH access, access policy, endpoint verification, and a reference model router. It does not install Ollama, MLX, vLLM, model weights, or other inference runtimes. Install and verify the required model servers on their respective compute nodes before expecting routed inference to work.

The repository is based on the same operating pattern used in a multi-node AI SRE environment:

- One identity-backed private network, called a **tailnet**.
- User-owned laptops authenticated as people.
- Shared compute machines authenticated as service nodes with tags.
- Linux GPU nodes and macOS MLX nodes reachable by stable Tailscale IP addresses and MagicDNS names.
- SSH and model API ports restricted through the Tailscale policy file.
- A central model router that selects a backend according to workload, capability, health, and fallback order.

## Example network

```text
rentorzo@RENTORZOs-MacBook-Pro-2 ~ % tailscale status
100.76.212.84   rentorzos-macbook-pro-2      krishdasgupta.official@  macOS  -
100.82.103.57   axonvertex-01                krishdasgupta.official@  linux  -
100.99.149.21   axonvertex-personal-01       krishdasgupta.official@  linux  -
```

Logical roles used in this guide:

```text
rentorzos-macbook-pro-2
  Operator workstation, optional MLX inference node, optional model gateway

axonvertex-01
  Primary Linux GPU node for larger or more capable models

axonvertex-personal-01
  Secondary Linux GPU node for smaller models, fallback inference, and testing
```

## What this repository contains

```text
tailscale-multi-compute-ai-network-guide/
├── README.md
├── SECURITY.md
├── LICENSE
├── Makefile
├── .gitignore
├── config/
│   ├── model-router.env.example
│   ├── models.example.yaml
│   └── tailnet-policy.example.hujson
├── docs/
│   ├── 00-ARCHITECTURE.md
│   ├── 01-TAILNET-ACCOUNT-IDENTITY.md
│   ├── 02-LINUX-SETUP.md
│   ├── 03-MACOS-SETUP.md
│   ├── 04-WINDOWS-WSL-SETUP.md
│   ├── 05-SSH-AND-ACCESS-CONTROL.md
│   ├── 06-MULTI-COMPUTE-MODEL-ROUTING.md
│   ├── 07-SECURITY-HARDENING.md
│   ├── 08-TROUBLESHOOTING.md
│   ├── 09-OPERATIONS-RUNBOOK.md
│   ├── 10-OFFICIAL-REFERENCES.md
│   ├── 11-PUBLISH-TO-GITHUB.md
│   └── 12-LINUX-MODEL-ROUTER-SERVICE.md
├── router/
│   ├── README.md
│   ├── model_router.py
│   ├── requirements.txt
│   └── systemd/model-router.service
└── scripts/
    ├── verify-tailnet.sh
    ├── test-model-endpoints.sh
    ├── linux/install-tailscale.sh
    ├── linux/configure-ollama-tailnet.sh
    ├── linux/run-model-router.sh
    ├── linux/install-model-router-service.sh
    ├── macos/check-tailscale.sh
    └── wsl/check-wsl-connectivity.sh
```

## Recommended reading order

1. [Architecture and operating model](docs/00-ARCHITECTURE.md)
2. [Create the tailnet and add identities](docs/01-TAILNET-ACCOUNT-IDENTITY.md)
3. Choose the platform guide:
   - [Linux](docs/02-LINUX-SETUP.md)
   - [macOS](docs/03-MACOS-SETUP.md)
   - [Windows with WSL](docs/04-WINDOWS-WSL-SETUP.md)
4. [SSH and access control](docs/05-SSH-AND-ACCESS-CONTROL.md)
5. [Multi-compute model routing](docs/06-MULTI-COMPUTE-MODEL-ROUTING.md)
6. [Security hardening](docs/07-SECURITY-HARDENING.md)
7. [Troubleshooting](docs/08-TROUBLESHOOTING.md)
8. [Operations runbook](docs/09-OPERATIONS-RUNBOOK.md)
9. [Install the Linux model-router service](docs/12-LINUX-MODEL-ROUTER-SERVICE.md)
10. [Publish the repository to GitHub](docs/11-PUBLISH-TO-GITHUB.md)

## Fast path

### 1. Create the tailnet

Create a Tailscale account using an existing identity provider account. The first login creates the tailnet. Keep MagicDNS enabled.

### 2. Add the Mac operator machine

Install the recommended standalone macOS client, sign in, install CLI integration, and verify:

```bash
tailscale status
tailscale ip -4
tailscale ping axonvertex-01
```

### 3. Add Linux compute nodes

On each Ubuntu or Debian node:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

tailscale status
tailscale ip -4
```

For a Linux node that will accept Tailscale SSH:

```bash
sudo tailscale set --ssh
```

Do not close the original administrative session until a second SSH session over the Tailscale address has succeeded.

### 4. Windows users work through WSL

The default mode is:

- Install and run Tailscale on the Windows host.
- Use WSL as the terminal for `ssh`, `curl`, Git, Docker clients, and model API calls.
- Do not run Tailscale simultaneously on both Windows and inside WSL 2.

A separate compute-node mode is documented for cases where WSL itself must have a Tailscale identity and host a model API.

### 5. Test the example machines

```bash
ping -c 3 100.82.103.57
ping -c 3 axonvertex-01
ssh ubuntu@axonvertex-01
curl -fsS http://axonvertex-01:18181/v1/models
curl -fsS http://axonvertex-personal-01:11434/api/tags
```

### 6. Apply the policy

Start with [`config/tailnet-policy.example.hujson`](config/tailnet-policy.example.hujson). Replace example users, local SSH usernames, tags, and ports before saving it in the Tailscale admin console.

### 7. Start the model router

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r router/requirements.txt

cp config/models.example.yaml config/models.yaml

export MODEL_ROUTER_CONFIG="$PWD/config/models.yaml"
export ROUTER_API_KEY="$(openssl rand -hex 32)"
export MODEL_ROUTER_HOST="$(tailscale ip -4 | head -n 1)"

make run
```

The router fails closed when `ROUTER_API_KEY` is missing. It binds to the Tailscale IPv4 address rather than every network interface.

For a persistent Linux service, follow [Linux model-router service installation](docs/12-LINUX-MODEL-ROUTER-SERVICE.md).

From another permitted tailnet device:

```bash
curl -sS http://rentorzos-macbook-pro-2:18180/v1/chat/completions \
  -H "Authorization: Bearer $ROUTER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "routing": {"profile": "security"},
    "messages": [{"role": "user", "content": "Review this incident summary."}],
    "stream": false
  }'
```

## Core operating rule

Tailscale provides the private encrypted path and identity-aware network policy. It does not decide which model should answer a request. The model gateway performs workload routing, health checks, fallback, API authentication, request logging, and model policy enforcement.

## Repository initialization

```bash
git init
git add .
git commit -m "Initial Tailscale multi-compute AI network guide"
git branch -M main

git remote add origin git@github.com:<ORG>/tailscale-multi-compute-ai-network-guide.git
git push -u origin main
```

Keep the repository private if it contains real hostnames, user identities, internal model names, API keys, or access policy details.
