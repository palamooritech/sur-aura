#!/bin/bash

# Configuration - Change these variables as needed
TARGET_ORG="${1:-myDevHub}"  # Use first argument or default to myDevHub
CREATE_SCRATCH="${2:-false}" # Use second argument or default to false
SCRATCH_DURATION=30

echo "🚀 Deploying Fixed Salesforce Deprecation Scanner..."
echo "📍 Target org: $TARGET_ORG"

# Function to deploy to existing org
deploy_to_existing_org() {
    echo "📤 Deploying to existing org: $TARGET_ORG..."
    sf project deploy start --target-org $TARGET_ORG --ignore-warnings --ignore-conflicts
}

# Function to create and deploy to scratch org
deploy_to_scratch_org() {
    echo "📱 Checking if scratch org exists..."
    sf org display --target-org $TARGET_ORG > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "📱 Creating new scratch org: $TARGET_ORG..."
        sf org create scratch --definition-file config/project-scratch-def.json --alias $TARGET_ORG --set-default --duration-days $SCRATCH_DURATION
    else
        echo "✅ Scratch org $TARGET_ORG already exists"
    fi
    
    echo "📤 Deploying to scratch org: $TARGET_ORG..."
    sf project deploy start --target-org $TARGET_ORG --ignore-warnings --ignore-conflicts
}

# Determine deployment strategy
if [ "$CREATE_SCRATCH" = "true" ] || [ "$TARGET_ORG" = "deprecation-scanner-dev" ]; then
    deploy_to_scratch_org
else
    deploy_to_existing_org
fi

# Check deployment result
if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    echo "🌍 Opening org..."
    sf org open --target-org $TARGET_ORG --path "/lightning/app/c__DeprecationScanner"
    echo "🎉 Done! Check the app in the browser."
else
    echo "❌ Deployment failed. Let's check the specific errors:"
    sf project deploy start --target-org $TARGET_ORG --dry-run
fi