if [ -f "chrome.tar.gz" ]; then
    $SUDO mkdir -p /opt/google/chrome
    $SUDO tar -xzf chrome.tar.gz -C /opt/google/chrome
    $SUDO rm -rf chrome.tar.gz
fi