# My Second Custom Template

This template creates a development workspace with:
- Ubuntu-based environment
- Persistent home directory
- VS Code (web-based)
- Web terminal
- Configurable CPU, memory, and disk size
- Optional dotfiles repository support

## Parameters

- **CPU Cores**: Number of CPU cores (1-8)
- **Memory**: RAM in GB (1-16)
- **Disk Size**: Home directory size in GB (1-100)
- **Dotfiles Repository**: Optional Git URL for your dotfiles

## What's Included

- Ubuntu 20.04 base image
- Common development tools (git, curl, wget, vim)
- VS Code Server for web-based editing
- Persistent storage for your files

## Customization

To add more tools, edit the startup script in `main.tf`.