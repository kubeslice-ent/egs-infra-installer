# Avesha Apps Installer

Ansible-based installer for Avesha EGS (Elastic GPU Service) components and Kubernetes cluster deployment.

## Table of Contents

1. [Prerequisites for Deploying K8s Cluster](#1-prerequisites-for-deploying-k8s-cluster) *(~2–3 mins)*  
2. [Installation Steps for Deploying K8s Cluster](#2-installation-steps-for-deploying-k8s-cluster) *(~15–20 mins)*  
3. [Prerequisites for EGS Installation](#3-prerequisites-for-egs-installation) *(~2 mins)*  
4. [EGS License Setup](#4-egs-license-setup) *(~5 mins)*  
5. [Instructions to Deploy EGS Apps](#5-instructions-to-deploy-egs-apps) *(~10-15 mins)*  
6. [Execution Order Control](#execution-order-control) *(optional) (~1 min)*  
7. [Destroying the Kubernetes Cluster](#destroying-the-kubernetes-cluster) *(~5 mins)*  
8. [Documentation Links](#documentation-links)  
9. [Troubleshooting](#troubleshooting)

---

## 1. Prerequisites for Deploying K8s Cluster

### System Requirements

- **Operating System**: Ubuntu 20.04 LTS or later
- **Minimum RAM**: 8GB per node (16GB recommended)
- **CPU**: 4 cores per node (8 cores recommended)
- **Storage**: 50GB free disk space per node
- **Network**: All nodes must be able to communicate with each other

### Required Software

- **Ansible**: 2.9+ (will be installed automatically)
- **Python**: 3.6+ (will be installed automatically)
- **Git**: For cloning the repository

### Network Requirements

- **Ports**: 6443, 2379-2380, 10250-10252, 10255, 30000-32767
- **Firewall**: Must allow communication between all nodes
- **DNS**: All nodes should be able to resolve each other's hostnames

---

## 2. Installation Steps for Deploying K8s Cluster

### Step 2.1: Clone Repository and Setup Environment

```bash
# Clone the repository
git clone https://github.com/smart-scaler/avesha-apps-installer.git
cd avesha-apps-installer

# Install Python3 
sudo apt update
sudo apt-get install python3-venv python3-full -y

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
chmod +x files/install-requirements.sh
./files/install-requirements.sh

# Install Ansible collections
LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ansible-galaxy collection install -r requirements.yml --force
```

### Step 2.2: Generate SSH Keys

```bash
# Generate SSH key for cluster access
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s_rsa -N ""

# Copy SSH key to each node (repeat for all nodes)
ssh-copy-id -i ~/.ssh/k8s_rsa.pub user@node-ip
```

### Step 2.3: Configure user_input.yml

Edit `user_input.yml` with your cluster configuration:

This section defines the settings required to enable and configure a Kubernetes cluster deployment using Ansible.

#### 🔧 **Note**: Replace placeholders with actual values before running the playbook.

```yaml
kubernetes_deployment:
  enabled: true  # Enable Kubernetes deployment via Ansible

  api_server:
    host: "PUBLIC_IP"        # Public IP of Kubernetes API server
    port: 6443               # Default secure port
    secure: true             # Use HTTPS (recommended)

  ssh_key_path: "/absolute/path/to/.ssh/k8s_rsa"     # SSH private key path
  default_ansible_user: "REPLACE_SSH_USER"           # SSH user (e.g., ubuntu, ec2-user)
  ansible_sudo_pass: ""                              # Optional: sudo password

  control_plane_nodes:
    - name: "master-1"
      ansible_host: "PUBLIC_IP"       # Public IP for SSH
      ansible_user: "REPLACE_SSH_USER"
      ansible_become: true
      ansible_become_method: "sudo"
      ansible_become_user: "root"
      private_ip: "PRIVATE_IP"        # Internal/private IP
```

#### ⚙️ For Single Node: Quick Configuration Update (Command-Line Shortcut)

You can quickly update your `user_input.yml` by replacing only the **values** in this command based on your environment.
**Keep the placeholder keywords (`PUBLIC_IP`, `PRIVATE_IP`, etc.) on the left side exactly as-is.**

> ⚠️ **Warning:**
> Replace **only** the values on the right-hand side (`192.168.1.100`, `root`, etc.) with your actual environment details.
> **Do not modify** the placeholder keywords (`PUBLIC_IP`, `PRIVATE_IP`, etc.) — they are required for matching.

#### 🧪 Example Command

```bash
sed -i \
  -e 's|PUBLIC_IP|172.235.157.18|g' \
  -e 's|PRIVATE_IP|172.235.157.18|g' \
  -e 's|REPLACE_SSH_USER|root|g' \
  -e 's|/absolute/path/to/.ssh/k8s_rsa|/root/.ssh/k8s_rsa|g' \
  -e '/kubernetes_deployment:/,/^[[:space:]]*[^[:space:]]*enabled:/ s/enabled: false/enabled: true/' \
  user_input.yml
```

> ✅ This command will:
>
> * Replace `PUBLIC_IP` and `PRIVATE_IP` placeholders with your node IP
> * Set the correct SSH user and key path
> * Enable Kubernetes deployment by updating `enabled: false` → `enabled: true`

#### 📌 Note:

If you're deploying on a **single node** and running the command from the **same server**, you can use the **same IP address** for both `PUBLIC_IP` and `PRIVATE_IP`.

---

### Step 2.4: Deploy Kubernetes Cluster

```bash
# Make the script executable
chmod +x setup_kubernetes.sh

# Run the installation script with sudo
 ./setup_kubernetes.sh
```

### Step 2.5 Change ownership of the avesha-apps-installer working directory

```bash
sudo chown $(whoami):$(whoami) -R .

# Set the KUBECONFIG environment variable
export KUBECONFIG=output/kubeconfig

# Verify cluster access and node status
kubectl get nodes
```

### Step 2.6: Verify Installation

```bash
# Check cluster status
kubectl get nodes
kubectl cluster-info

# Verify all system pods are running
kubectl get pods --all-namespaces
```

---

## 3. Prerequisites for EGS Installation

### Cluster Requirements

- **Kubernetes cluster must be running and accessible**
- **kubectl configured with proper kubeconfig**
- **Helm v3.15.0+ installed**

### Required Environment Variables

No additional environment variables are required for EGS installation.

### Configure user_input.yml

**Important**: Set `kubernetes_deployment.enabled` to `false` in `user_input.yml` before running EGS installation:

```yaml
kubernetes_deployment:
  enabled: false  # Must be false for apps-only deployment
```

You can also use this command to automatically set it:

```bash
sed -i \
   -e '/kubernetes_deployment:/,/^[[:space:]]*[^[:space:]]*enabled:/ s/enabled: true/enabled: false/' \
  user_input.yml
```

---

## 4. EGS License Setup

> ⚠️ **Important**: License setup must be completed BEFORE installing any EGS components. The cluster fingerprint generation and license application are prerequisites for all EGS installations.

### Step 4.0: Label Cluster Nodes

Before setting up the EGS license, all nodes in the cluster must be labeled with `kubeslice.io/node-type=gateway`. This is automatically handled by the installer, but you can also run it manually:

```bash
# Label all nodes with kubeslice.io/node-type=gateway
kubectl get nodes -o name | xargs -I {} kubectl label {} kubeslice.io/node-type=gateway --overwrite

# Verify the labels
kubectl get nodes -l kubeslice.io/node-type=gateway
```

### Step 4.1: Generate Cluster Fingerprint

Generate the cluster fingerprint required for EGS license generation:

```bash
# Generate cluster fingerprint
kubectl get namespace kube-system -o=jsonpath='{.metadata.creationTimestamp}{.metadata.uid}{"\n"}'
```

Copy the output and save it for the next step.

### Step 4.2: Get EGS License

1. **Visit EGS Registration Portal**: Go to [https://avesha.io/egs-registration](https://avesha.io/egs-registration)
2. **Fill out the registration form**:
   - Enter your full name, company name, title/position
   - Provide your work email address
   - Paste the cluster fingerprint from Step 4.1
   - Select your cloud type
   - Agree to terms and conditions
3. **Submit registration** and wait for Avesha to process your request
4. **Receive license file** via email from Avesha

### Step 4.3: Place License File

Place your downloaded license file in the designated folder:

```bash
# Copy your license file to the required location
cp your-egs-license.yaml files/egs-license/egs-license.yaml
```

The license file should contain a Kubernetes Secret with the name `egs-license-file` in the `kubeslice-controller` namespace.

### Step 4.4: License Validation

The installer will automatically validate the license during deployment. The validation includes:
- ✅ License file exists and is valid
- ✅ License secret is created in the cluster
- ✅ All required fields are present
- ✅ License has not expired
- ✅ License status is valid

---

## 5. Instructions to Deploy EGS Apps

### Step 5.1: Verify Prerequisites

```bash
# Verify cluster access
kubectl get nodes
kubectl cluster-info

# Verify required tools
kubectl version --client
helm version

# Verify cluster is accessible
kubectl get nodes
```

### Step 5.2: Deploy EGS Applications

```bash
# Deploy EGS applications
ansible-playbook site.yml -vvvv
```

### Step 5.3: Verify EGS Deployment

```bash
# Check all namespaces
kubectl get namespaces

# Expected namespaces:
# - gpu-operator
# - monitoring
# - kubeslice-controller
# - kubeslice-system

# Verify EGS component status
kubectl get pods -n gpu-operator
kubectl get pods -n monitoring
kubectl get pods -n kubeslice-controller
kubectl get pods -n kubeslice-system

# Verify EGS license
kubectl get secret egs-license-file -n kubeslice-controller
kubectl describe secret egs-license-file -n kubeslice-controller
```

Expected output:

```sh
## Infrastructure Components
# GPU Operator
gpu-operator-666bbffcd-drrwk                                  1/1     Running   0          96m
gpu-operator-node-feature-discovery-gc-7c7f68d5f4-dz7jk       1/1     Running   0          96m
gpu-operator-node-feature-discovery-master-58588c6967-8pjhc   1/1     Running   0          96m
gpu-operator-node-feature-discovery-worker-xkbk2              1/1     Running   0          96m

# Monitoring
alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0          98m
prometheus-grafana-67dc5c9fc9-5jzhh                      3/3     Running   0          98m
prometheus-kube-prometheus-operator-775d58dc6b-bgglg     1/1     Running   0          98m
prometheus-kube-state-metrics-856b96f64d-7st5q           1/1     Running   0          98m
prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0          98m
prometheus-prometheus-node-exporter-nm8zl                1/1     Running   0          98m
pushgateway-65497548cc-6v7sv                             1/1     Running   0          97m

# EGS Controller
egs-controller-7c6fc8d849-9cchf                           1/1     Running   0          98m
egs-ui-6465596cb9-4j54h                                   1/1     Running   0          98m

# EGS Worker
egs-worker-dc4dd6d79-gzxpq                                1/1     Running   0          98m
```

### Step 5.4: Accessing EGS UI and Monitoring

After deploying the EGS application stack, you can access the management interfaces:

#### EGS UI Access

```bash
# Get EGS UI service details
kubectl get svc -n kubeslice-controller

# Access EGS UI (replace with your node IP)
kubectl port-forward -n kubeslice-controller svc/kubeslice-ui-proxy 8080:443
```

Then access the EGS UI at: [https://localhost:8080](https://localhost:8080)

#### Monitoring Access

```bash
# Get monitoring service details
kubectl get svc -n monitoring

# Access Grafana (replace with your node IP)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access Prometheus (replace with your node IP)
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

- **Grafana Dashboard**: [http://localhost:3000](http://localhost:3000) (admin/prom-operator)
- **Prometheus UI**: [http://localhost:9090](http://localhost:9090)


---

## Documentation Links

- **[User Input Configuration Guide](docs/USER_INPUT_CONFIGURATION.md)** - Complete user_input.yml guide
- **[User Input Reference](docs/USER_INPUT_REFERENCE.md)** - All configuration options
- **[Kubernetes Configuration](docs/KUBERNETES_CONFIGURATION.md)** - Cluster setup details
- **[Kubernetes Firewall Configuration](docs/KUBERNETES_FIREWALL.md)** - Network and firewall setup
- **[NVIDIA Container Runtime Configuration](docs/NVIDIA_CONTAINER_RUNTIME.md)** - GPU runtime setup
- **[EGS License Setup](docs/EGS-License-Setup.md)** - EGS license configuration guide

---

## Troubleshooting

### Common Issues

1. **Cluster Deployment Failed**
   - Check system requirements are met
   - Verify network connectivity between nodes
   - Review firewall settings

2. **EGS Deployment Failed**
   - Ensure `kubernetes_deployment.enabled` is set to `false`
   - Verify all environment variables are set
   - Check cluster accessibility with `kubectl get nodes`
   - Ensure EGS license is valid and applied

3. **EGS License Issues**
   - Verify license file exists in `files/egs-license/egs-license.yaml`
   - Check license secret exists: `kubectl get secret egs-license-file -n kubeslice-controller`
   - Verify license has not expired
   - Ensure license contains all required fields

4. **GPU Support Issues**
   - Verify NVIDIA drivers are installed on nodes
   - Check `nvidia_runtime.enabled` is set to `true`
   - Review GPU operator pod status


### Debug Commands

```bash
# Check all pods status
kubectl get pods --all-namespaces

# Check EGS component logs
kubectl logs -n kubeslice-controller deployment/egs-controller
kubectl logs -n kubeslice-controller deployment/egs-ui
kubectl logs -n kubeslice-system deployment/egs-worker

# Check infrastructure component logs
kubectl logs -n gpu-operator deployment/gpu-operator
kubectl logs -n monitoring deployment/prometheus-grafana
kubectl logs -n monitoring deployment/prometheus-kube-prometheus-operator

# Check EGS license status
kubectl get secret egs-license-file -n kubeslice-controller -o yaml
kubectl describe secret egs-license-file -n kubeslice-controller

# Check service status
kubectl get svc --all-namespaces

# Check ingress status
kubectl get ingress --all-namespaces

# Check persistent volumes
kubectl get pv
kubectl get pvc --all-namespaces

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check GPU resources
kubectl get nodes -o json | jq '.items[].status.allocatable | with_entries(select(.key | contains("nvidia")))'

# Check events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

For additional support, please refer to the detailed documentation in the `docs/` folder or create an issue in the repository.

---

## Execution Order Control

The deployment process follows a specific execution order defined in `user_input.yml`. You can control which components to execute by modifying the execution order or using `--extra-vars` with Ansible.

### Available Components

#### Core Infrastructure (Optional)
- `metallb_chart` - MetalLB load balancer installation
- `metallb_l2_config` - L2 configuration for MetalLB
- `metallb_ip_pool` - IP pool configuration for MetalLB
- `nginx_ingress_config` - NGINX ingress controller configuration
- `nginx_ingress_chart` - NGINX ingress controller installation
- `cert_manager` - Cert-manager for certificate management (required for AMD GPU operator)

#### Base Components
- `gpu_operator_chart` - NVIDIA GPU operator installation
- `prometheus_stack` - Prometheus monitoring stack
- `pushgateway_manifest` - Prometheus Pushgateway

#### AMD GPU Support (Alternative to NVIDIA)
- `amd_gpu_operator_chart` - AMD GPU operator for AMD Instinct GPU accelerators
- `amd_gpu_deviceconfig_manifest` - AMD GPU device configuration and settings

#### EGS Installation
- `label_nodes_gateway` - Label all nodes with kubeslice.io/node-type=gateway (REQUIRED FIRST)
- `validate_and_apply_egs_license` - Validate and apply EGS license (REQUIRED SECOND)
- `kubeslice_controller_egs_chart` - KubeSlice EGS controller for multi-cluster management
- `kubeslice_ui_egs_chart` - KubeSlice EGS management UI interface
- `kubeslice_worker_egs_chart` - KubeSlice EGS worker for cluster management
- `egs_project_manifest` - EGS project configuration
- `egs_cluster_registration_worker_1` - Register worker cluster
- `fetch_worker_secret_worker_1` - Fetch worker authentication secrets
- `kubeslice_worker_egs_worker_1` - Install EGS worker components


### Controlling Execution

To execute specific components, use the `execution_order` variable with a list of components:

```bash
# Execute only GPU operator and monitoring stack
ansible-playbook site.yml \
  --extra-vars "execution_order=['gpu_operator_chart','prometheus_stack']" \
  -vv

# Execute node labeling and EGS license validation
ansible-playbook site.yml \
  --extra-vars "execution_order=['label_nodes_gateway','validate_and_apply_egs_license']" \
  -vv

# Execute EGS installation with node labeling and license validation
ansible-playbook site.yml \
  --extra-vars "execution_order=['label_nodes_gateway','validate_and_apply_egs_license','kubeslice_controller_egs_chart','kubeslice_ui_egs_chart']" \
  -vv

# Execute AMD GPU operator setup (alternative to NVIDIA)
ansible-playbook site.yml \
  --extra-vars "execution_order=['cert_manager','amd_gpu_operator_chart','amd_gpu_deviceconfig_manifest']" \
  -vv

# Execute complete EGS installation (node labeling first, then license validation, then components)
ansible-playbook site.yml \
  --extra-vars "execution_order=['label_nodes_gateway','validate_and_apply_egs_license','kubeslice_controller_egs_chart','kubeslice_ui_egs_chart','kubeslice_worker_egs_chart','egs_project_manifest','egs_cluster_registration_worker_1','fetch_worker_secret_worker_1']" \
  -vv

# Execute only NGINX ingress setup
ansible-playbook site.yml \
  --extra-vars "execution_order=['nginx_ingress_config','nginx_ingress_chart']" \
  -vv
```

> 💡 **Tip**: Components are executed in the order they appear in the list. Make sure to list dependent components in the correct order.

---

## Destroying the Kubernetes Cluster

To completely remove the Kubernetes cluster and clean up all resources, run the following command from the root directory:

```bash
ansible-playbook kubespray/reset.yml -i inventory/kubespray/inventory.ini
```

This command will:
- Remove all Kubernetes components from the nodes
- Clean up all cluster-related configurations
- Reset the nodes to their pre-Kubernetes state

> ⚠️ **Warning**: This action is irreversible. Make sure to backup any important data before proceeding with the cluster destruction.

---

## Support and Contributing

For support, questions, or contributions to the Avesha Apps Installer:

- **Documentation**: Check the `docs/` folder for detailed guides
- **Issues**: Report issues on the GitHub repository
- **License**: See the EGS license setup guide for licensing information

---

## License

This project is part of the Avesha EGS (Elastic GPU Service) ecosystem. Please refer to the EGS license terms and conditions for usage rights and restrictions.
