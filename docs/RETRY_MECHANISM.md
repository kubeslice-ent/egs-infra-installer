# EGS Installer Retry Mechanism

The EGS installer includes a built-in retry mechanism to handle transient failures and timeouts during installation. This is especially useful for network-dependent operations and resource-intensive deployments.

## Table of Contents

- [Overview](#overview)
- [Configuration](#configuration)
- [Retry Features](#retry-features)
- [Retry Behavior](#retry-behavior)
- [Configuration Examples](#configuration-examples)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The retry mechanism automatically retries failed components during EGS installation, reducing the need for manual intervention when temporary issues occur. It supports:

- Configurable retry counts and delays
- Exponential backoff for delays
- Component-specific retry settings
- Override settings for critical components
- Detailed retry tracking and reporting

## Configuration

Retry behavior is configured in `user_input.yml` under the `retry_config` section:

```yaml
retry_config:
  # Global retry settings
  enabled: true                    # Enable retry mechanism globally
  max_retries: 3                   # Maximum number of retry attempts
  retry_delay: 30                  # Delay between retries in seconds
  exponential_backoff: true        # Use exponential backoff for delays
  
  # Component-specific retry settings (overrides global settings)
  component_retries:
    # Helm chart installations
    helm_charts:
      max_retries: 3
      retry_delay: 45
      exponential_backoff: true
      retry_on_failure: true       # Retry on any failure
      retry_on_timeout: true       # Retry on timeout
    
    # Kubernetes manifest applications
    manifests:
      max_retries: 2
      retry_delay: 20
      exponential_backoff: false
      retry_on_failure: true
      retry_on_timeout: false
    
    # Command executions
    commands:
      max_retries: 2
      retry_delay: 15
      exponential_backoff: false
      retry_on_failure: true
      retry_on_timeout: true
    
    # Kubectl commands
    kubectl_commands:
      max_retries: 3
      retry_delay: 10
      exponential_backoff: false
      retry_on_failure: true
      retry_on_timeout: true
  
  # Specific component retry overrides
  component_overrides:
    # Critical components that need more retries
    gpu_operator_chart:
      max_retries: 5
      retry_delay: 60
      exponential_backoff: true
    
    prometheus_stack:
      max_retries: 4
      retry_delay: 45
      exponential_backoff: true
    
    kubeslice_controller_egs:
      max_retries: 4
      retry_delay: 60
      exponential_backoff: true
    
    kubeslice_worker_egs_worker_1:
      max_retries: 4
      retry_delay: 60
      exponential_backoff: true
    
    # License validation - critical, needs more retries
    validate_and_apply_egs_license:
      max_retries: 5
      retry_delay: 30
      exponential_backoff: true
```

## Retry Features

- **🔄 Automatic Retries**: Failed components are automatically retried based on configuration
- **⏱️ Configurable Delays**: Set custom delays between retry attempts
- **📈 Exponential Backoff**: Option to increase delays exponentially with each retry
- **🎯 Component-Specific**: Different retry settings for different component types
- **🔧 Override Support**: Override retry settings for specific critical components
- **📊 Retry Tracking**: Retry attempts are tracked in the installation summary
- **🚫 Selective Disabling**: Disable retries for specific components if needed

## Retry Behavior

### 1. First Attempt
Component is executed normally using the standard installation process.

### 2. On Failure
If retry is enabled and the component fails:
- Wait for the configured delay period
- Display retry attempt information
- Prepare for retry execution

### 3. Retry Attempts
Execute component again with:
- Increased delay (if exponential backoff enabled)
- Same configuration as original attempt
- Retry counter incremented

### 4. Final Failure
After maximum retries are exhausted:
- Installation fails with detailed error message
- Provides troubleshooting steps
- Includes retry attempt history

## Configuration Examples

### Basic Configuration
```yaml
retry_config:
  enabled: true
  max_retries: 3
  retry_delay: 30
  exponential_backoff: true
```

### Aggressive Retry for Critical Components
```yaml
retry_config:
  enabled: true
  max_retries: 5
  retry_delay: 60
  exponential_backoff: true
  
  component_overrides:
    gpu_operator_chart:
      max_retries: 8
      retry_delay: 90
      exponential_backoff: true
    
    kubeslice_controller_egs:
      max_retries: 6
      retry_delay: 75
      exponential_backoff: true
```

### Conservative Retry for Stable Environments
```yaml
retry_config:
  enabled: true
  max_retries: 2
  retry_delay: 15
  exponential_backoff: false
  
  component_retries:
    helm_charts:
      max_retries: 2
      retry_delay: 30
      exponential_backoff: false
    
    commands:
      max_retries: 1
      retry_delay: 10
      exponential_backoff: false
```

### Network-Optimized Configuration
```yaml
retry_config:
  enabled: true
  max_retries: 4
  retry_delay: 45
  exponential_backoff: true
  
  component_retries:
    helm_charts:
      max_retries: 4
      retry_delay: 60
      exponential_backoff: true
    
    manifests:
      max_retries: 3
      retry_delay: 30
      exponential_backoff: true
```

### Disable Retries for Specific Components
```yaml
retry_config:
  enabled: true
  max_retries: 3
  retry_delay: 30
  exponential_backoff: true
  
  component_overrides:
    # Disable retry for this component
    problematic_component:
      max_retries: 0
    
    # Increase retry for critical components
    validate_and_apply_egs_license:
      max_retries: 5
      retry_delay: 45
      exponential_backoff: true
```

## Troubleshooting

### Common Issues

#### Components Failing After All Retries
**Symptoms:**
- Installation fails with "failed after X retry attempts" message
- Specific components consistently fail

**Solutions:**
1. Check component logs: `kubectl logs -n <namespace> <pod-name>`
2. Verify resource availability: `kubectl top nodes`
3. Review component configuration in user_input.yml
4. Increase retry settings for the failing component

#### Retry Mechanism Not Working
**Symptoms:**
- Components fail immediately without retries
- No retry messages in output

**Solutions:**
1. Enable retry mechanism: `retry_config.enabled: true`
2. Check component-specific settings
3. Verify retry configuration syntax

#### Excessive Retry Delays
**Symptoms:**
- Very long delays between retries
- Installation takes too long

**Solutions:**
1. Reduce retry delays: `retry_delay: 15`
2. Disable exponential backoff: `exponential_backoff: false`
3. Reduce max retries: `max_retries: 2`

### Debugging Retry Behavior

#### Enable Verbose Output
```bash
ansible-playbook site.yml -vvv
```

#### Check Retry Logs
Look for these messages in the output:
- `🔄 Retry attempt X/Y for component_name`
- `⏱️ Waiting Xs before retry...`
- `❌ component_name failed after X retry attempts`

#### Monitor Resource Usage
```bash
# In another terminal
watch -n 5 'kubectl top nodes && echo "---" && kubectl get pods --all-namespaces | grep -E "(Pending|Error|CrashLoopBackOff)"'
```

## Best Practices

### 1. Start with Default Settings
Begin with the default retry configuration and adjust based on your environment's behavior.

### 2. Monitor Resource Usage
Keep an eye on CPU, memory, and storage usage during retries to avoid resource exhaustion.

### 3. Check Logs for Root Causes
Don't just increase retry counts - investigate why components are failing.

### 4. Use Exponential Backoff for Network Components
Enable exponential backoff for components that depend on network connectivity.

### 5. Set Higher Retry Counts for Critical Components
Components like GPU operator and EGS controller should have more retry attempts.

### 6. Disable Retries for Fast-Fail Components
Some components should fail quickly rather than retry (e.g., configuration validation).

### 7. Environment-Specific Configuration
- **Development**: Lower retry counts, shorter delays
- **Production**: Higher retry counts, longer delays
- **Unstable Networks**: More aggressive retry settings

## Disabling Retries

### Global Disable
```yaml
retry_config:
  enabled: false
```

### Component-Specific Disable
```yaml
retry_config:
  enabled: true
  component_overrides:
    problematic_component:
      max_retries: 0
```

## Emergency Recovery

If retry mechanism causes issues:

1. **Disable retries temporarily:**
   ```yaml
   retry_config:
     enabled: false
   ```

2. **Run specific components manually:**
   ```bash
   ansible-playbook site.yml --extra-vars "execution_order=['component_name']"
   ```

3. **Check component status:**
   ```bash
   kubectl get pods --all-namespaces
   kubectl get events --all-namespaces
   ```

## Related Documentation

- [Retry Troubleshooting Guide](RETRY_TROUBLESHOOTING.md) - Detailed troubleshooting steps
- [User Input Configuration](USER_INPUT_CONFIGURATION.md) - Complete configuration guide
- [User Input Reference](USER_INPUT_REFERENCE.md) - All configuration options

## Support

For additional help with retry mechanism:
- Check the troubleshooting guide above
- Review component-specific documentation
- Create an issue in the repository with retry logs and configuration
