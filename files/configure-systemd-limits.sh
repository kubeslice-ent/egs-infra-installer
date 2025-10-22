#!/bin/bash

# Configure systemd limits for kubelet and container runtime
# This prevents "too many open files" errors with GPU device plugins

set -e

# Configuration
NOFILE_LIMIT=65536
NPROC_LIMIT=32768
MEMLOCK_LIMIT=-1
STACK_LIMIT=8192

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "SUCCESS") echo -e "${GREEN}✓${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}⚠${NC} $message" ;;
        "ERROR") echo -e "${RED}✗${NC} $message" ;;
        "INFO") echo -e "${BLUE}ℹ${NC} $message" ;;
    esac
}

# Function to create systemd override
create_systemd_override() {
    local service_name=$1
    local override_dir="/etc/systemd/system/${service_name}.service.d"
    local override_file="${override_dir}/limits.conf"
    
    print_status "INFO" "Configuring systemd limits for $service_name"
    
    # Create override directory
    sudo mkdir -p "$override_dir"
    
    # Create override file
    sudo tee "$override_file" > /dev/null << EOF
[Service]
LimitNOFILE=$NOFILE_LIMIT
LimitNPROC=$NPROC_LIMIT
LimitMEMLOCK=$MEMLOCK_LIMIT
LimitSTACK=$STACK_LIMIT
EOF
    
    print_status "SUCCESS" "Created systemd override for $service_name"
}

# Function to restart service
restart_service() {
    local service_name=$1
    
    print_status "INFO" "Restarting $service_name service"
    
    if sudo systemctl is-active --quiet "$service_name"; then
        sudo systemctl restart "$service_name"
        print_status "SUCCESS" "$service_name service restarted"
    else
        print_status "WARNING" "$service_name service is not active, skipping restart"
    fi
}

# Function to verify limits
verify_limits() {
    local service_name=$1
    
    print_status "INFO" "Verifying limits for $service_name"
    
    local nofile_limit=$(sudo systemctl show "$service_name" --property=LimitNOFILE --value 2>/dev/null || echo "unknown")
    local nproc_limit=$(sudo systemctl show "$service_name" --property=LimitNPROC --value 2>/dev/null || echo "unknown")
    
    echo "  NOFILE limit: $nofile_limit"
    echo "  NPROC limit: $nproc_limit"
}

# Main execution
main() {
    echo "=========================================="
    echo "Systemd Limits Configuration for GPU Support"
    echo "=========================================="
    echo "Configuration:"
    echo "  NOFILE limit: $NOFILE_LIMIT"
    echo "  NPROC limit: $NPROC_LIMIT"
    echo "  MEMLOCK limit: $MEMLOCK_LIMIT"
    echo "  STACK limit: $STACK_LIMIT"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_status "WARNING" "Running as root. Consider running as regular user with sudo."
    fi
    
    # Detect container runtime
    local container_runtime=""
    if systemctl is-active --quiet containerd; then
        container_runtime="containerd"
    elif systemctl is-active --quiet docker; then
        container_runtime="docker"
    else
        print_status "WARNING" "No active container runtime detected (containerd/docker)"
    fi
    
    # Configure kubelet
    if systemctl is-enabled --quiet kubelet 2>/dev/null; then
        create_systemd_override "kubelet"
        restart_service "kubelet"
        verify_limits "kubelet"
    else
        print_status "WARNING" "Kubelet service not found or not enabled"
    fi
    
    # Configure container runtime
    if [ -n "$container_runtime" ]; then
        create_systemd_override "$container_runtime"
        restart_service "$container_runtime"
        verify_limits "$container_runtime"
    fi
    
    # Reload systemd daemon
    print_status "INFO" "Reloading systemd daemon"
    sudo systemctl daemon-reload
    
    echo ""
    print_status "SUCCESS" "Systemd limits configuration completed"
    echo ""
    echo "Next steps:"
    echo "1. Verify GPU device plugin can start without 'too many open files' errors"
    echo "2. Check pod logs: kubectl logs -n gpu-operator <device-plugin-pod>"
    echo "3. Monitor system resources: ulimit -n"
}

# Run main function
main "$@"
