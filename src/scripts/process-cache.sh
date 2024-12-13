#!/bin/bash
set -x
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi
if [ -f "/tmp/chrome.tar.gz" ]; then
    if uname -a | grep Darwin >/dev/null 2>&1; then
        $SUDO tar -xzf /tmp/chrome.tar.gz -C /tmp
    elif command -v apt-get >/dev/null 2>&1; then
        $SUDO mkdir -p /opt/google/chrome
        $SUDO tar -xzf /tmp/chrome.tar.gz -C /opt/google/chrome
        $SUDO rm -rf /tmp/chrome.tar.gz
        $SUDO ln -s /opt/google/chrome/google-chrome "/usr/bin/google-chrome-$ORB_PARAM_CHANNEL"
        $SUDO ln -s "/usr/bin/google-chrome-$ORB_PARAM_CHANNEL" "/etc/alternatives/google-chrome"
        $SUDO ln -s "/etc/alternatives/google-chrome" "/usr/bin/google-chrome"
    else
        echo "This system doesn't support cache for chrome"
        $SUDO rm -rf /tmp/chrome.tar.gz
    fi
fi
set +x
