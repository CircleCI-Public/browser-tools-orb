#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi

cd "$ORB_PARAM_DIR" || { echo "$ORB_PARAM_DIR does not exist. Exiting"; exit 1; }

if [ -z "$ORB_PARAM_VERSION" ]; then
    echo "ORB_PARAM_VERSION is not set. Exiting."
    exit 1
fi

if uname -a | grep Darwin >/dev/null 2>&1; then
    $SUDO curl -s -o chrome-for-testing.zip "https://storage.googleapis.com/chrome-for-testing-public/$ORB_PARAM_VERSION/mac-arm64/chrome-mac-arm64.zip"
    if [ -s "chrome-for-testing.zip" ]; then
        $SUDO unzip chrome-for-testing.zip >/dev/null 2>&1
    else
        echo "Version $ORB_PARAM_VERSION doesn't exist"
        exit 1
    fi

    if [ "$ORB_PARAM_INSTALL_CHROMEDRIVER" = true ] ; then
        $SUDO curl -s -o chrome-for-testing-driver.zip "https://storage.googleapis.com/chrome-for-testing-public/$ORB_PARAM_VERSION/mac-arm64/chromedriver-mac-arm64.zip"
        $SUDO unzip chrome-for-testing-driver.zip >/dev/null 2>&1
        $SUDO mv chromedriver-mac-arm64/chromedriver chromedriver
    fi
elif command -v apt >/dev/null 2>&1; then
    $SUDO curl -s -o chrome-for-testing.zip "https://storage.googleapis.com/chrome-for-testing-public/$ORB_PARAM_VERSION/linux64/chrome-linux64.zip"
    if [ -s "chrome-for-testing.zip" ]; then
        $SUDO unzip chrome-for-testing.zip >/dev/null 2>&1
    else
        echo "Version $ORB_PARAM_VERSION doesn't exist"
        exit 1
    fi
    $SUDO apt-get update
    while read -r pkg; do
        $SUDO apt-get satisfy -y --no-install-recommends "${pkg}";
    done < chrome-linux64/deb.deps;

    if [ "$ORB_PARAM_INSTALL_CHROMEDRIVER" = true ] ; then
        $SUDO curl -s -o chrome-for-testing-driver.zip "https://storage.googleapis.com/chrome-for-testing-public/$ORB_PARAM_VERSION/linux64/chromedriver-linux64.zip"
        $SUDO unzip chrome-for-testing-driver.zip >/dev/null 2>&1
        $SUDO mv chromedriver-linux64/chromedriver chromedriver
    fi
fi

if [ "$ORB_PARAM_INSTALL_CHROMEDRIVER" = true ] ; then
    $SUDO chmod +x chromedriver
fi

if [ "$ORB_PARAM_INSTALL_CHROMEDRIVER" = true ] ; then
    if chromedriver --version | grep "$ORB_PARAM_VERSION" >/dev/null 2>&1; then
        echo "chromedriver for Chrome for testing installed correctly"
    else
        echo "Error installing Chrome for testing"
        exit 1
    fi
fi