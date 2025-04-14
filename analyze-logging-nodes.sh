#!/bin/bash

set -e

echo "====================================================="
echo "COMPREHENSIVE ANALYSIS OF LOGGING NODES FOR SCALING DOWN"
echo "====================================================="
echo "This script will analyze your logging nodes to determine"
echo "which ones can be safely scaled down for ODF migration."
echo ""

# Make scripts executable
chmod +x check-logging-nodes-resources.sh
chmod +x analyze-loki-distribution.sh
chmod +x check-node-utilization.sh
chmod +x check-loki-distribution.sh

# Run all analysis scripts
echo "1. Checking allocated resources for logging nodes..."
echo "--------------------------------------------------"
./check-logging-nodes-resources.sh

echo ""
echo "2. Analyzing Loki component distribution..."
echo "----------------------------------------"
./analyze-loki-distribution.sh

echo ""
echo "3. Checking resource utilization for logging nodes..."
echo "------------------------------------------------"
./check-node-utilization.sh

echo ""
echo "4. Checking Loki distribution for 1x medium LokiStack with 4 ingesters..."
echo "-------------------------------------------------------------------"
./check-loki-distribution.sh

echo ""
echo "====================================================="
echo "SUMMARY OF FINDINGS AND RECOMMENDATIONS"
echo "====================================================="
echo "Based on the analysis above, here are the key findings:"
echo ""

# Identify potential candidates for scaling down
echo "Potential Candidates for Scaling Down:"
echo "-----------------------------------"
echo "1. Nodes with low CPU and memory utilization"
echo "2. Nodes without Loki ingesters"
echo "3. Nodes with minimal Loki components"
echo ""

# Identify nodes to avoid scaling down
echo "Nodes to Avoid Scaling Down:"
echo "-------------------------"
echo "1. Nodes with critical Loki components like compactors"
echo "2. Nodes with multiple ingesters"
echo "3. Nodes with high resource utilization"
echo ""

# Final recommendations
echo "Final Recommendations:"
echo "-------------------"
echo "1. Prioritize scaling down nodes without ingesters"
echo "2. If you must scale down a node with one ingester, ensure you have enough capacity on other nodes"
echo "3. Never scale down a node with multiple ingesters"
echo "4. Ensure you maintain at least 4 ingesters for your 1x medium LokiStack"
echo "5. Consider the impact on data availability and query performance"
echo ""
echo "Note: Before scaling down, ensure you have enough resources on the remaining nodes"
echo "      to handle the workload of the removed nodes."
echo ""
echo "====================================================="
echo "NEXT STEPS"
echo "====================================================="
echo "1. Review the analysis above to identify potential nodes for scaling down"
echo "2. Verify that scaling down these nodes won't impact your LokiStack"
echo "3. Plan the scaling down process to minimize disruption"
echo "4. After scaling down, scale up your ODF machineset with the freed resources"
echo ""
echo "For more detailed information, refer to the individual analysis sections above." 