#!/bin/bash

set -e

echo "Validating Terraform templates..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Check templates directory exists
if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "❌ Error: Templates directory not found at $TEMPLATES_DIR"
    exit 1
fi

FAILED_TEMPLATES=()
VALIDATED_COUNT=0

# Process each template directory
for template_dir in "$TEMPLATES_DIR"/*; do
    if [ -d "$template_dir" ] && [ -f "$template_dir/main.tf" ]; then
        template_name=$(basename "$template_dir")
        echo ""
        echo "🔍 Validating: $template_name"
        
        # Create temporary directory for validation
        TEMP_DIR=$(mktemp -d)
        echo "   Using temp dir: $TEMP_DIR"
        
        # Copy template to temp directory
        cp -r "$template_dir"/* "$TEMP_DIR/" || {
            echo "❌ Failed to copy template files"
            rm -rf "$TEMP_DIR"
            FAILED_TEMPLATES+=("$template_name")
            continue
        }
        
        cd "$TEMP_DIR"
        
        # Initialize terraform
        echo "   Running terraform init..."
        if ! terraform init -backend=false 2>&1; then
            echo "❌ Terraform init failed for $template_name"
            cd "$SCRIPT_DIR"
            rm -rf "$TEMP_DIR"
            FAILED_TEMPLATES+=("$template_name")
            continue
        fi
        
        # Validate terraform
        echo "   Running terraform validate..."
        if terraform validate 2>&1; then
            echo "✅ $template_name - PASSED"
            ((VALIDATED_COUNT++))
        else
            echo "❌ $template_name - FAILED"
            FAILED_TEMPLATES+=("$template_name")
        fi
        
        # Cleanup
        cd "$SCRIPT_DIR"
        rm -rf "$TEMP_DIR"
    fi
done

# Summary
echo ""
echo "================================================"
echo "VALIDATION SUMMARY"
echo "================================================"
echo "Templates validated: $VALIDATED_COUNT"

if [ ${#FAILED_TEMPLATES[@]} -eq 0 ]; then
    echo "✅ ALL TEMPLATES PASSED"
    exit 0
else
    echo "❌ FAILED TEMPLATES (${#FAILED_TEMPLATES[@]}):"
    for template in "${FAILED_TEMPLATES[@]}"; do
        echo "   - $template"
    done
    exit 1
fi