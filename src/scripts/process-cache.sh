#!/bin/bash
set -x
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi
if [ -f "/tmp/chrome.tar.gz" ]; then
    $SUDO mkdir -p /opt/google/chrome
    $SUDO tar -xzf /tmp/chrome.tar.gz -C /opt/google/chrome
    $SUDO rm -rf /tmp/chrome.tar.gz
    $SUDO ln -s /opt/google/chrome/google-chrome "/usr/bin/google-chrome-$ORB_PARAM_CHANNEL"
    google-chrome-$ORB_PARAM_CHANNEL --version
fi
set +x
