#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi

if ! command -v microsoft-edge >/dev/null 2>&1; then
  echo "Microsoft Edge is not installed"
  exit 1
fi

if uname -a | grep Darwin >/dev/null 2>&1; then
  PLATFORM=mac64_m1
else
  PLATFORM=linux64
fi

VERSION=$(microsoft-edge --version | awk '{print $3}')

wget -q -O edgedriver.zip "https://msedgedriver.azureedge.net/$VERSION/edgedriver_$PLATFORM.zip"
unzip edgedriver.zip >/dev/null 2>&1
$SUDO mv msedgedriver "$ORB_PARAM_DRIVER_INSTALL_DIR"
rm -rf edgedriver.zip Driver_Notes

$SUDO chmod +x "$ORB_PARAM_DRIVER_INSTALL_DIR/msedgedriver"

if "$ORB_PARAM_DRIVER_INSTALL_DIR/msedgedriver" --version | grep "$VERSION" >/dev/null 2>&1; then
  echo "Edge Web Driver installed correctly"
else
  echo "Error installing Edge Web Driver"
  exit 1
fi
