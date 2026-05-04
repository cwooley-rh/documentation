#!/bin/bash
# Conflict detection for batch PR validation
# Usage: detect-conflicts.sh guide1.md guide2.md

set -euo pipefail

guide_a="$1"
guide_b="$2"

if [[ ! -f "$guide_a" ]] || [[ ! -f "$guide_b" ]]; then
  echo "ERROR: Both guide files must exist"
  exit 1
fi

conflicts=()
conflict_level="LOW"

# Check for cluster-wide operators
ops_a=$(grep -E "kind: (Subscription|ClusterServiceVersion|OperatorGroup)" "$guide_a" | wc -l | tr -d ' ')
ops_b=$(grep -E "kind: (Subscription|ClusterServiceVersion|OperatorGroup)" "$guide_b" | wc -l | tr -d ' ')

if [[ $ops_a -gt 0 && $ops_b -gt 0 ]]; then
  conflicts+=("Both install operators")
  conflict_level="HIGH"
fi

# Check for CRDs
crds_a=$(grep -E "kind: CustomResourceDefinition|apiVersion:.*\.openshift\.io" "$guide_a" | wc -l | tr -d ' ')
crds_b=$(grep -E "kind: CustomResourceDefinition|apiVersion:.*\.openshift\.io" "$guide_b" | wc -l | tr -d ' ')

if [[ $crds_a -gt 0 && $crds_b -gt 0 ]]; then
  conflicts+=("Both define custom resources/CRDs")
  if [[ "$conflict_level" != "HIGH" ]]; then
    conflict_level="MEDIUM"
  fi
fi

# Check for GPU requirements
gpu_a=$(grep -E "nvidia\.com/gpu|gpu-operator|g4dn\.|p3\.|p4d\.|Tesla|A100|T4" "$guide_a" | wc -l | tr -d ' ')
gpu_b=$(grep -E "nvidia\.com/gpu|gpu-operator|g4dn\.|p3\.|p4d\.|Tesla|A100|T4" "$guide_b" | wc -l | tr -d ' ')

if [[ $gpu_a -gt 0 && $gpu_b -gt 0 ]]; then
  conflicts+=("Both require GPU (single GPU node)")
  conflict_level="HIGH"
fi

# Check for storage operators
storage_a=$(grep -E "Trident|ODF|Portworx|blob-storage-csi|file-storage-csi|efs-csi" "$guide_a" | wc -l | tr -d ' ')
storage_b=$(grep -E "Trident|ODF|Portworx|blob-storage-csi|file-storage-csi|efs-csi" "$guide_b" | wc -l | tr -d ' ')

if [[ $storage_a -gt 0 && $storage_b -gt 0 ]]; then
  conflicts+=("Both install storage operators/CSI drivers")
  conflict_level="HIGH"
fi

# Check for service mesh
mesh_a=$(grep -E "ServiceMesh|Istio|service-mesh" "$guide_a" | wc -l | tr -d ' ')
mesh_b=$(grep -E "ServiceMesh|Istio|service-mesh" "$guide_b" | wc -l | tr -d ' ')

if [[ $mesh_a -gt 0 && $mesh_b -gt 0 ]]; then
  conflicts+=("Both install Service Mesh")
  conflict_level="HIGH"
fi

# Check for cluster-wide config changes
config_a=$(grep -E "KMS|kms-encryption|FIPS|fips-mode|CNI|ingress-controller" "$guide_a" | wc -l | tr -d ' ')
config_b=$(grep -E "KMS|kms-encryption|FIPS|fips-mode|CNI|ingress-controller" "$guide_b" | wc -l | tr -d ' ')

if [[ $config_a -gt 0 && $config_b -gt 0 ]]; then
  conflicts+=("Both modify cluster-wide configuration")
  conflict_level="HIGH"
fi

# Check for metrics/observability (usually compatible)
metrics_a=$(grep -E "metrics|prometheus|grafana|cloudwatch|azure-monitor" "$guide_a" | wc -l | tr -d ' ')
metrics_b=$(grep -E "metrics|prometheus|grafana|cloudwatch|azure-monitor" "$guide_b" | wc -l | tr -d ' ')

if [[ $metrics_a -gt 0 && $metrics_b -gt 0 && ${#conflicts[@]} -eq 0 ]]; then
  conflicts+=("Both configure metrics (usually compatible)")
  conflict_level="LOW"
fi

# Output results
echo "Conflict Level: $conflict_level"

if [[ ${#conflicts[@]} -eq 0 ]]; then
  echo "Conflicts: None - guides can run in parallel"
else
  echo "Conflicts:"
  for conflict in "${conflicts[@]}"; do
    echo "  - $conflict"
  done
fi

# Recommendation
case "$conflict_level" in
  LOW)
    echo ""
    echo "Recommendation: Can run in parallel on same cluster"
    ;;
  MEDIUM)
    echo ""
    echo "Recommendation: Run sequentially with namespace-level cleanup"
    ;;
  HIGH)
    echo ""
    echo "Recommendation: Run sequentially with operator-level cleanup, or use separate clusters"
    ;;
esac

# Exit code: 0 = no conflict, 1 = medium, 2 = high
if [[ "$conflict_level" == "HIGH" ]]; then
  exit 2
elif [[ "$conflict_level" == "MEDIUM" ]]; then
  exit 1
else
  exit 0
fi
