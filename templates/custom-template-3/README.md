# Dummy Testing Template 3

A lightweight template for testing Coder deployments without requiring real infrastructure.

## Overview

This template creates a "dummy" workspace that simulates resources without actually provisioning any infrastructure. It's perfect for:

- Testing Coder deployments
- Template development and debugging
- CI/CD pipelines
- Learning Coder without infrastructure costs

## How It Works

1. **No Real Infrastructure**: Uses Terraform's `null` and `local` providers
2. **Simulated Resources**: Creates dummy state files and logs to simulate activity
3. **Full Coder Integration**: Works with all Coder features (parameters, apps, metadata)
4. **Zero Cost**: No cloud resources are created

## Features

- ✅ Configurable parameters (CPU, memory, disk)
- ✅ Coder apps (VS Code, Terminal, Status page)
- ✅ Workspace metadata display
- ✅ Dotfiles support (simulated)
- ✅ Start/stop lifecycle
- ✅ Agent connectivity

## What's Simulated

- **Container ID**: Generated from workspace name
- **IP Address**: Static dummy IP
- **Resource Usage**: Displayed but not enforced
- **Storage**: State file in `/tmp`
- **Apps**: URLs point to localhost (won't actually work)

## Parameters

All standard parameters are available:
- CPU cores (1-8)
- Memory (1-16 GB)
- Disk size (1-100 GB)
- Dotfiles repository URL

## Usage

1. Deploy via template-promoter or manually:
   ```bash
   coder template create dummy-test
   ```

2. Create a workspace:
   ```bash
   coder create my-dummy --template dummy-test
   ```

3. Check the logs to see simulated activity:
   ```bash
   coder logs my-dummy
   ```

## Limitations

- Apps (VS Code, Terminal) won't actually connect
- No real compute resources
- State files are temporary
- No actual file persistence

## Perfect For

- 🧪 Testing template syntax
- 🔧 Debugging Coder configurations
- 📚 Learning Coder concepts
- 🚀 Quick demos
- 🔄 CI/CD testing 