# REPO_CONTEXT: egs-infra-installer

## Purpose
Ansible-based installer for provisioning the underlying infrastructure required by EGS — bare-metal or VM Kubernetes clusters, GPU driver installation, NVIDIA tooling (DCGM, device plugin), networking prerequisites, and storage configuration. Wraps Kubespray for cluster bootstrapping.

## Role in EGS System
The lowest-level infrastructure layer. Runs before `egs-installation` (which installs EGS software on top of an existing cluster). Targets scenarios where the customer does not have a pre-existing Kubernetes cluster.

## Tech Stack
- **Language:** Python / Ansible
- **Cluster provisioner:** Kubespray (vendored as a submodule)
- **Target OS:** Ubuntu 22.04 LTS (primary), RHEL 8/9

## Key Components
```
site.yml                - Main Ansible playbook entry point
setup_kubernetes.sh     - Shell wrapper to invoke Ansible with correct inventory
kubernetes.yml          - Kubernetes cluster configuration playbook
roles/
  gpu-drivers/          - NVIDIA driver, CUDA, container toolkit installation
  dcgm/                 - DCGM DaemonSet deployment
  storage/              - Persistent volume provisioner setup
  networking/           - CNI plugin configuration
inventory/              - Host inventory templates
group_vars/             - Cluster-wide variable defaults
user_input.yml          - User-facing configuration (node IPs, GPU model, etc.)
kubespray/              - Vendored Kubespray for K8s cluster bootstrap
requirements.txt        - Python deps (ansible-core, netaddr, etc.)
requirements.yml        - Ansible Galaxy collections
```

## Usage
```bash
pip install -r requirements.txt
ansible-galaxy install -r requirements.yml
# Edit user_input.yml with node IPs and GPU config
bash setup_kubernetes.sh
```

## Dependencies & Integrations
- **egs-installation** — runs after this installer; installs EGS Helm charts on the provisioned cluster
- **NVIDIA GPU nodes** — target nodes must have compatible NVIDIA GPUs
- **Kubespray** — handles kubeadm-based cluster bootstrapping
