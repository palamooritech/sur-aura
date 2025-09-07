#!/bin/bash

# Validation Script - Check for syntax errors before deployment
echo "🔍 Validating Salesforce Deprecation Scanner..."

# 1. Check if all required files exist
echo "📁 Checking file structure..."

required_files=(
    "force-app/main/default/classes/GitHubService.cls"
    "force-app/main/default/classes/DeprecationRule.cls"
    "force-app/main/default/classes/ScanResult.cls"
    "force-app/main/default/classes/ZipProcessor.cls"
    "force-app/main/default/classes/DeprecationScanner.cls"
    "force-app/main/default/classes/DeprecationScannerController.cls"
    "force-app/main/default/lwc/deprecationScanner/deprecationScanner.js"
    "force-app/main/default/lwc/deprecationScanner/deprecationScanner.html"
    "force-app/main/default/lwc/deprecationScanner/deprecationScanner.css"
    "force-app/main/default/lwc/deprecationScanner/deprecationScanner.js-meta.xml"
    "force-app/main/default/applications/DeprecationScanner.app-meta.xml"
    "force-app/main/default/tabs/Deprecation_Scanner.tab-meta.xml"
    "force-app/main/default/flexipages/DeprecationScannerApp.flexipage-meta.xml"
    "force-app/main/default/remoteSiteSettings/GitHub_API.remoteSite-meta.xml"
    "force-app/main/default/remoteSiteSettings/GitHub_Raw.remoteSite-meta.xml"
    "force-app/main/default/remoteSiteSettings/GitHub_Main.remoteSite-meta.xml"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    echo "✅ All required files found!"
else
    echo "❌ Missing files:"
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
    exit 1
fi

# 2. Basic syntax validation
echo "🔍 Running basic syntax validation..."

# Check for common Apex syntax issues
echo "   Checking Apex classes..."
grep -r "Pattern.matches" force-app/main/default/classes/ && echo "❌ Found Pattern.matches usage - should use Pattern.compile().matcher().matches()" && exit 1
grep -r "String.*=" force-app/main/default/classes/ | grep -v '\$' | grep '\n' && echo "❌ Found potential multi-line string literals" && exit 1

echo "   Checking LWC JavaScript..."
# Check for common JS issues
node -c force-app/main/default/lwc/deprecationScanner/deprecationScanner.js 2>/dev/null || echo "⚠️ JavaScript syntax check failed - make sure Node.js is installed"

echo "   Checking LWC HTML..."
# Check for ternary operators in attributes (not supported in LWC)
grep -r "?" force-app/main/default/lwc/deprecationScanner/deprecationScanner.html | grep "=" && echo "❌ Found ternary operators in HTML attributes - not supported in LWC" && exit 1

echo "✅ Basic syntax validation passed!"

# 3. Try to validate against Salesforce
echo "🚀 Validating against Salesforce org..."
sf project deploy validate --target-org deprecation-scanner-dev

if [ $? -eq 0 ]; then
    echo "✅ Salesforce validation passed!"
    echo "🎉 Ready to deploy!"
else
    echo "❌ Salesforce validation failed. Check the errors above."
    exit 1
fi