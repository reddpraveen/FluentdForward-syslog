#!/bin/bash

set -e

echo "Checking allocated resources for logging nodes..."

# Get all logging nodes
echo "Getting list of logging nodes..."
LOGGING_NODES=$(oc get nodes -l node-role.kubernetes.io/logging=true -o name)

echo "Node Name,CPU Allocated (cores),Memory Allocated (Mi),Pods Running,Loki Ingesters,Loki Queriers,Loki Compactors,Loki Distributors"
echo "--------------------------------------------------------------------------------------------------------"

for node in $LOGGING_NODES; do
  NODE_NAME=$(echo $node | cut -d'/' -f2)
  
  # Get CPU and memory allocated
  CPU_ALLOCATED=$(oc describe $node | grep -A 5 "Allocated resources:" | grep "cpu" | awk '{print $2}' | sed 's/(//' | sed 's/)//')
  MEM_ALLOCATED=$(oc describe $node | grep -A 5 "Allocated resources:" | grep "memory" | awk '{print $2}' | sed 's/(//' | sed 's/)//')
  
  # Get number of pods running on this node
  PODS_RUNNING=$(oc get pods --all-namespaces -o wide | grep $NODE_NAME | wc -l)
  
  # Count Loki components on this node
  LOKI_INGESTERS=$(oc get pods -n openshift-logging -o wide | grep $NODE_NAME | grep "loki-ingester" | wc -l)
  LOKI_QUERIERS=$(oc get pods -n openshift-logging -o wide | grep $NODE_NAME | grep "loki-querier" | wc -l)
  LOKI_COMPACTORS=$(oc get pods -n openshift-logging -o wide | grep $NODE_NAME | grep "loki-compactor" | wc -l)
  LOKI_DISTRIBUTORS=$(oc get pods -n openshift-logging -o wide | grep $NODE_NAME | grep "loki-distributor" | wc -l)
  
  echo "$NODE_NAME,$CPU_ALLOCATED,$MEM_ALLOCATED,$PODS_RUNNING,$LOKI_INGESTERS,$LOKI_QUERIERS,$LOKI_COMPACTORS,$LOKI_DISTRIBUTORS"
done

echo ""
echo "Checking LokiStack configuration..."
echo "----------------------------------"
oc get lokistack instance -n openshift-logging -o yaml | grep -A 10 "size:"

echo ""
echo "Checking Loki component resource requests..."
echo "------------------------------------------"
oc get pods -n openshift-logging -l app.kubernetes.io/name=loki -o yaml | grep -A 5 "resources:"

echo ""
echo "Recommendations:"
echo "1. Look for nodes with fewer Loki components, especially ingesters"
echo "2. Check nodes with lower CPU and memory allocation"
echo "3. Ensure you don't remove nodes with critical Loki components"
echo "4. Consider the impact on your 1x medium LokiStack with 4 ingesters" 