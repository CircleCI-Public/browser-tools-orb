#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi
# FUNCTIONS
grab_geckodriver_version () {
  if [[ "$ORB_PARAM_GECKO_VERSION" == "latest" ]]; then
    # extract latest version from github releases API
    GECKODRIVER_VERSION_STRING=$(curl -Ls -o /dev/null -w "%{url_effective}\n" "https://github.com/mozilla/geckodriver/releases/latest" | sed 's:.*/::')

    # strip leading/trailing "
    temp="${GECKODRIVER_VERSION_STRING%\"}"
    GECKODRIVER_VERSION="${temp#\"}"
  else
    GECKODRIVER_VERSION="$ORB_PARAM_GECKO_VERSION"
  fi

  echo "Selected version of Geckodriver is: $GECKODRIVER_VERSION"
}

installation_check () {
  if command -v geckodriver >> /dev/null 2>&1; then
    if geckodriver --version | grep "$GECKODRIVER_VERSION" >> /dev/null 2>&1; then
      echo "Geckodriver $GECKODRIVER_VERSION is already installed"
      exit 0
    else
      echo "A different version of Geckodriver is installed ($(geckodriver --version)); removing it"
      $SUDO rm -rf $(command -v geckodriver)
    fi
  else
    echo "Geckodriver is not currently installed; installing it"
  fi
}

grab_geckodriver_version
installation_check

if uname -a | grep Darwin >> /dev/null 2>&1; then
  PLATFORM=macos
else
  PLATFORM=linux64
fi

# get download URL
GECKODRIVER_URL="https://github.com/mozilla/geckodriver/releases/download/$GECKODRIVER_VERSION/geckodriver-$GECKODRIVER_VERSION-$PLATFORM.tar.gz"

# download geckodriver
$SUDO curl --silent --show-error --location --fail --retry 3 --output "geckodriver-$GECKODRIVER_VERSION-$PLATFORM.tar.gz" "$GECKODRIVER_URL"

# setup geckodriver installation
$SUDO tar xf "geckodriver-$GECKODRIVER_VERSION-$PLATFORM.tar.gz"
$SUDO rm -rf "geckodriver-$GECKODRIVER_VERSION-$PLATFORM.tar.gz"

$SUDO mv geckodriver "$ORB_PARAM_GECKO_INSTALL_DIR"
$SUDO chmod +x "$ORB_PARAM_GECKO_INSTALL_DIR/geckodriver"

# verify version
echo "Geckodriver has been installed to $(which geckodriver)"
geckodriver --version

# test/verify version

GECKODRIVER_VERSION_NUM="$(echo $GECKODRIVER_VERSION | sed -E 's/v//')"

if geckodriver --version | grep "$GECKODRIVER_VERSION_NUM" > /dev/null 2>&1; then
  echo "$(geckodriver --version) has been installed to $(which geckodriver)"
else
  echo "Something went wrong; the specified version of Geckodriver could not be installed"
  exit 1
fi
