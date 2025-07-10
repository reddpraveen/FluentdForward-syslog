#!/bin/bash

set -e

# Create output directory if it doesn't exist
OUTPUT_DIR="logging-analysis-$(date +%Y%m%d-%H%M%S)"
mkdir -p $OUTPUT_DIR

# Function to log output to both screen and file
log_output() {
  echo "$1" | tee -a "$OUTPUT_DIR/analysis.log"
}

log_output "====================================================="
log_output "COMPREHENSIVE ANALYSIS OF LOGGING NODES FOR SCALING DOWN"
log_output "====================================================="
log_output "This script will analyze your logging nodes to determine"
log_output "which ones can be safely scaled down for ODF migration."
log_output "Output is being saved to: $OUTPUT_DIR/analysis.log"
log_output ""

# Make scripts executable
chmod +x check-logging-nodes-resources.sh
chmod +x analyze-loki-distribution.sh
chmod +x check-node-utilization.sh
chmod +x check-loki-distribution.sh

# Run all analysis scripts
log_output "1. Checking allocated resources for logging nodes..."
log_output "--------------------------------------------------"
./check-logging-nodes-resources.sh | tee -a "$OUTPUT_DIR/resources.log"

log_output ""
log_output "2. Analyzing Loki component distribution..."
log_output "----------------------------------------"
./analyze-loki-distribution.sh | tee -a "$OUTPUT_DIR/distribution.log"

log_output ""
log_output "3. Checking resource utilization for logging nodes..."
log_output "------------------------------------------------"
./check-node-utilization.sh | tee -a "$OUTPUT_DIR/utilization.log"

log_output ""
log_output "4. Checking Loki distribution for 1x medium LokiStack with 4 ingesters..."
log_output "-------------------------------------------------------------------"
./check-loki-distribution.sh | tee -a "$OUTPUT_DIR/loki-distribution.log"

log_output ""
log_output "====================================================="
log_output "SUMMARY OF FINDINGS AND RECOMMENDATIONS"
log_output "====================================================="
log_output "Based on the analysis above, here are the key findings:"
log_output ""

# Identify potential candidates for scaling down
log_output "Potential Candidates for Scaling Down:"
log_output "-----------------------------------"
log_output "1. Nodes with low CPU and memory utilization"
log_output "2. Nodes without Loki ingesters"
log_output "3. Nodes with minimal Loki components"
log_output ""

# Identify nodes to avoid scaling down
log_output "Nodes to Avoid Scaling Down:"
log_output "-------------------------"
log_output "1. Nodes with critical Loki components like compactors"
log_output "2. Nodes with multiple ingesters"
log_output "3. Nodes with high resource utilization"
log_output ""

# Final recommendations
log_output "Final Recommendations:"
log_output "-------------------"
log_output "1. Prioritize scaling down nodes without ingesters"
log_output "2. If you must scale down a node with one ingester, ensure you have enough capacity on other nodes"
log_output "3. Never scale down a node with multiple ingesters"
log_output "4. Ensure you maintain at least 4 ingesters for your 1x medium LokiStack"
log_output "5. Consider the impact on data availability and query performance"
log_output ""
log_output "Note: Before scaling down, ensure you have enough resources on the remaining nodes"
log_output "      to handle the workload of the removed nodes."
log_output ""
log_output "====================================================="
log_output "NEXT STEPS"
log_output "====================================================="
log_output "1. Review the analysis above to identify potential nodes for scaling down"
log_output "2. Verify that scaling down these nodes won't impact your LokiStack"
log_output "3. Plan the scaling down process to minimize disruption"
log_output "4. After scaling down, scale up your ODF machineset with the freed resources"
log_output ""
log_output "For more detailed information, refer to the individual analysis sections above."
log_output ""
log_output "Analysis complete. Results saved to: $OUTPUT_DIR/analysis.log"
log_output "Individual component logs saved to:"
log_output "  - $OUTPUT_DIR/resources.log"
log_output "  - $OUTPUT_DIR/distribution.log"
log_output "  - $OUTPUT_DIR/utilization.log"
log_output "  - $OUTPUT_DIR/loki-distribution.log" 