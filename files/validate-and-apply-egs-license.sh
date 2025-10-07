#!/bin/bash

# EGS License Validation and Application Script
# This script validates and applies EGS license for cluster deployment

set -e  # Exit on any error

echo "=========================================="
echo "EGS License Validation and Application"
echo "=========================================="

# Configuration
LICENSE_FOLDER="files/egs-license"
LICENSE_FILE="egs-license.yaml"
NAMESPACE="kubeslice-controller"
SECRET_NAME="egs-license-file"

# Display configuration being used
echo "Configuration:"
echo "  KUBECONFIG: ${KUBECONFIG:-'default location'}"
echo "  KUBECONTEXT: ${KUBECONTEXT:-'current context'}"
echo "  License Folder: $LICENSE_FOLDER"
echo "  License File: $LICENSE_FILE"
echo "  Namespace: $NAMESPACE"
echo "  Secret Name: $SECRET_NAME"
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

# Function to check if namespace exists
check_namespace() {
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        echo "✓ Namespace '$NAMESPACE' exists"
        return 0
    else
        echo "✗ Namespace '$NAMESPACE' does not exist"
        return 1
    fi
}

# Function to check if license secret exists
check_license_secret() {
    if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
        echo "✓ License secret '$SECRET_NAME' exists in namespace '$NAMESPACE'"
        return 0
    else
        echo "✗ License secret '$SECRET_NAME' does not exist in namespace '$NAMESPACE'"
        return 1
    fi
}

# Function to validate license secret
validate_license_secret() {
    echo "Validating license secret..."
    
    # Check if secret has required labels
    if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/license-type}' | grep -q "egs-ent-license"; then
        echo "✗ License secret missing required label 'app.kubernetes.io/license-type: egs-ent-license'"
        return 1
    fi
    
    # Check if secret has required data fields
    REQUIRED_FIELDS=("customer-name" "license-created" "license-expiration" "license-id" "license-type" "license.key" "machine.file")
    for field in "${REQUIRED_FIELDS[@]}"; do
        if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath="{.data.$field}" &> /dev/null; then
            echo "✗ License secret missing required field: $field"
            return 1
        fi
    done
    
    # Check license expiration
    EXPIRATION=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.license-expiration}' | base64 -d 2>/dev/null || echo "")
    if [ -n "$EXPIRATION" ]; then
        EXPIRATION_EPOCH=$(date -d "$EXPIRATION" +%s 2>/dev/null || echo "0")
        CURRENT_EPOCH=$(date +%s)
        if [ "$EXPIRATION_EPOCH" -lt "$CURRENT_EPOCH" ]; then
            echo "✗ License has expired (expiration: $EXPIRATION)"
            return 1
        else
            echo "✓ License is valid (expires: $EXPIRATION)"
        fi
    fi
    
    echo "✓ License secret validation passed"
    return 0
}

# Function to apply license from file
apply_license_from_file() {
    local license_file="$1"
    echo "Applying license from file: $license_file"
    
    if kubectl apply -f "$license_file"; then
        echo "✓ License applied successfully"
        return 0
    else
        echo "✗ Failed to apply license from file"
        return 1
    fi
}

# Function to create namespace if it doesn't exist
create_namespace() {
    echo "Creating namespace '$NAMESPACE'..."
    if kubectl create namespace "$NAMESPACE" 2>/dev/null; then
        echo "✓ Created namespace '$NAMESPACE'"
    else
        echo "✓ Namespace '$NAMESPACE' already exists or created successfully"
    fi
}

# Main execution logic
echo "=========================================="
echo "Starting License Validation Process"
echo "=========================================="

# Step 1: Check if namespace exists, create if not
if ! check_namespace; then
    echo "Creating namespace..."
    create_namespace
fi

# Step 2: Check if license file exists in folder
LICENSE_FILE_PATH="$LICENSE_FOLDER/$LICENSE_FILE"
if [ -f "$LICENSE_FILE_PATH" ]; then
    echo "✓ License file found: $LICENSE_FILE_PATH"
    
    # Check if file is empty or contains only comments
    if [ ! -s "$LICENSE_FILE_PATH" ] || grep -q "^# EGS License File" "$LICENSE_FILE_PATH" && ! grep -q "^apiVersion:" "$LICENSE_FILE_PATH"; then
        echo "⚠ License file is empty or contains only template content"
        echo "Skipping license application from file"
    else
        # Apply the license file
        if apply_license_from_file "$LICENSE_FILE_PATH"; then
            echo "✓ License applied from file"
        else
            echo "✗ Failed to apply license from file"
            exit 1
        fi
    fi
else
    echo "✗ License file not found: $LICENSE_FILE_PATH"
    echo ""
    echo "Please ensure the license file is placed at: $LICENSE_FILE_PATH"
    echo "Or apply the license manually using:"
    echo "  kubectl apply -f <your-license-file.yaml>"
    echo ""
    exit 1
fi

# Step 3: Wait a moment for secret to be created (only if we applied a file)
if [ -f "$LICENSE_FILE_PATH" ] && [ -s "$LICENSE_FILE_PATH" ] && grep -q "^apiVersion:" "$LICENSE_FILE_PATH"; then
    echo "Waiting for secret to be created..."
    sleep 5
fi

# Step 4: Check if license secret exists
if ! check_license_secret; then
    echo "✗ License secret not found"
    echo ""
    echo "ERROR: EGS License is required before proceeding with EGS installation!"
    echo ""
    echo "Please ensure the license is applied by either:"
    echo "1. Placing a valid license file at: $LICENSE_FILE_PATH"
    echo "2. Applying the license manually: kubectl apply -f <your-license-file.yaml>"
    echo ""
    echo "The license must create a secret named '$SECRET_NAME' in namespace '$NAMESPACE'"
    echo "with the following required labels and data fields:"
    echo "  Labels: app.kubernetes.io/license-type: egs-ent-license"
    echo "  Data: customer-name, license-created, license-expiration, license-id, license-type, license.key, machine.file"
    echo ""
    exit 1
fi

# Step 5: Validate license secret
if ! validate_license_secret; then
    echo "✗ License secret validation failed"
    echo "Please check the license file and ensure it contains all required fields"
    exit 1
fi

# Step 6: Display license information
echo ""
echo "=========================================="
echo "License Information"
echo "=========================================="

# Get license details
CUSTOMER_NAME=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.customer-name}' | base64 -d 2>/dev/null || echo "N/A")
LICENSE_TYPE=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.license-type}' | base64 -d 2>/dev/null || echo "N/A")
LICENSE_CREATED=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.license-created}' | base64 -d 2>/dev/null || echo "N/A")
LICENSE_EXPIRATION=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.license-expiration}' | base64 -d 2>/dev/null || echo "N/A")
LICENSE_ID=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.data.license-id}' | base64 -d 2>/dev/null || echo "N/A")

echo "Customer Name: $CUSTOMER_NAME"
echo "License Type: $LICENSE_TYPE"
echo "License Created: $LICENSE_CREATED"
echo "License Expiration: $LICENSE_EXPIRATION"
echo "License ID: $LICENSE_ID"
echo ""

# Step 7: Final validation
echo "=========================================="
echo "Final Validation"
echo "=========================================="

# Check if secret is ready for use
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.license-status}' | grep -q "valid"; then
    echo "✓ License status: VALID"
else
    echo "⚠ License status: Unknown (check manually)"
fi

echo "✓ EGS License validation and application completed successfully!"
echo ""
echo "Next steps:"
echo "1. Proceed with EGS installation"
echo "2. The license is now available in the '$NAMESPACE' namespace"
echo "3. EGS components can now be deployed"
echo ""

# Save license info to output file
mkdir -p output
cat > output/egs-license-info.txt << EOF
EGS License Information
=======================
Customer Name: $CUSTOMER_NAME
License Type: $LICENSE_TYPE
License Created: $LICENSE_CREATED
License Expiration: $LICENSE_EXPIRATION
License ID: $LICENSE_ID
Namespace: $NAMESPACE
Secret Name: $SECRET_NAME
Status: VALID
EOF

echo "✓ License information saved to: output/egs-license-info.txt"
