#!/bin/bash

set -e

echo "Validating Terraform templates..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
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
        echo "Validating template: $template_name"
        
        # Use temporary directory to avoid creating .terraform files in the source
        TEMP_DIR=$(mktemp -d)
        cp -r "$template_dir"/* "$TEMP_DIR/"
        cd "$TEMP_DIR"
        
        if terraform init -backend=false -get=false > /dev/null 2>&1; then
            if terraform validate > /dev/null 2>&1; then
                echo "  ✓ $template_name validation passed"
                ((VALIDATED_COUNT++))
            else
                echo "  ✗ $template_name validation failed"
                terraform validate
                FAILED_TEMPLATES+=("$template_name")
            fi
        else
            echo "  ✗ $template_name terraform init failed"
            terraform init -backend=false -get=false
            FAILED_TEMPLATES+=("$template_name")
        fi
        
        cd "$SCRIPT_DIR"
        rm -rf "$TEMP_DIR"
    fi
done

echo ""
echo "Validation Summary:"
echo "  Templates validated: $VALIDATED_COUNT"

if [ ${#FAILED_TEMPLATES[@]} -eq 0 ]; then
    echo "  ✓ All templates passed validation"
    exit 0
else
    echo "  ✗ Failed templates: ${#FAILED_TEMPLATES[@]}"
    for template in "${FAILED_TEMPLATES[@]}"; do
        echo "    - $template"
    done
    exit 1
fi