#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi

cd "$ORB_PARAM_DIR" || exit 1

if uname -a | grep Darwin >/dev/null 2>&1; then
    $SUDO wget -q -O chrome-for-testing.zip "https://storage.googleapis.com/chrome-for-testing-public/$ORB_PARAM_VERSION/mac-arm64/chrome-mac-arm64.zip"
    $SUDO unzip chrome-for-testing.zip >/dev/null 2>&1

    $SUDO wget -q -O chrome-for-testing-driver.zip "https://storage.googleapis.com/chrome-for-testing-public/$ORB_PARAM_VERSION/mac-arm64/chromedriver-mac-arm64.zip"
    $SUDO unzip chrome-for-testing-driver.zip >/dev/null 2>&1
    $SUDO mv chromedriver-mac-arm64/chromedriver chromedriver
elif command -v apt >/dev/null 2>&1; then
    $SUDO wget -q -O chrome-for-testing.zip "https://storage.googleapis.com/chrome-for-testing-public/$ORB_PARAM_VERSION/linux64/chrome-linux64.zip"
    $SUDO unzip chrome-for-testing.zip >/dev/null 2>&1
    $SUDO apt-get update
    while read -r pkg; do
        $SUDO apt-get satisfy -y --no-install-recommends "${pkg}";
    done < chrome-linux64/deb.deps;

    $SUDO wget -q -O chrome-for-testing-driver.zip "https://storage.googleapis.com/chrome-for-testing-public/$ORB_PARAM_VERSION/linux64/chromedriver-linux64.zip"
    $SUDO unzip chrome-for-testing-driver.zip >/dev/null 2>&1
    $SUDO mv chromedriver-linux64/chromedriver chromedriver
fi
$SUDO chmod +x chromedriver

if chromedriver --version | grep "$ORB_PARAM_VERSION" >/dev/null 2>&1; then
  echo "Chrome for testing installed correctly"
else
  echo "Error installing Chrome for testing"
  exit 1
fi
