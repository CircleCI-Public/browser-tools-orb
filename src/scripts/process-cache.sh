if [ -f "chrome.tar.gz" ]; then
    $SUDO mkdir -p /opt/google/chrome
    $SUDO tar -xzf /tmp/chrome.tar.gz -C /opt/google/chrome
    $SUDO rm -rf /tmp/chrome.tar.gz
fi
