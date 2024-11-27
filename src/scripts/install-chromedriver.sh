#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi
# determine_chrome_version
if uname -a | grep Darwin >/dev/null 2>&1; then
  echo "System detected as MacOS"

  if [ -f "/usr/local/bin/google-chrome-stable" ]; then
    CHROME_VERSION="$(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version)"
  else
    CHROME_VERSION="$(/Applications/Google\ Chrome\ Beta.app/Contents/MacOS/Google\ Chrome\ Beta --version)"
  fi

  if uname -a | grep arm64 >/dev/null 2>&1; then
    PLATFORM=mac-arm64
  else
    PLATFORM=mac-x64
  fi


elif grep Alpine /etc/issue >/dev/null 2>&1; then
  apk update >/dev/null 2>&1 &&
    apk add --no-cache chromium-chromedriver >/dev/null

  # verify version
  echo "$(chromedriver --version) has been installed to $(command -v chromedriver)"

  exit 0
else
  CHROME_VERSION="$(google-chrome --version)"
  PLATFORM=linux64
fi

CHROME_VERSION_STRING="$(echo "$CHROME_VERSION" | sed 's/.*Google Chrome //' | sed 's/.*Chromium //')"
# shellcheck disable=SC2001 
CHROME_VERSION_MAJOR="$(echo "$CHROME_VERSION_STRING" |  sed "s/\..*//" )"
echo "Chrome version major is $CHROME_VERSION_MAJOR"

# print Chrome version
echo "Installed version of Google Chrome is $CHROME_VERSION_STRING"

# determine chromedriver release
CHROMEDRIVER_RELEASE="${CHROME_VERSION_STRING%%.*}"

CHROME_RELEASE="${CHROMEDRIVER_RELEASE}"

if [[ $CHROME_RELEASE -lt 70 ]]; then
  # https://sites.google.com/a/chromium.org/chromedriver/downloads
  # https://chromedriver.storage.googleapis.com/2.40/notes.txt

  case $CHROME_RELEASE in
  69)
    CHROMEDRIVER_VERSION="2.44"
    ;;
  68)
    CHROMEDRIVER_VERSION="2.42"
    ;;
  67)
    CHROMEDRIVER_VERSION="2.41"
    ;;
  66)
    CHROMEDRIVER_VERSION="2.40"
    ;;
  65)
    CHROMEDRIVER_VERSION="2.38"
    ;;
  64)
    CHROMEDRIVER_VERSION="2.37"
    ;;
  63)
    CHROMEDRIVER_VERSION="2.36"
    ;;
  62)
    CHROMEDRIVER_VERSION="2.35"
    ;;
  61)
    CHROMEDRIVER_VERSION="2.34"
    ;;
  60)
    CHROMEDRIVER_VERSION="2.33"
    ;;
  59)
    CHROMEDRIVER_VERSION="2.32"
    ;;
  58)
    CHROMEDRIVER_VERSION="2.31"
    ;;
  57)
    CHROMEDRIVER_VERSION="2.29"
    ;;
  56)
    CHROMEDRIVER_VERSION="2.29"
    ;;
  55)
    CHROMEDRIVER_VERSION="2.28"
    ;;
  54)
    CHROMEDRIVER_VERSION="2.27"
    ;;
  53)
    CHROMEDRIVER_VERSION="2.26"
    ;;
  52)
    CHROMEDRIVER_VERSION="2.24"
    ;;
  51)
    CHROMEDRIVER_VERSION="2.23"
    ;;
  50)
    CHROMEDRIVER_VERSION="2.22"
    ;;
  49)
    CHROMEDRIVER_VERSION="2.22"
    ;;
  48)
    CHROMEDRIVER_VERSION="2.21"
    ;;
  47)
    CHROMEDRIVER_VERSION="2.21"
    ;;
  46)
    CHROMEDRIVER_VERSION="2.21"
    ;;
  45)
    CHROMEDRIVER_VERSION="2.20"
    ;;
  44)
    CHROMEDRIVER_VERSION="2.20"
    ;;
  43)
    CHROMEDRIVER_VERSION="2.20"
    ;;
  *)
    echo "Sorry, Google Chrome/Chromium version 43 or newer is required to use ChromeDriver"
    exit 1
    ;;
  esac
elif [[ $CHROME_RELEASE -lt 115 ]]; then
  CHROMEDRIVER_VERSION=$(curl --silent --show-error --location --fail --retry 3 \
    "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_$CHROMEDRIVER_RELEASE")
else
  # shellcheck disable=SC2001
  CHROMEDRIVER_VERSION=$(echo $CHROME_VERSION | sed 's/[^0-9.]//g')
fi

# installation check
if command -v chromedriver >/dev/null 2>&1; then
  if chromedriver --version | grep "$CHROMEDRIVER_VERSION" >/dev/null 2>&1; then
    echo "ChromeDriver $CHROMEDRIVER_VERSION is already installed"
    exit 0
  else
    echo "A different version of ChromeDriver is installed ($(chromedriver --version)); removing it"
    $SUDO rm -f "$(command -v chromedriver)"
  fi
fi

# download chromedriver
if [[ $CHROME_RELEASE -lt 115 ]]; then
  curl --silent --show-error --location --fail --retry 3 \
    --output chromedriver_$PLATFORM.zip \
    "http://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_$PLATFORM.zip"
else 
  MATCHING_CHROMEDRIVER_DOWNLOAD_URL=$(curl --silent https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json | jq --raw-output --arg chromeDriverVersion $CHROMEDRIVER_VERSION --arg platform $PLATFORM '.versions[] | select(.version=="\($chromeDriverVersion)") | .downloads.chromedriver[] | select(.platform=="\($platform)") | .url')
  if [ -z "${MATCHING_CHROMEDRIVER_DOWNLOAD_URL}" ]; then
    echo "Matching Chrome Driver Version URL is empty, falling back to first matching major version."
    CHROMEDRIVER_VERSION=$( curl https://googlechromelabs.github.io/chrome-for-testing/latest-versions-per-milestone.json | jq ".milestones.\"$CHROME_VERSION_MAJOR\".version" | sed 's/\"//g')
    CHROMEDRIVER_DOWNLOAD_URL=$(curl https://googlechromelabs.github.io/chrome-for-testing/latest-versions-per-milestone-with-downloads.json | jq --raw-output --arg chromeVersion $CHROME_VERSION_MAJOR --arg platform $PLATFORM '.milestones."\($chromeVersion)".downloads.chromedriver[] | select(.platform=="\($platform)") | .url')
    echo "New ChromeDriver version to be installed: $CHROMEDRIVER_VERSION"
  else
   CHROMEDRIVER_DOWNLOAD_URL=$MATCHING_CHROMEDRIVER_DOWNLOAD_URL
  fi
  echo "$CHROMEDRIVER_VERSION will be installed"

  curl --silent --show-error --location --fail --retry 3 \
    --output chromedriver_$PLATFORM.zip \
    "$CHROMEDRIVER_DOWNLOAD_URL"
fi

# setup chromedriver installation
if command -v yum >/dev/null 2>&1; then
  yum install -y unzip >/dev/null 2>&1
fi

unzip "chromedriver_$PLATFORM.zip" >/dev/null 2>&1
rm -rf "chromedriver_$PLATFORM.zip"

if [[ $CHROME_RELEASE -gt 114 ]]; then
  mv "chromedriver-$PLATFORM" chromedriver
  $SUDO mv chromedriver/chromedriver "$ORB_PARAM_DRIVER_INSTALL_DIR"
  rm -rf "chromedriver"
else
  $SUDO mv chromedriver "$ORB_PARAM_DRIVER_INSTALL_DIR"
fi


$SUDO chmod +x "$ORB_PARAM_DRIVER_INSTALL_DIR/chromedriver" 


# test/verify version
  if chromedriver --version | grep "$CHROMEDRIVER_VERSION" >/dev/null 2>&1; then
    echo "$(chromedriver --version) has been installed to $(command -v chromedriver)"
    readonly base_dir="${CIRCLE_WORKING_DIRECTORY/\~/$HOME}"
    rm -f "${base_dir}/LICENSE.chromedriver"
  else
    echo "Something went wrong; ChromeDriver could not be installed"
    exit 1
  fi
