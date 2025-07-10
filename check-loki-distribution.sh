#!/bin/bash

set -e

echo "Checking Loki component distribution for 1x medium LokiStack with 4 ingesters..."
echo "======================================================================="

# Get LokiStack configuration
echo "LokiStack Configuration:"
echo "----------------------"
oc get lokistack logging-loki -n openshift-logging -o yaml | grep -A 15 "size:"

# Check current ingester count
echo ""
echo "Current Ingester Count:"
echo "--------------------"
INGESTER_COUNT=$(oc get pods -n openshift-logging -l app.kubernetes.io/component=ingester -o name | wc -l)
echo "Total Ingesters: $INGESTER_COUNT"

# Check ingester distribution by node
echo ""
echo "Ingester Distribution by Node:"
echo "---------------------------"
echo "Node Name,Ingesters,CPU Request,Memory Request"
echo "-------------------------------------------"

for node in $(oc get nodes -l node-role.kubernetes.io/logging='' -o name | cut -d'/' -f2); do
  INGESTERS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-ingester" | wc -l)
  
  if [ $INGESTERS -gt 0 ]; then
    # Get resource requests for ingesters on this node
    CPU_REQUEST=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-ingester" | awk '{print $1}' | xargs -I{} oc get pod {} -n openshift-logging -o jsonpath='{.spec.containers[0].resources.requests.cpu}' | tr ' ' '\n' | sed 's/m//g' | awk '{sum += $1} END {print sum/1000 " cores"}')
    MEM_REQUEST=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-ingester" | awk '{print $1}' | xargs -I{} oc get pod {} -n openshift-logging -o jsonpath='{.spec.containers[0].resources.requests.memory}' | tr ' ' '\n' | sed 's/Mi//g' | awk '{sum += $1} END {print sum " Mi"}')
    
    echo "$node,$INGESTERS,$CPU_REQUEST,$MEM_REQUEST"
  fi
done

# Check if we can safely scale down a node
echo ""
echo "Analyzing if we can safely scale down nodes:"
echo "-----------------------------------------"

# Count nodes with ingesters
NODES_WITH_INGESTERS=$(oc get pods -n openshift-logging -o wide | grep "loki-ingester" | awk '{print $7}' | sort | uniq | wc -l)
echo "Nodes with Ingesters: $NODES_WITH_INGESTERS"

# Check if we have enough nodes to maintain 4 ingesters
if [ $NODES_WITH_INGESTERS -le 2 ]; then
  echo "WARNING: You have only $NODES_WITH_INGESTERS nodes with ingesters. Scaling down may impact your 1x medium LokiStack with 4 ingesters."
else
  echo "You have $NODES_WITH_INGESTERS nodes with ingesters. You may be able to scale down 1-2 nodes if they don't have ingesters."
fi

# Check for nodes without ingesters
echo ""
echo "Nodes without Ingesters (Potential Candidates for Scaling Down):"
echo "------------------------------------------------------------"
for node in $(oc get nodes -l node-role.kubernetes.io/logging='' -o name | cut -d'/' -f2); do
  INGESTERS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-ingester" | wc -l)
  if [ $INGESTERS -eq 0 ]; then
    echo "$node (No Ingesters)"
  fi
done

# Check for nodes with only one ingester
echo ""
echo "Nodes with Only One Ingester (Use Caution When Scaling Down):"
echo "---------------------------------------------------------"
for node in $(oc get nodes -l node-role.kubernetes.io/logging='' -o name | cut -d'/' -f2); do
  INGESTERS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-ingester" | wc -l)
  if [ $INGESTERS -eq 1 ]; then
    echo "$node (One Ingester)"
  fi
done

# Check for nodes with multiple ingesters (avoid scaling down)
echo ""
echo "Nodes with Multiple Ingesters (Avoid Scaling Down):"
echo "------------------------------------------------"
for node in $(oc get nodes -l node-role.kubernetes.io/logging='' -o name | cut -d'/' -f2); do
  INGESTERS=$(oc get pods -n openshift-logging -o wide | grep $node | grep "loki-ingester" | wc -l)
  if [ $INGESTERS -gt 1 ]; then
    echo "$node ($INGESTERS Ingesters)"
  fi
done

echo ""
echo "Recommendations:"
echo "1. Prioritize scaling down nodes without ingesters"
echo "2. If you must scale down a node with one ingester, ensure you have enough capacity on other nodes"
echo "3. Never scale down a node with multiple ingesters"
echo "4. Ensure you maintain at least 4 ingesters for your 1x medium LokiStack"
echo "5. Consider the impact on data availability and query performance"
echo ""
echo "Note: Before scaling down, ensure you have enough resources on the remaining nodes"
echo "      to handle the workload of the removed nodes." 