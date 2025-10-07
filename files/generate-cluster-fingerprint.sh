#!/bin/bash

# EGS Cluster Fingerprint Generation Script
# This script generates the cluster fingerprint required for EGS license generation

set -e  # Exit on any error

echo "=========================================="
echo "EGS Cluster Fingerprint Generation"
echo "=========================================="

# Display configuration being used
echo "Configuration:"
echo "  KUBECONFIG: ${KUBECONFIG:-'default location'}"
echo "  KUBECONTEXT: ${KUBECONTEXT:-'current context'}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed or not in PATH"
    exit 1
fi

# Set kubectl context if provided
if [ -n "$KUBECONTEXT" ]; then
    echo "Using Kubernetes context: $KUBECONTEXT"
    kubectl config use-context "$KUBECONTEXT" || {
        echo "ERROR: Failed to switch to context: $KUBECONTEXT"
        exit 1
    }
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    echo "Please ensure your kubeconfig is properly configured"
    echo "KUBECONFIG: ${KUBECONFIG:-'not set'}"
    echo "KUBECONTEXT: ${KUBECONTEXT:-'not set'}"
    exit 1
fi

echo "✓ Kubernetes cluster is accessible"

# Display current context for verification
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "Unable to determine")
echo "✓ Current context: $CURRENT_CONTEXT"

# Create kubeslice-controller namespace if it doesn't exist
echo "Creating kubeslice-controller namespace..."
if ! kubectl get namespace kubeslice-controller &> /dev/null; then
    kubectl create namespace kubeslice-controller
    echo "✓ Created kubeslice-controller namespace"
else
    echo "✓ kubeslice-controller namespace already exists"
fi

# Generate cluster fingerprint
echo "Generating cluster fingerprint..."
echo ""

FINGERPRINT=$(kubectl get namespace kube-system -o=jsonpath='{.metadata.creationTimestamp}{.metadata.uid}{"\n"}')

if [ -z "$FINGERPRINT" ]; then
    echo "ERROR: Failed to generate cluster fingerprint"
    exit 1
fi

echo "=========================================="
echo "CLUSTER FINGERPRINT:"
echo "=========================================="
echo "$FINGERPRINT"
echo "=========================================="
echo ""

# Save fingerprint to file
FINGERPRINT_FILE="output/cluster-fingerprint.txt"
mkdir -p output
echo "$FINGERPRINT" > "$FINGERPRINT_FILE"

echo "✓ Cluster fingerprint saved to: $FINGERPRINT_FILE"
echo ""

# Display next steps
echo "=========================================="
echo "NEXT STEPS FOR EGS LICENSE GENERATION:"
echo "=========================================="
echo "1. Copy the cluster fingerprint above"
echo "2. Visit the EGS Registration page:"
echo "   https://registration.kubeslice.io/"
echo "3. Sign in with your Avesha account"
echo "4. Navigate to 'License Management' section"
echo "5. Click 'Generate New License'"
echo "6. Paste the cluster fingerprint when prompted"
echo "7. Select your license type and duration"
echo "8. Download the generated license file"
echo "9. Apply the license to your cluster using:"
echo "   kubectl apply -f <license-file.yaml>"
echo "=========================================="
echo ""

# Additional cluster information for reference
echo "Additional Cluster Information:"
echo "Cluster Name: $(kubectl config current-context 2>/dev/null || echo 'Not available')"
echo "Kubernetes Version: $(kubectl version --short 2>/dev/null | grep Server | cut -d' ' -f3 || echo 'Not available')"
echo "Node Count: $(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo 'Not available')"
echo ""

echo "Script completed successfully!"
