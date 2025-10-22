# Systemd Limits Configuration for GPU Support

This document explains how to configure systemd limits to prevent "too many open files" errors when running GPU device plugins in Kubernetes.

## Problem

GPU device plugins (like NVIDIA GPU Operator) often encounter "too many open files" errors because they need to access many GPU devices and files simultaneously. The default systemd limits are insufficient for these workloads.

## Solution

We provide two approaches to configure systemd limits:

1. **Automatic via EGS Installer** (Recommended)
2. **Manual Configuration**

## Approach 1: Automatic Configuration (Recommended)

The EGS installer automatically configures systemd limits as part of the deployment process.

### Configuration

The systemd limits are configured in `group_vars/all/systemd_limits.yml`:

```yaml
# Systemd limits configuration
systemd_limits:
  # File descriptor limits
  nofile: 65536
  # Process limits
  nproc: 32768
  # Memory limits (unlimited for GPU workloads)
  memlock: -1
  # Additional limits for GPU workloads
  stack: 8192

# Enable systemd limits configuration
configure_systemd_limits: true

# Container runtime to configure (containerd or docker)
container_runtime: "{{ 'containerd' if containerd_enabled | default(true) else 'docker' }}"
```

### Execution Order

The systemd limits configuration runs early in the deployment process:

```yaml
execution_order:
  # Base Applications
  - label_nodes_gateway            # Label all nodes with kubeslice.io/node-type=gateway
  - configure_systemd_limits       # Configure systemd limits for GPU device plugins
  - gpu_operator_chart
  # ... rest of deployment
```

### What It Does

1. **Creates systemd override directories** for kubelet and container runtime
2. **Configures limits** for:
   - `NOFILE`: 65536 (file descriptors)
   - `NPROC`: 32768 (processes)
   - `MEMLOCK`: -1 (unlimited memory locking)
   - `STACK`: 8192 (stack size)
3. **Restarts services** to apply the new limits
4. **Verifies** that limits are applied correctly

## Approach 2: Manual Configuration

If you prefer to configure systemd limits manually, you can use the provided script or configure them directly.

### Using the Script

```bash
# Run the systemd limits configuration script
sudo bash files/configure-systemd-limits.sh
```

### Manual Configuration

#### For Kubelet

```bash
# Create override directory
sudo mkdir -p /etc/systemd/system/kubelet.service.d

# Create override file
sudo tee /etc/systemd/system/kubelet.service.d/limits.conf > /dev/null << EOF
[Service]
LimitNOFILE=65536
LimitNPROC=32768
LimitMEMLOCK=-1
LimitSTACK=8192
EOF

# Reload systemd and restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

#### For Containerd

```bash
# Create override directory
sudo mkdir -p /etc/systemd/system/containerd.service.d

# Create override file
sudo tee /etc/systemd/system/containerd.service.d/limits.conf > /dev/null << EOF
[Service]
LimitNOFILE=65536
LimitNPROC=32768
LimitMEMLOCK=-1
LimitSTACK=8192
EOF

# Reload systemd and restart containerd
sudo systemctl daemon-reload
sudo systemctl restart containerd
```

#### For Docker (if using Docker instead of containerd)

```bash
# Create override directory
sudo mkdir -p /etc/systemd/system/docker.service.d

# Create override file
sudo tee /etc/systemd/system/docker.service.d/limits.conf > /dev/null << EOF
[Service]
LimitNOFILE=65536
LimitNPROC=32768
LimitMEMLOCK=-1
LimitSTACK=8192
EOF

# Reload systemd and restart docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Verification

### Check Applied Limits

```bash
# Check kubelet limits
sudo systemctl show kubelet --property=LimitNOFILE --value

# Check containerd limits
sudo systemctl show containerd --property=LimitNOFILE --value

# Check docker limits (if using docker)
sudo systemctl show docker --property=LimitNOFILE --value
```

### Verify in Running Containers

```bash
# Check limits in a running pod
kubectl exec -it <gpu-pod> -- cat /proc/1/limits

# Check current process limits
ulimit -n
```

## Troubleshooting

### Common Issues

1. **Service won't restart after configuration**
   ```bash
   # Check systemd status
   sudo systemctl status kubelet
   sudo systemctl status containerd
   
   # Check for configuration errors
   sudo systemd-analyze verify /etc/systemd/system/kubelet.service
   ```

2. **Limits not applied**
   ```bash
   # Verify override file exists and has correct content
   sudo cat /etc/systemd/system/kubelet.service.d/limits.conf
   
   # Reload systemd daemon
   sudo systemctl daemon-reload
   ```

3. **GPU device plugin still fails**
   ```bash
   # Check pod logs
   kubectl logs -n gpu-operator <device-plugin-pod>
   
   # Check if limits are inherited by containers
   kubectl exec -it <gpu-pod> -- cat /proc/1/limits
   ```

### Debugging Commands

```bash
# Check all systemd limits for a service
sudo systemctl show kubelet | grep Limit

# Check current system limits
cat /proc/sys/fs/file-max
cat /proc/sys/kernel/pid_max

# Check process limits
ps aux | grep kubelet
cat /proc/$(pgrep kubelet)/limits
```

## Customization

### Adjusting Limits

You can customize the limits by modifying `group_vars/all/systemd_limits.yml`:

```yaml
systemd_limits:
  nofile: 131072    # Increase file descriptor limit
  nproc: 65536      # Increase process limit
  memlock: -1       # Keep unlimited
  stack: 16384      # Increase stack size
```

### Disabling Automatic Configuration

To disable automatic systemd limits configuration:

```yaml
# In group_vars/all/systemd_limits.yml
configure_systemd_limits: false
```

Or remove `configure_systemd_limits` from the execution order in `user_input.yml`.

## Best Practices

1. **Configure limits before GPU operator installation** - This prevents issues during initial deployment
2. **Use the automatic configuration** - It handles both kubelet and container runtime
3. **Verify limits after configuration** - Ensure they are applied correctly
4. **Monitor GPU device plugin logs** - Watch for any remaining file descriptor issues
5. **Test with your specific GPU workloads** - Different workloads may have different requirements

## References

- [Kubernetes GPU Support](https://kubernetes.io/docs/tasks/manage-gpus/scheduling-gpus/)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/)
- [Systemd Resource Limits](https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html)
