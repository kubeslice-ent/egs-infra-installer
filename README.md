# EGS Infra Installer

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
git clone https://github.com/kubeslice-ent/egs-infra-installer.git
cd egs-infra-installer

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

  # worker_nodes: []                   # Uncomment and configure for multi-node setup
  # Example worker node configuration (for multi-node setups only):
  # worker_nodes:
  #   - name: "worker-1"
  #     ansible_host: "WORKER_PUBLIC_IP"
  #     ansible_user: "REPLACE_SSH_USER"
  #     ansible_become: true
  #     ansible_become_method: "sudo"
  #     ansible_become_user: "root"
  #     private_ip: "WORKER_PRIVATE_IP"
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

- **Single Node**: If you're deploying on a **single node** and running the command from the **same server**, you can use the **same IP address** for both `PUBLIC_IP` and `PRIVATE_IP`. The `worker_nodes` section should remain commented out.
- **Multi-Node**: For multi-node setups, uncomment and configure both `control_plane_nodes` and `worker_nodes` sections with their respective IP addresses.

---

### Step 2.4: Deploy Kubernetes Cluster

```bash
# Make the script executable
chmod +x setup_kubernetes.sh

# Run the installation script with sudo
 ./setup_kubernetes.sh
```

### Step 2.5 Change ownership of the egs-infra-installer working directory

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

### KubeSlice Networking Configuration

**Note**: KubeSlice networking is **disabled by default** in the EGS worker configuration:

```yaml
kubesliceNetworking:
  enabled: false  # Disabled by default
```

If you need inter-cluster networking capabilities, you can enable it by setting `enabled: true` in the worker configuration. However, this is typically not required for EGS GPU sharing functionality.

---

## 4. EGS Prerequisites

> ⚠️ **Critical**: The following steps are MANDATORY prerequisites that must be completed BEFORE installing any EGS components. EGS installation will fail without these prerequisites.

### Step 4.1: Label Cluster Nodes (OPTIONAL)

Nodes in the cluster need to be labeled with `kubeslice.io/node-type=gateway` before EGS installation. This is automatically handled by the installer script, but you can also run it manually:

```bash
# Label nodes with kubeslice.io/node-type=gateway (optional - script handles this)
kubectl get nodes -o name | xargs -I {} kubectl label {} kubeslice.io/node-type=gateway --overwrite

# Verify the labels
kubectl get nodes -l kubeslice.io/node-type=gateway
```

> **Note**: The installer automatically handles node labeling, so this step is optional for manual execution.

### Step 4.2: Generate Cluster Fingerprint (REQUIRED)

Generate the cluster fingerprint required for EGS license generation:

```bash
# Generate cluster fingerprint
kubectl get namespace kube-system -o=jsonpath='{.metadata.creationTimestamp}{.metadata.uid}{"\n"}'
```

Copy the output and save it for the next step.

### Step 4.3: Get EGS License (REQUIRED)

1. **Visit EGS Registration Portal**: Go to [https://avesha.io/egs-registration](https://avesha.io/egs-registration)
2. **Fill out the registration form**:
   - Enter your full name, company name, title/position
   - Provide your work email address
   - Paste the cluster fingerprint from Step 4.2
   - Select your cloud type
   - Agree to terms and conditions
3. **Submit registration** and wait for Avesha to process your request
4. **Receive license file** via email from Avesha

### Step 4.4: Apply EGS License (REQUIRED)

You have two options for applying the EGS license:

**Option 1: Automated Application (Recommended)**
```bash
# Place license file in the designated folder
cp your-egs-license.yaml files/egs-license/egs-license.yaml
```
The installer will automatically detect and apply the license during deployment.

**Option 2: Manual Application**
```bash
# Apply license manually
kubectl apply -f files/egs-license/egs-license.yaml
```

The license file should contain a Kubernetes Secret with the name `egs-license-file` in the `kubeslice-controller` namespace.

> 📖 **For detailed troubleshooting and validation steps**, see the [EGS License Setup Guide](docs/EGS-License-Setup.md)

---

## 5. Instructions to Deploy EGS Apps

### Step 5.1: Deploy EGS Applications

```bash
# Deploy EGS applications
ansible-playbook site.yml -vvvv
```

### Step 5.2: Verify EGS Deployment

```bash
# Check all namespaces
kubectl get namespaces

# Verify EGS component status
kubectl get pods -n gpu-operator
kubectl get pods -n monitoring
kubectl get pods -n kubeslice-controller
kubectl get pods -n kubeslice-system
kubectl get pods -n kt-postgresql

# Verify EGS license
kubectl get secret egs-license-file -n kubeslice-controller
```

**Expected Output:**

```sh
NAMESPACE              NAME                                                          READY   STATUS      RESTARTS      AGE
gpu-operator           gpu-feature-discovery-xkbx7                                   1/1     Running     0             69m
gpu-operator           gpu-operator-669c87dd9-cxpfb                                  1/1     Running     0             69m
gpu-operator           gpu-operator-node-feature-discovery-gc-6f9bcf88fb-sw59w       1/1     Running     0             68m
gpu-operator           gpu-operator-node-feature-discovery-master-57d9fbd8b8-2wlc8   1/1     Running     0             68m
gpu-operator           gpu-operator-node-feature-discovery-worker-mgn25              1/1     Running     0             68m
gpu-operator           nvidia-container-toolkit-daemonset-tm7zp                      1/1     Running     0             68m
gpu-operator           nvidia-cuda-validator-z5cnd                                   0/1     Completed   0             67m
gpu-operator           nvidia-dcgm-exporter-cc62g                                    1/1     Running     0             68m
gpu-operator           nvidia-dcgm-vxrk8                                             1/1     Running     0             68m
gpu-operator           nvidia-device-plugin-daemonset-ckpt2                          1/1     Running     0             68m
gpu-operator           nvidia-operator-validator-ggj7g                               1/1     Running     0             68m
kt-postgresql          kt-postgresql-0                                               1/1     Running     0             69m
kube-system            calico-kube-controllers-588d6df6c9-xmbcz                      1/1     Running     0             69m
kube-system            calico-node-zqglt                                             1/1     Running     0             69m
kube-system            coredns-5c54f84c97-8xzb4                                      1/1     Running     0             69m
kube-system            dns-autoscaler-676999957f-chz6k                               1/1     Running     0             69m
kube-system            etcd-master-1                                                 1/1     Running     0             69m
kube-system            haproxy-master-1                                              1/1     Running     0             69m
kube-system            kube-apiserver-master-1                                       1/1     Running     0             69m
kube-system            kube-controller-manager-master-1                              1/1     Running     0             68m
kube-system            kube-proxy-qt5k4                                              1/1     Running     0             69m
kube-system            kube-scheduler-master-1                                       1/1     Running     0             69m
kube-system            metrics-server-5dff58bc89-9m2rb                               1/1     Running     0             69m
kube-system            nodelocaldns-z7lhs                                            1/1     Running     0             69m
kubeslice-controller   egs-core-apis-56b6d94d58-ggphq                                1/1     Running     0             68m
kubeslice-controller   egs-gpr-manager-688ddfcc5d-kdhwv                              1/1     Running     0             68m
kubeslice-controller   egs-inventory-controller-manager-79db45b5b6-nfdfq             1/1     Running     0             68m
kubeslice-controller   egs-queue-manager-7ffcb656c4-tqmg2                            1/1     Running     0             68m
kubeslice-controller   kubeslice-api-gw-6fbd6c489c-6lbm4                             1/1     Running     0             69m
kubeslice-controller   kubeslice-controller-manager-559f795b54-8l62f                 2/2     Running     0             69m
kubeslice-controller   kubeslice-ui-7c86cf87b8-gxz6h                                 1/1     Running     0             69m
kubeslice-controller   kubeslice-ui-proxy-5fd4fff495-zbrlx                           1/1     Running     0             69m
kubeslice-controller   kubeslice-ui-v2-6ff4fb6444-xkdxx                              1/1     Running     0             69m
kubeslice-controller   kubetally-pricing-service-59565c8cfc-d4rt2                    1/1     Running     0             69m
kubeslice-controller   kubetally-report-d4f8b5fcd-q8ktq                              1/1     Running     0             69m
kubeslice-system       aiops-operator-9f999b66b-gk4bk                                2/2     Running     0             69m
kubeslice-system       egs-agent-7d4f6dc6d-6r4wp                                     1/1     Running     0             69m
kubeslice-system       kubeslice-operator-97858cd44-5flcz                            2/2     Running     0             69m
local-path-storage     local-path-provisioner-7d4b6f8ccf-wmspb                       1/1     Running     0             69m
monitoring             alertmanager-prometheus-kube-prometheus-alertmanager-0        2/2     Running     0             69m
monitoring             prometheus-grafana-67dc5c9fc9-jtlnf                           3/3     Running     0             68m
monitoring             prometheus-kube-prometheus-operator-775d58dc6b-gfjlg          1/1     Running     0             69m
monitoring             prometheus-kube-state-metrics-856b96f64d-rgz52                1/1     Running     0             68m
monitoring             prometheus-prometheus-kube-prometheus-prometheus-0            2/2     Running     0             69m
monitoring             prometheus-prometheus-node-exporter-h5dgr                     1/1     Running     0             69m
```

**Key Components Status:**
- ✅ **GPU Operator**: Complete NVIDIA GPU stack running (device plugin, DCGM, container toolkit, validators)
- ✅ **PostgreSQL**: Database running in `kt-postgresql` namespace
- ✅ **EGS Controller**: All management components running in `kubeslice-controller`
- ✅ **EGS Worker**: Agent and operator running in `kubeslice-system`
- ✅ **Monitoring**: Complete Prometheus stack running in `monitoring` namespace
- ✅ **Kubernetes Core**: All core system components running in `kube-system`
- ✅ **Storage**: Local path provisioner running in `local-path-storage`

### Step 5.3: EGS Management UI Access

After successful EGS deployment, you can access the management UI and retrieve access tokens for project management.

#### a) Get EGS UI Access URL

The EGS UI access method depends on your service configuration:

```bash
# Check EGS UI service configuration
kubectl get svc kubeslice-ui-proxy -n kubeslice-controller

# For LoadBalancer service type
kubectl get svc kubeslice-ui-proxy -n kubeslice-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || \
kubectl get svc kubeslice-ui-proxy -n kubeslice-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null

# For NodePort service type
# Try ExternalIP first, fallback to InternalIP if not available
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null | head -n1)
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null | head -n1)
fi
NODE_PORT=$(kubectl get svc kubeslice-ui-proxy -n kubeslice-controller -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
echo "https://$NODE_IP:$NODE_PORT"

# For ClusterIP service type (port-forward required)
kubectl port-forward -n kubeslice-controller svc/kubeslice-ui-proxy 8080:443
echo "https://localhost:8080"
```

#### b) Get EGS Access Token

```bash
# Get access token for EGS UI
kubectl get secret kubeslice-rbac-rw-admin -o jsonpath="{.data.token}" -n kubeslice-avesha --kubeconfig output/kubeconfig --context kubernetes-admin@cluster.local 2>/dev/null | base64 --decode
```

#### c) Access EGS Management UI

1. **Open your browser** and navigate to the EGS UI URL from step a)
2. **Enter the access token** from step b) when prompted for "Service Account Token"
3. **Start managing** your EGS clusters, projects, and GPU resources

---

## 6. Multiple Worker Cluster Registration

For production deployments, you may need to register multiple worker clusters with your EGS controller. There are two approaches to register additional worker clusters:

### Option 1: Using EGS Installation Script (Recommended)

For comprehensive multi-cluster setup with detailed configuration options, use the official EGS installation script:

📖 **[EGS Installation Guide](https://github.com/kubeslice-ent/egs-installation)**

The EGS installation script provides:
- **Complete multi-cluster configuration** with detailed examples
- **Cluster registration YAML** for multiple worker clusters
- **Telemetry endpoint configuration** for each cluster
- **Geographic distribution** settings (cloud provider, region)
- **Prometheus endpoint accessibility** guidance for multi-cluster setups
- **Preflight checks** and troubleshooting tools

**Key Features:**
- Support for workers in different Kubernetes clusters
- LoadBalancer/NodePort service configuration for cross-cluster access
- Comprehensive cluster registration examples
- Telemetry and monitoring setup for each cluster

### Option 2: Using EGS UI (Alternative)

For simpler cluster registration, you can use the EGS management UI:

📖 **[Register Clusters via UI](https://docs.avesha.io/documentation/enterprise-egs/1.15.0/admin-operations/register-clusters/)**

The UI approach provides:
- **Interactive cluster registration** through the web interface
- **Simplified configuration** without YAML files
- **Real-time status monitoring** of cluster registration
- **Visual cluster management** and monitoring

**When to Use Each Approach:**
- **EGS Installation Script**: For complex multi-cluster setups, automated deployments, or when you need detailed configuration control
- **EGS UI**: For simple cluster additions, quick setup, or when you prefer a graphical interface

---

## Documentation Links

- **[User Input Configuration Guide](docs/USER_INPUT_CONFIGURATION.md)** - Complete user_input.yml guide
- **[User Input Reference](docs/USER_INPUT_REFERENCE.md)** - All configuration options
- **[Kubernetes Configuration](docs/KUBERNETES_CONFIGURATION.md)** - Cluster setup details
- **[Kubernetes Firewall Configuration](docs/KUBERNETES_FIREWALL.md)** - Network and firewall setup
- **[NVIDIA Container Runtime Configuration](docs/NVIDIA_CONTAINER_RUNTIME.md)** - GPU runtime setup
- **[EGS License Setup](docs/EGS-License-Setup.md)** - EGS license configuration guide
- **[Retry Mechanism](docs/RETRY_MECHANISM.md)** - Retry mechanism configuration and troubleshooting

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
   - If license file is empty, complete registration at [https://avesha.io/egs-registration](https://avesha.io/egs-registration)
   - Apply license manually: `kubectl apply -f files/egs-license/egs-license.yaml`

4. **GPU Support Issues**
   - Verify NVIDIA drivers are installed on nodes
   - Check `nvidia_runtime.enabled` is set to `true`
   - Review GPU operator pod status

5. **"EGS License is required before proceeding" Error**
   - This error occurs when the license file is empty or the license secret doesn't exist
   - **Solution 1**: Complete registration at [https://avesha.io/egs-registration](https://avesha.io/egs-registration) and download license
   - **Solution 2**: Apply existing license manually: `kubectl apply -f files/egs-license/egs-license.yaml`
   - **Verify**: Check secret exists: `kubectl get secret egs-license-file -n kubeslice-controller`
   - **Re-run**: Execute the installation again after applying license


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

For support, questions, or contributions to the EGS Infra Installer:

- **Documentation**: Check the `docs/` folder for detailed guides
- **Issues**: Report issues on the GitHub repository
- **License**: See the EGS license setup guide for licensing information

---

## License

This project is part of the Avesha EGS (Elastic GPU Service) ecosystem. Please refer to the EGS license terms and conditions for usage rights and restrictions.
