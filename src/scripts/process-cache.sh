if [ -f "chrome.tar.gz" ]; then
    $SUDO tar -xzf chrome.tar.gz -C /
    $SUDO rm -rf chrome.tar.gz
fi