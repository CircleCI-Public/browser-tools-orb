#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi

if uname -a | grep Darwin >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "You need brew to install Edge on MacOS"
    exit 1
  fi
  brew install --cask microsoft-edge
elif command -v apt >/dev/null 2>&1; then
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-archive-keyring.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/edge stable main" | sudo tee /etc/apt/sources.list.d/microsoft-edge-stable.list
  if [ "$ORB_PARAM_VERSION" != "latest" ]; then
    VERSION="=$ORB_PARAM_VERSION-1"
  fi
  $SUDO apt-get update
  $SUDO apt-get install -y "microsoft-edge-stable$VERSION"
fi

if command -v microsoft-edge >/dev/null 2>&1; then
  echo "Microsoft Edge version $(microsoft-edge --version) was installed."
else
  echo "Microsoft Edge could not be installed"
  exit 1
fi
