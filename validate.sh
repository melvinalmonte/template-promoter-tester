#!/bin/bash

set -e

echo "Validating Terraform templates..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [ ! -d "$TEMPLATES_DIR" ]; then
    echo "Error: Templates directory not found at $TEMPLATES_DIR"
    exit 1
fi

FAILED_TEMPLATES=()
VALIDATED_COUNT=0

for template_dir in "$TEMPLATES_DIR"/*; do
    if [ -d "$template_dir" ] && [ -f "$template_dir/main.tf" ]; then
        template_name=$(basename "$template_dir")
        echo "Checking template: $template_name"
        
        cd "$template_dir"
        
        if terraform fmt -check=true -diff=false > /dev/null 2>&1; then
            echo "  ✓ $template_name syntax check passed"
            ((VALIDATED_COUNT++))
        else
            echo "  ✗ $template_name syntax check failed"
            terraform fmt -check=true -diff=true
            FAILED_TEMPLATES+=("$template_name")
        fi
        
        cd "$SCRIPT_DIR"
    fi
done

echo ""
echo "Validation Summary:"
echo "  Templates checked: $VALIDATED_COUNT"

if [ ${#FAILED_TEMPLATES[@]} -eq 0 ]; then
    echo "  ✓ All templates passed"
    exit 0
else
    echo "  ✗ Failed templates: ${#FAILED_TEMPLATES[@]}"
    for template in "${FAILED_TEMPLATES[@]}"; do
        echo "    - $template"
    done
    exit 1
fi