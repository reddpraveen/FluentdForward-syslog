#!/bin/bash

set -e

echo "Analyzing Loki component distribution and resource allocation..."
echo "============================================================="

# Get LokiStack configuration
echo "LokiStack Configuration:"
echo "----------------------"
oc get lokistack instance -n openshift-logging -o yaml | grep -A 15 "size:"

# Get all Loki pods and their resource requests
echo ""
echo "Loki Pod Resource Requests:"
echo "-------------------------"
oc get pods -n openshift-logging -l app.kubernetes.io/name=loki -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,CPU_REQUEST:.spec.containers[0].resources.requests.cpu,MEMORY_REQUEST:.spec.containers[0].resources.requests.memory,CPU_LIMIT:.spec.containers[0].resources.limits.cpu,MEMORY_LIMIT:.spec.containers[0].resources.limits.memory

# Count Loki components by node
echo ""
echo "Loki Component Distribution by Node:"
echo "----------------------------------"
echo "Node Name,Ingesters,Queriers,Compactors,Distributors,Total Components"
echo "-------------------------------------------------------------------"

for node in $(oc get nodes -l node-role.kubernetes.io/logging=true -o name | cut -d'/' -f2); do
  INGESTERS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-ingester" | wc -l)
  QUERIERS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-querier" | wc -l)
  COMPACTORS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-compactor" | wc -l)
  DISTRIBUTORS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-distributor" | wc -l)
  TOTAL=$((INGESTERS + QUERIERS + COMPACTORS + DISTRIBUTORS))
  
  echo "$node,$INGESTERS,$QUERIERS,$COMPACTORS,$DISTRIBUTORS,$TOTAL"
done

# Check for Loki component dependencies
echo ""
echo "Loki Component Dependencies:"
echo "--------------------------"
echo "1. Ingesters: Required for data ingestion, should be evenly distributed"
echo "2. Queriers: Required for querying data, can be scaled based on query load"
echo "3. Compactors: Required for data compaction, typically one is sufficient"
echo "4. Distributors: Required for data distribution, should be evenly distributed"

# Calculate total resource requests for Loki components
echo ""
echo "Total Resource Requests for Loki Components:"
echo "------------------------------------------"
TOTAL_CPU_REQUEST=$(oc get pods -n openshift-logging -l app.kubernetes.io/name=loki -o jsonpath='{.items[*].spec.containers[0].resources.requests.cpu}' | tr ' ' '\n' | sed 's/m//g' | awk '{sum += $1} END {print sum/1000 " cores"}')
TOTAL_MEMORY_REQUEST=$(oc get pods -n openshift-logging -l app.kubernetes.io/name=loki -o jsonpath='{.items[*].spec.containers[0].resources.requests.memory}' | tr ' ' '\n' | sed 's/Mi//g' | awk '{sum += $1} END {print sum " Mi"}')

echo "Total CPU Request: $TOTAL_CPU_REQUEST"
echo "Total Memory Request: $TOTAL_MEMORY_REQUEST"

# Recommendations for scaling down
echo ""
echo "Recommendations for Scaling Down:"
echo "-------------------------------"
echo "1. Identify nodes with the fewest Loki components"
echo "2. Ensure you don't remove nodes with critical components like compactors"
echo "3. Consider the impact on your 1x medium LokiStack with 4 ingesters"
echo "4. Check if removing a node would leave enough resources for the remaining Loki components"
echo "5. Consider the impact on data availability and query performance"
echo ""
echo "Note: Before scaling down, ensure you have enough resources on the remaining nodes"
echo "      to handle the workload of the removed nodes." 