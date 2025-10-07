# Retry Mechanism Troubleshooting Guide

This guide helps troubleshoot issues related to the retry mechanism in EGS installation.

## Common Retry Issues

### 1. Components Failing After All Retries

**Symptoms:**
- Installation fails with "failed after X retry attempts" message
- Specific components consistently fail

**Troubleshooting Steps:**

```bash
# Check component logs
kubectl logs -n <namespace> <pod-name>

# Check resource availability
kubectl top nodes
kubectl describe nodes

# Check component status
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

**Solutions:**
1. **Increase retry settings** for the failing component
2. **Check prerequisites** are met
3. **Verify resource availability** (CPU, memory, storage)
4. **Review component configuration** in user_input.yml

### 2. Retry Mechanism Not Working

**Symptoms:**
- Components fail immediately without retries
- No retry messages in output

**Troubleshooting Steps:**

```bash
# Check retry configuration
grep -A 20 "retry_config:" user_input.yml

# Verify retry is enabled
ansible-playbook site.yml --check --diff
```

**Solutions:**
1. **Enable retry mechanism:**
   ```yaml
   retry_config:
     enabled: true
   ```

2. **Check component-specific settings:**
   ```yaml
   retry_config:
     component_overrides:
       your_component:
         max_retries: 3
         retry_delay: 30
   ```

### 3. Excessive Retry Delays

**Symptoms:**
- Very long delays between retries
- Installation takes too long

**Troubleshooting Steps:**

```bash
# Check current retry configuration
grep -A 30 "retry_config:" user_input.yml
```

**Solutions:**
1. **Reduce retry delays:**
   ```yaml
   retry_config:
     retry_delay: 15  # Reduce from 30 to 15 seconds
   ```

2. **Disable exponential backoff:**
   ```yaml
   retry_config:
     exponential_backoff: false
   ```

3. **Reduce max retries:**
   ```yaml
   retry_config:
     max_retries: 2  # Reduce from 3 to 2
   ```

### 4. Specific Component Retry Issues

#### GPU Operator Chart
```yaml
retry_config:
  component_overrides:
    gpu_operator_chart:
      max_retries: 5
      retry_delay: 60
      exponential_backoff: true
```

#### EGS Controller
```yaml
retry_config:
  component_overrides:
    kubeslice_controller_egs:
      max_retries: 4
      retry_delay: 60
      exponential_backoff: true
```

#### License Validation
```yaml
retry_config:
  component_overrides:
    validate_and_apply_egs_license:
      max_retries: 5
      retry_delay: 30
      exponential_backoff: true
```

## Retry Configuration Examples

### For Unstable Networks
```yaml
retry_config:
  enabled: true
  max_retries: 5
  retry_delay: 60
  exponential_backoff: true
  
  component_retries:
    helm_charts:
      max_retries: 6
      retry_delay: 90
      exponential_backoff: true
```

### For Resource-Constrained Environments
```yaml
retry_config:
  enabled: true
  max_retries: 4
  retry_delay: 45
  exponential_backoff: true
  
  component_overrides:
    gpu_operator_chart:
      max_retries: 6
      retry_delay: 90
      exponential_backoff: true
```

### For Quick Failures (Development)
```yaml
retry_config:
  enabled: true
  max_retries: 2
  retry_delay: 10
  exponential_backoff: false
```

## Debugging Retry Behavior

### Enable Verbose Output
```bash
ansible-playbook site.yml -vvv
```

### Check Retry Logs
Look for these messages in the output:
- `🔄 Retry attempt X/Y for component_name`
- `⏱️ Waiting Xs before retry...`
- `❌ component_name failed after X retry attempts`

### Monitor Resource Usage During Retries
```bash
# In another terminal
watch -n 5 'kubectl top nodes && echo "---" && kubectl get pods --all-namespaces | grep -E "(Pending|Error|CrashLoopBackOff)"'
```

## Best Practices

1. **Start with default settings** and adjust based on your environment
2. **Monitor resource usage** during retries
3. **Check logs** for specific failure reasons
4. **Use exponential backoff** for network-dependent components
5. **Set higher retry counts** for critical components
6. **Disable retries** for components that should fail fast

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

## Support

For additional help with retry mechanism issues:
- Check the main README.md for retry configuration details
- Review component-specific documentation
- Create an issue in the repository with retry logs
