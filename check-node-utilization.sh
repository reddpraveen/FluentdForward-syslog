#!/bin/bash

set -e

echo "Checking resource utilization for logging nodes..."
echo "==============================================="

# Get all logging nodes
LOGGING_NODES=$(oc get nodes -l node-role.kubernetes.io/logging='' -o name)

echo "Node Name,CPU Utilization %,Memory Utilization %,CPU Allocated (cores),Memory Allocated (Mi),CPU Capacity (cores),Memory Capacity (Mi)"
echo "----------------------------------------------------------------------------------------------------------------------------"

for node in $LOGGING_NODES; do
  NODE_NAME=$(echo $node | cut -d'/' -f2)
  
  # Get CPU and memory utilization
  CPU_UTIL=$(oc adm top node $NODE_NAME --no-headers | awk '{print $3}' | sed 's/%//')
  MEM_UTIL=$(oc adm top node $NODE_NAME --no-headers | awk '{print $5}' | sed 's/%//')
  
  # Get CPU and memory allocated
  CPU_ALLOCATED=$(oc describe $node | grep -A 5 "Allocated resources:" | grep "cpu" | awk '{print $2}' | sed 's/(//' | sed 's/)//')
  MEM_ALLOCATED=$(oc describe $node | grep -A 5 "Allocated resources:" | grep "memory" | awk '{print $2}' | sed 's/(//' | sed 's/)//')
  
  # Get CPU and memory capacity
  CPU_CAPACITY=$(oc describe $node | grep -A 5 "Capacity:" | grep "cpu" | awk '{print $2}')
  MEM_CAPACITY=$(oc describe $node | grep -A 5 "Capacity:" | grep "memory" | awk '{print $2}')
  
  echo "$NODE_NAME,$CPU_UTIL,$MEM_UTIL,$CPU_ALLOCATED,$MEM_ALLOCATED,$CPU_CAPACITY,$MEM_CAPACITY"
done

# Check for nodes with low utilization
echo ""
echo "Nodes with Low Utilization (Potential Candidates for Scaling Down):"
echo "----------------------------------------------------------------"
oc adm top nodes -l node-role.kubernetes.io/logging='' --sort-by=cpu | grep -v "NAME" | awk '$3 < 30 {print $1 " (CPU: " $3 "%, MEM: " $5 "%)"}'

# Check for nodes with high utilization
echo ""
echo "Nodes with High Utilization (Avoid Scaling Down):"
echo "----------------------------------------------"
oc adm top nodes -l node-role.kubernetes.io/logging='' --sort-by=cpu | grep -v "NAME" | awk '$3 > 70 {print $1 " (CPU: " $3 "%, MEM: " $5 "%)"}'

# Check for nodes with critical Loki components
echo ""
echo "Nodes with Critical Loki Components (Avoid Scaling Down):"
echo "-----------------------------------------------------"
for node in $(oc get nodes -l node-role.kubernetes.io/logging='' -o name | cut -d'/' -f2); do
  COMPACTORS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-compactor" | wc -l)
  if [ $COMPACTORS -gt 0 ]; then
    echo "$node (Has Compactor)"
  fi
  
  INGESTERS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-ingester" | wc -l)
  if [ $INGESTERS -gt 1 ]; then
    echo "$node (Has Multiple Ingesters: $INGESTERS)"
  fi
done

echo ""
echo "Recommendations:"
echo "1. Look for nodes with low CPU and memory utilization"
echo "2. Avoid nodes with critical Loki components like compactors"
echo "3. Consider the impact on your 1x medium LokiStack with 4 ingesters"
echo "4. Ensure you don't remove nodes with multiple ingesters"
echo "5. Check if removing a node would leave enough resources for the remaining Loki components" 