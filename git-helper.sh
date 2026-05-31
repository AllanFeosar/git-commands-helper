#!/usr/bin/env bash
# Git Helper CLI  ─  Linux / macOS launcher
# Requires: PowerShell 7+ (pwsh)  https://github.com/PowerShell/PowerShell

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pwsh &>/dev/null; then
    echo ""
    echo "  [ERROR] pwsh (PowerShell 7+) not found."
    echo ""
    echo "  Install it:"
    echo "    macOS  : brew install --cask powershell"
    echo "    Ubuntu : https://aka.ms/install-powershell-ubuntu"
    echo "    Fedora : https://aka.ms/install-powershell-fedora"
    echo ""
    exit 1
fi

pwsh -NoLogo -File "$SCRIPT_DIR/git-helper.ps1"
