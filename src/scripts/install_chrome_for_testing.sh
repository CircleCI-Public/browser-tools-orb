#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi

retry() {
    local -r -i max_attempts=5
    local -i attempt_num=1

    until "$@"; do
        if (( attempt_num == max_attempts )); then
            echo "Attempt $attempt_num failed and there are no more attempts left!"
            exit 1
        else
            echo "Attempt $attempt_num failed! Trying again..."
            ((attempt_num++))
            $SUDO rm -rf /var/lib/apt/lists/*
            sleep 5
        fi
    done
}

cd "$ORB_PARAM_DIR" || { echo "$ORB_PARAM_DIR does not exist. Exiting"; exit 1; }

# process ORB_PARAM_VERSION
if command -v circleci &>/dev/null; then
  # CircleCI is installed, proceed with substitution
  PROCESSED_CHROME_VERSION=$(circleci env subst "$ORB_PARAM_VERSION")
else
  # CircleCI is not installed, fallback to using the environment variable as-is
  echo "CircleCI CLI is not installed. Relying on the environment variable ORB_PARAM_VERSION to be set manually."
  PROCESSED_CHROME_VERSION=${ORB_PARAM_VERSION:-latest} # Default to "latest" if the variable is unset
fi

if uname -a | grep Darwin >/dev/null 2>&1; then
    if [[ "$PROCESSED_CHROME_VERSION" == "latest" ]]; then
      LATEST_VERSION="$(curl -s 'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json' | jq -r '.channels.Stable.version')"
      target_version="$LATEST_VERSION"
    else
      target_version="$PROCESSED_CHROME_VERSION"
    fi

    $SUDO curl -s -o chrome-for-testing.zip "https://storage.googleapis.com/chrome-for-testing-public/$target_version/mac-arm64/chrome-mac-arm64.zip"
    if [ -s "chrome-for-testing.zip" ]; then
        $SUDO unzip chrome-for-testing.zip >/dev/null
        $SUDO rm chrome-for-testing.zip
        $SUDO mv ./chrome-mac-arm64 /opt/chrome-for-testing
        # leveraging /opt instead of /Applications/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing as this should be temporary
        $SUDO ln -fs /opt/chrome-for-testing/chrome "$ORB_PARAM_DIR/chrome"
    else
        echo "Version $target_version doesn't exist"
        #exit 1
    fi

    if [ "$ORB_PARAM_INSTALL_CHROMEDRIVER" = true ] ; then
        $SUDO curl -s -o chrome-for-testing-driver.zip "https://storage.googleapis.com/chrome-for-testing-public/$target_version/mac-arm64/chromedriver-mac-arm64.zip"
        $SUDO unzip chrome-for-testing-driver.zip >/dev/null 2>&1
        $SUDO rm chrome-for-testing-driver.zip
        $SUDO mv chromedriver-mac-arm64/chromedriver chromedriver
    fi
elif command -v apt >/dev/null 2>&1; then
    if [[ "$PROCESSED_CHROME_VERSION" == "latest" ]]; then
      LATEST_VERSION="$(curl -s 'https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions.json' | jq -r '.channels.Stable.version')"
      target_version="$LATEST_VERSION"
    else
      target_version="$PROCESSED_CHROME_VERSION"
    fi

    $SUDO curl -s -o chrome-for-testing.zip "https://storage.googleapis.com/chrome-for-testing-public/$target_version/linux64/chrome-linux64.zip"
    if [ -s "chrome-for-testing.zip" ]; then
        $SUDO unzip chrome-for-testing.zip >/dev/null 2>&1
        $SUDO rm chrome-for-testing.zip
        $SUDO mv ./chrome-linux64 /opt/chrome-for-testing
        $SUDO ln -fs /opt/chrome-for-testing/chrome "$ORB_PARAM_DIR/chrome"
    else
        echo "Version $target_version doesn't exist"
        exit 1
    fi

    retry $SUDO apt-get update
    $SUDO chmod +r /opt/chrome-for-testing/deb.deps
    while read -r pkg; do
        $SUDO apt-get satisfy -y --no-install-recommends "${pkg}";
    done < /opt/chrome-for-testing/deb.deps;

    if [ "$ORB_PARAM_INSTALL_CHROMEDRIVER" = true ] ; then
        $SUDO curl -s -o chrome-for-testing-driver.zip "https://storage.googleapis.com/chrome-for-testing-public/$target_version/linux64/chromedriver-linux64.zip"
        $SUDO unzip chrome-for-testing-driver.zip >/dev/null 2>&1
        $SUDO rm chrome-for-testing-driver.zip
        $SUDO mv chromedriver-linux64/chromedriver chromedriver
    fi
fi

if [ "$ORB_PARAM_INSTALL_CHROMEDRIVER" = true ] ; then
    $SUDO chmod +x chromedriver
fi

if [ "$ORB_PARAM_INSTALL_CHROMEDRIVER" = true ] ; then
    if chromedriver --version | grep "$target_version" >/dev/null 2>&1; then
        echo "chromedriver for Chrome for testing installed correctly"
    else
        echo "Error installing Chrome for testing"
        exit 1
    fi
fi
