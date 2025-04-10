#!/bin/bash
echo "WARNING: This might crash WSL. Save all work before proceeding."
read -p "Do you want to continue? (y/N): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    echo "Running 'make mrproper'..."
    make mrproper
    echo "Source tree cleaned."
else
    echo "Operation cancelled."
fi
