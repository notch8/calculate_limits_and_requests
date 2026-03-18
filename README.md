# Kubernetes Resource Optimization Guide

This guide helps you calculate and apply appropriate CPU and memory requests/limits for workloads in our Kubernetes clusters based on actual usage patterns.

## Overview

The `calculate-resources.rb` script:
1. Collects current resource configurations from the cluster
2. Queries Prometheus for 7-day usage metrics (95th and 99th percentiles)
3. Calculates recommendations based on actual usage + safety multipliers + minimum thresholds
4. Outputs a CSV with current vs recommended values and diff calculations

### Methodology

**Recommendations are based on:**
- **CPU Requests**: 95th percentile usage × 1.3
- **CPU Limits**: 99th percentile usage × 1.5
- **Memory Requests**: 95th percentile usage × 1.2
- **Memory Limits**: 99th percentile usage × 1.3

**With category-specific minimums:**
- **Rails apps** (web, worker, cable): 250m-1000m CPU, 2Gi-4Gi memory
- **Java apps** (FITS, Solr, Elasticsearch): 500m-1000m CPU, 1Gi-2Gi memory
- **Fcrepo**: 250m-1000m CPU, 3Gi-4Gi memory (Java heap + non-heap)
- **Databases** (PostgreSQL, MySQL): 100m-500m CPU, 512Mi-1Gi memory
- **Cache** (Redis, Memcached): 50m-250m CPU, 256Mi-512Mi memory
- **Utility**: 50m-100m CPU, 128Mi-256Mi memory

All values are rounded to sensible increments for easier comparison and maintenance.

## Prerequisites

### Required Tools
- `kubectl` configured with cluster access
- `kubectx` for context management
- Ruby 3.x with `json` and `csv` gems (built-in)
- `curl` for Prometheus queries

### Required Access
- Read access to all namespaces in the target cluster
- Access to Prometheus in `cattle-monitoring-system` namespace

## Running the Script

### Step 1: Set the Cluster Context

Edit the script to set your target cluster:
```ruby
CLUSTER = 'r2-friends'  # or 'r2-besties'
```

Set your kubectl context:
```bash
kubectx r2-friends
```

The script will verify you're in the correct context before running.

### Step 2: Port-Forward to Prometheus

In a separate terminal, create a port-forward to Prometheus:
```bash
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-prometheus 9090:9090
```

**Important:** Keep this running while the script executes.

### Step 3: Run the Script
```bash
ruby bin/calculate_resources.rb
```

**Expected runtime:** 2-3 minutes

**Output:**
- `r2-friends-resources-with-recommendations.csv` - Main results
- `r2-friends-cpu-p95.csv` - 95th percentile CPU metrics
- `r2-friends-cpu-p99.csv` - 99th percentile CPU metrics
- `r2-friends-mem-p95.csv` - 95th percentile memory metrics
- `r2-friends-mem-p99.csv` - 99th percentile memory metrics

## Interpreting Results

The CSV contains these key columns:

### Identification
- `namespace` - Kubernetes namespace
- `owner_type` - Deployment or StatefulSet
- `owner_name` - Name of the deployment/statefulset
- `container` - Container name within the pod
- `container_type` - Detected category (rails_app, java_app, etc.)

### Current Configuration
- `cpu_request_current` - Current CPU request
- `cpu_limit_current` - Current CPU limit
- `mem_request_current` - Current memory request
- `mem_limit_current` - Current memory limit

### Usage Metrics
- `cpu_p95_m` - 95th percentile CPU usage (millicores)
- `cpu_p99_m` - 99th percentile CPU usage (millicores)
- `mem_p95_mi` - 95th percentile memory usage (Mi)
- `mem_p99_mi` - 99th percentile memory usage (Mi)

### Recommendations
- `cpu_request_recommended` - Recommended CPU request
- `cpu_limit_recommended` - Recommended CPU limit
- `mem_request_recommended` - Recommended memory request
- `mem_limit_recommended` - Recommended memory limit

### Change Analysis
- `cpu_request_diff` - Change needed for CPU request (+/- values)
- `cpu_limit_diff` - Change needed for CPU limit (+/- values)
- `mem_request_diff` - Change needed for memory request (+/- values)
- `mem_limit_diff` - Change needed for memory limit (+/- values)

### YAML Stanza
- `stanza` - Ready-to-paste YAML for Helm values files

**Interpreting diffs:**
- **Positive values** (e.g., `+512Mi`): Need to increase resources
- **Negative values** (e.g., `-1Gi`): Can reduce resources (over-provisioned)
- **Empty**: No current value set

## Applying Recommendations

### For Hyku/Hyrax Applications

Most applications are deployed via Helm charts with values in `ops/*-deploy.tmpl.yaml` files.

1. **Open the application's values file**
```bash
   # Example: crash-world-cake
   cd crash_world_cake
   vim ops/friends-deploy.tmpl.yaml
```

2. **Update resource values**
   
   Copy the `stanza` column value for each container and paste into the appropriate section:
```yaml
   # Main web application
   resources:
     limits:
       memory: "4Gi"
       cpu: "1000m"
     requests:
       memory: "2Gi"
       cpu: "350m"

   # Worker
   worker:
     resources:
       limits:
         memory: "4Gi"
         cpu: "1000m"
       requests:
         memory: "2Gi"
         cpu: "250m"

   # Redis (Bitnami chart - note the master. prefix)
   redis:
     master:
       resources:
         limits:
           memory: "512Mi"
           cpu: "250m"
         requests:
           memory: "256Mi"
           cpu: "50m"

   # Fcrepo PostgreSQL (Bitnami subchart - note the primary. prefix)
   fcrepo:
     postgresql:
       primary:
         resources:
           limits:
             memory: "1Gi"
             cpu: "500m"
           requests:
             memory: "512Mi"
             cpu: "100m"
```

3. **Commit and push changes**
```bash
   git add ops/friends-deploy.tmpl.yaml
   git commit -m "Update resource limits based on usage analysis"
   git push
```

4. **Deploy via CI/CD**
   
   Your GitHub Actions workflow will build and deploy with the new values.

### Quick Iteration with kubectl (Testing Only)

For quick testing without rebuilding images:
```bash
NAMESPACE="your-namespace"
CURRENT_TAG=$(kubectl get deployment your-deployment -n $NAMESPACE \
  -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d':' -f2)

kubectl patch deployment your-deployment -n $NAMESPACE --type strategic --patch "
spec:
  template:
    spec:
      containers:
      - name: your-container
        image: your-image:$CURRENT_TAG
        resources:
          limits:
            memory: \"4Gi\"
            cpu: \"1000m\"
          requests:
            memory: \"2Gi\"
            cpu: \"350m\"
"
```

**Note:** This is for testing only. Changes made via kubectl will be overwritten by the next Helm deployment.

## Special Considerations

### StatefulSets with Bitnami Charts

Bitnami charts (Redis, PostgreSQL) use nested resource paths:
```yaml
# Redis
redis:
  master:  # Not just 'resources:'
    resources:
      limits: ...

# PostgreSQL
postgresql:
  primary:  # Not just 'resources:'
    resources:
      limits: ...
```

### Java Applications

Java apps (fcrepo, FITS, Solr) need memory limits that account for:
- JVM heap size (`-Xmx`)
- Non-heap memory (metaspace, thread stacks, etc.)

**Rule of thumb:** Memory limit should be 1.3-1.5x the heap size.

### Startup vs Steady-State

The recommendations are based on steady-state usage. Rails applications may need:
- **2-3x more memory during startup** (gem loading, asset compilation)
- **Higher CPU during startup** (initialization, migrations)

Our minimums (2Gi-4Gi for Rails) account for this, but monitor startup behavior after applying changes.

## Customizing Minimums

Edit the `MINIMUMS` hash in the script to adjust category minimums:
```ruby
MINIMUMS = {
  rails_app: { cpu_request: 250, cpu_limit: 1000, mem_request: 2048, mem_limit: 4096 },
  # ... other categories
}
```

All memory values are in Mi, CPU values are in millicores.

## Troubleshooting

### "The current context does not match the cluster name"

**Cause:** kubectl context doesn't match the `CLUSTER` variable in the script.

**Solution:**
```bash
kubectx r2-friends  # or r2-besties
```

### "Empty response from Prometheus"

**Cause:** Prometheus port-forward is not running or has disconnected.

**Solution:**
```bash
# In a separate terminal
kubectl port-forward -n monitoring \
  svc/kube-prometheus-stack-prometheus 9090:9090
```

### "Prometheus query failed"

**Cause:** Invalid Prometheus query or connectivity issue.

**Solution:**
1. Verify Prometheus is accessible: `curl http://localhost:9090/-/healthy`
2. Check Prometheus logs: `kubectl logs -n cattle-monitoring-system -l app=prometheus`

### Container Type Misclassification

**Symptom:** A container is categorized incorrectly (e.g., Redis as rails_app).

**Cause:** The pattern matching in `container_type()` needs adjustment.

**Solution:** Update the pattern matching order in the script. Specific patterns should come before generic ones:
```ruby
def container_type(pod_name, container_name, owner_name)
  combined = "#{pod_name} #{container_name} #{owner_name}".downcase
  
  # Specific services FIRST
  if combined =~ /redis|memcached/
    return :cache
  # ...
  # Generic patterns LAST
  elsif combined =~ /hyrax|hyku|rails/
    return :rails_app
  # ...
end
```

### No Metrics for New Deployments

**Symptom:** `cpu_p95_m` and similar columns are empty.

**Cause:** Deployment is less than 7 days old or Prometheus hasn't collected metrics yet.

**Solution:**
1. Wait for more data to accumulate (ideally 7 days)
2. Rely on minimums for the container type
3. Monitor and adjust after deployment based on actual usage

### Recommendations Seem Too High/Low

**Symptom:** Recommended values don't match your expectations.

**Investigation:**
1. Check the raw metrics columns (`cpu_p95_m`, `mem_p95_mi`)
2. Verify the `container_type` is correct
3. Review the multipliers (1.3x for requests, 1.5x for limits)
4. Consider if the 7-day period captured unusual load

**Solution:**
- Adjust minimums if needed for specific categories
- Re-run during a more representative time period
- Test recommendations on staging first

### Helm Release Stuck in "pending-*" State

**Symptom:** Cannot deploy because Helm shows `pending-upgrade` or `pending-rollback`.

**Solution:**
```bash
NAMESPACE="your-namespace"
RELEASE_SECRET=$(kubectl get secrets -n $NAMESPACE \
  -l name=your-release,owner=helm \
  --sort-by=.metadata.creationTimestamp | tail -1 | awk '{print $1}')

kubectl delete secret $RELEASE_SECRET -n $NAMESPACE
helm list -n $NAMESPACE  # Verify status is now "failed" or previous revision
```

## Repeating for Other Clusters

1. **Update the cluster name:**
```ruby
   CLUSTER = 'r2-besties'
```

2. **Switch context:**
```bash
   kubectx r2-besties
```

3. **Run the script:**
```bash
   ruby bin/calculate_resources.rb
```

4. **Apply recommendations** following the same process as above.

## Cost Impact

Setting appropriate resource limits:
- **Reduces waste** from over-provisioned workloads
- **Prevents OOMKills** and restarts from under-provisioning
- **Improves cluster efficiency** and bin-packing
- **Enables cost attribution** per client/application

Review the diff columns to estimate total resource impact:
- Sum positive diffs to see total increase needed
- Sum negative diffs to see potential savings
- Use this to inform capacity planning

## Best Practices

1. **Review classifications** - Always check the `container_type` column for accuracy
2. **Test on staging first** - Apply to r2-friends before r2-besties
3. **Monitor after changes** - Watch for OOMKills, restarts, or performance issues
4. **Iterate gradually** - Don't change all applications at once
5. **Document decisions** - Note why you deviated from recommendations in commit messages
6. **Re-run periodically** - Usage patterns change over time (quarterly recommended)
7. **Validate startup** - Restart a few pods after applying to ensure startup succeeds

## Next Steps

After applying recommendations to r2-friends and r2-besties:

1. **Document client costs** - Use resource allocations for cost attribution
2. **Set up monitoring** - Alert on containers approaching limits
3. **Implement LimitRanges** - Set cluster-wide defaults for new deployments
4. **Consider HPA** - For variable workloads, use Horizontal Pod Autoscaler
