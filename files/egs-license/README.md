# EGS License Setup

This folder contains the EGS license configuration for your cluster deployment.

## License File

Place your EGS license YAML file as `egs-license.yaml` in this folder.

### License File Format

The license file should contain a Kubernetes Secret with the following specifications:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: egs-license-file
  namespace: kubeslice-controller
  labels:
    app.kubernetes.io/license-type: egs-ent-license
    app.kubernetes.io/managed-by: kubeslice-controller
    license-status: valid
data:
  customer-name: <base64-encoded-customer-name>
  grace-period: <base64-encoded-grace-period>
  license-created: <base64-encoded-creation-timestamp>
  license-expiration: <base64-encoded-expiration-timestamp>
  license-updated: <base64-encoded-update-timestamp>
  license-id: <base64-encoded-license-id>
  license-type: <base64-encoded-license-type>
  license.key: <base64-encoded-license-key>
  machine.file: <base64-encoded-machine-file>
  gpu-count: <base64-encoded-gpu-count>
  overage: <base64-encoded-overage>
```

## How It Works

1. **License File Detection**: The system checks if `egs-license.yaml` exists in this folder
2. **Empty File Handling**: If the file is empty or contains only template content, it skips application
3. **License Application**: If a valid license file is found, it applies it to the cluster
4. **Secret Validation**: The system validates that the license secret exists and contains all required fields
5. **License Validation**: Checks license expiration and required labels

## Getting Your License

1. **Generate Cluster Fingerprint**: Run the deployment to generate your cluster fingerprint
2. **Visit EGS Registration**: Go to [https://registration.kubeslice.io/](https://registration.kubeslice.io/)
3. **Sign In**: Use your Avesha account credentials
4. **Generate License**: Use the cluster fingerprint to generate your license
5. **Download License**: Save the license file as `egs-license.yaml` in this folder

## Manual License Application

If you prefer to apply the license manually:

```bash
kubectl apply -f egs-license.yaml
```

## Validation

The system will automatically validate:
- ✅ License secret exists in `kubeslice-controller` namespace
- ✅ Required labels are present
- ✅ All required data fields are present
- ✅ License has not expired
- ✅ License status is valid

## Error Handling

If the license validation fails, the deployment will stop with clear error messages indicating:
- Missing license file
- Invalid license format
- Missing required fields
- Expired license
- Missing secret in cluster

## Next Steps

Once the license is validated successfully, you can proceed with EGS installation by uncommenting the EGS-related items in the `execution_order` section of `user_input.yml`.
