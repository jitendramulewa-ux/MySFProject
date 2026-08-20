#!/bin/bash
# Deployment script for KAN-1: Create new fields on Account Object
# This script deploys the custom fields to a Salesforce org

echo "=================================="
echo "Deploying KAN-1 User Story"
echo "Adding custom fields to Account object"
echo "=================================="
echo ""

# Deploy metadata using SFDX CLI
echo "Deploying Account custom fields..."
sf project deploy start --source-dir force-app/main/default/objects/Account/

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Deployment successful!"
    echo ""
    echo "Custom fields created:"
    echo "  1. Account_Summary__c (Long Text Area)"
    echo "  2. Account_Budget__c (Currency)"
    echo ""
    echo "These fields can now be used in:"
    echo "  - Flows"
    echo "  - Apex code"
    echo "  - Page layouts"
    echo "  - Reports and Dashboards"
else
    echo ""
    echo "❌ Deployment failed!"
    echo "Please check the error messages above"
    exit 1
fi
