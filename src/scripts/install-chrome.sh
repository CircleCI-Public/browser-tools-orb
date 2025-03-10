#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi

# process ORB_PARAM_CHROME_VERSION
if command -v circleci &>/dev/null; then
  # CircleCI is installed, proceed with substitution
  PROCESSED_CHROME_VERSION=$(circleci env subst "$ORB_PARAM_CHROME_VERSION")
else
  # CircleCI is not installed, fallback to using the environment variable as-is
  echo "CircleCI CLI is not installed. Relying on the environment variable ORB_PARAM_CHROME_VERSION to be set manually."
  PROCESSED_CHROME_VERSION=${ORB_PARAM_CHROME_VERSION:-latest} # Default to "latest" if the variable is unset
fi

save_cache() {
  echo "Saving cache"
  if uname -a | grep Darwin >/dev/null 2>&1; then
    $SUDO tar -czf /tmp/chrome.tar.gz -C "$CHROME_TEMP_DIR" googlechrome.pkg
  elif command -v apt-get >/dev/null 2>&1; then
    $SUDO tar -czf /tmp/chrome.tar.gz -C /opt/google/chrome .
  else
    echo "This system doesn't support cache for chrome"
  fi
}

# installation check
if uname -a | grep Darwin >/dev/null 2>&1; then
  if ls /Applications/*Google\ Chrome* >/dev/null 2>&1; then
    if [[ "$PROCESSED_CHROME_VERSION" == "latest" ]]; then
      LATEST_VERSION="$(curl -s 'https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Mac' | jq -r ' .[0] | .version ')"
      target_version="$LATEST_VERSION"
    else
      target_version="$PROCESSED_CHROME_VERSION"
    fi
    installed_version="$(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version)"

    if [ "$ORB_PARAM_REPLACE_EXISTING" == "1" ] && [ "$installed_version" != "$target_version" ]; then
      echo "$installed_version is currently installed; replacing it"
      HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall google-chrome >/dev/null 2>&1 || true
      $SUDO rm -rf /Applications/Google\ Chrome.app >/dev/null 2>&1 || true
    else
      echo "$installed_version is already installed"
      exit 0
    fi
  else
    echo "Google Chrome is not currently installed; installing it"
  fi
elif grep Alpine /etc/issue >/dev/null 2>&1; then
  if command -v chromium-browser >/dev/null 2>&1; then
    if [[ "$PROCESSED_CHROME_VERSION" == "latest" ]]; then
      LATEST_VERSION="$(curl -s 'https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Linux' | jq -r ' .[0] | .version ')"
      target_version="$LATEST_VERSION"
    else
      target_version="$PROCESSED_CHROME_VERSION"
    fi
    installed_version="$(chromium-browser --version)"

    if [ "$ORB_PARAM_REPLACE_EXISTING" == "1" ] && [ "$installed_version" != "$target_version" ]; then
      echo "$installed_version is currently installed; replacing it"
      $SUDO apk del --force-broken-world chromium >/dev/null 2>&1 || true
      $SUDO rm -f "$(command -v chromium-browser)" >/dev/null 2>&1 || true
    else
      echo "$installed_version is already installed to $(command -v chromium-browser)"
      exit 0
    fi
  else
    echo "Google Chrome (via Chromium) is not currently installed; installing it"
  fi
elif command -v yum >/dev/null 2>&1; then
  if command -v google-chrome >/dev/null 2>&1; then
    if [[ "$PROCESSED_CHROME_VERSION" == "latest" ]]; then
      LATEST_VERSION="$(curl -s 'https://chromiumdash.appspot.com/fetch_releases?channel=Stable&platform=Linux' | jq -r ' .[0] | .version ')"
      target_version="$LATEST_VERSION"
    else
      target_version="$PROCESSED_CHROME_VERSION"
    fi
    installed_version="$(google-chrome --version)"

    if [ "$ORB_PARAM_REPLACE_EXISTING" == "1" ] && [ "$installed_version" != "$target_version" ]; then
      echo "$installed_version is currently installed; replacing it"
      $SUDO yum remove -y google-chrome-stable >/dev/null 2>&1 || true
      $SUDO rm -f "$(command -v google-chrome)" >/dev/null 2>&1 || true
    else
      echo "$installed_version is already installed to $(command -v google-chrome)"
      exit 0
    fi
  else
    echo "Google Chrome is not currently installed; installing it"
  fi
else
  if command -v google-chrome >/dev/null 2>&1; then
    if [ "$ORB_PARAM_REPLACE_EXISTING" == "1" ]; then
      echo "$(google-chrome --version)is currently installed; replacing it"
      $SUDO apt-get -y --purge remove google-chrome-stable >/dev/null 2>&1 || true
      $SUDO rm -f "$(command -v google-chrome)" >/dev/null 2>&1 || true
    else
      echo "$(google-chrome --version)is already installed to $(command -v google-chrome)"
      exit 0
    fi
  else
    echo "Google Chrome is not currently installed; installing it"
  fi
fi

# install chrome
if uname -a | grep Darwin >/dev/null 2>&1; then
  echo "Preparing Chrome installation for MacOS-based systems"
  # Universal MacOS .pkg with license pre-accepted: https://support.google.com/chrome/a/answer/9915669?hl=en
  CHROME_TEMP_DIR="$(mktemp -d)"
  if [ "$ORB_PARAM_SAVE_CACHE" = 1 ] && [ -f "/tmp/googlechrome.pkg" ]; then
    echo "Cache found."
    cp /tmp/googlechrome.pkg "$CHROME_TEMP_DIR"
  else
    CHROME_MAC_URL="https://dl.google.com/chrome/mac/${ORB_PARAM_CHANNEL}/accept_tos%3Dhttps%253A%252F%252Fwww.google.com%252Fintl%252Fen_ph%252Fchrome%252Fterms%252F%26_and_accept_tos%3Dhttps%253A%252F%252Fpolicies.google.com%252Fterms/googlechrome.pkg"
    curl -L -o "$CHROME_TEMP_DIR/googlechrome.pkg" "$CHROME_MAC_URL"
  fi
  sudo /usr/sbin/installer -pkg "$CHROME_TEMP_DIR/googlechrome.pkg" -target /
  if [ "$ORB_PARAM_SAVE_CACHE" = 1 ]; then
    save_cache
  fi
  sudo rm -rf "$CHROME_TEMP_DIR"
  echo '#!/usr/bin/env bash' >> google-chrome-$ORB_PARAM_CHANNEL
  if [[ $ORB_PARAM_CHANNEL == "beta" ]]; then
    xattr -rc "/Applications/Google Chrome Beta.app"
    echo '/Applications/Google\ Chrome\ Beta.app/Contents/MacOS/Google\ Chrome\ Beta "$@"' >> google-chrome-$ORB_PARAM_CHANNEL
  else
    xattr -rc "/Applications/Google Chrome.app"
    echo '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome "$@"' >> google-chrome-$ORB_PARAM_CHANNEL
  fi
  sudo mv google-chrome-$ORB_PARAM_CHANNEL /usr/local/bin/
  sudo chmod +x /usr/local/bin/google-chrome-$ORB_PARAM_CHANNEL
  # test/verify installation
  if google-chrome-$ORB_PARAM_CHANNEL --version >/dev/null 2>&1; then
    echo "$(google-chrome-$ORB_PARAM_CHANNEL --version)has been installed in the /Applications directory"
    echo "A shortcut has also been created at $(command -v google-chrome)"
    exit 0
  else
    echo "The latest release of Google Chrome (${ORB_PARAM_CHANNEL}) failed to install."
    exit 1
  fi
elif command -v yum >/dev/null 2>&1; then
  echo "Preparing Chrome installation for RedHat-based systems"
  # download chrome
  if [[ "$PROCESSED_CHROME_VERSION" == "latest" ]]; then
    CHROME_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
  else
    CHROME_URL="https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome-${ORB_PARAM_CHANNEL}-$PROCESSED_CHROME_VERSION-1.x86_64.rpm"
  fi
  curl --silent --show-error --location --fail --retry 3 \
    --output google-chrome.rpm \
    "$CHROME_URL"
  curl --silent --show-error --location --fail --retry 3 \
    --output liberation-fonts.rpm \
    http://mirror.centos.org/centos/7/os/x86_64/Packages/liberation-fonts-1.07.2-16.el7.noarch.rpm
  $SUDO yum localinstall -y liberation-fonts.rpm \
    >/dev/null 2>&1
  $SUDO yum localinstall -y google-chrome.rpm \
    >/dev/null 2>&1
  if [ "$ORB_PARAM_SAVE_CACHE" = 1 ]; then
    save_cache
  fi
  rm -rf google-chrome.rpm liberation-fonts.rpm
else
  # download chrome
  echo "Preparing Chrome installation for Debian-based systems"
  if [[ "$PROCESSED_CHROME_VERSION" == "latest" ]]; then
    ENV_IS_ARM=$(! dpkg --print-architecture | grep -q arm; echo $?)
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | $SUDO apt-key add -
    if [ "$ENV_IS_ARM" == "arm" ]; then
      echo "Installing Chrome for ARM64"
      $SUDO sh -c 'echo "deb [arch=arm64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
    else
      echo "Installing Chrome for AMD64"
      $SUDO sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
    fi
    $SUDO apt-get update
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y google-chrome-${ORB_PARAM_CHANNEL}
  else
    # Google does not keep older releases in their PPA, but they can be installed manually. HTTPS should be enough to secure the download.
    $SUDO apt-get update
    wget --no-verbose -O /tmp/chrome.deb "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-${ORB_PARAM_CHANNEL}/google-chrome-${ORB_PARAM_CHANNEL}_${ORB_PARAM_CHROME_VERSION}-1_amd64.deb" \
      && $SUDO apt-get install -y apt-utils && $SUDO apt-get install -y /tmp/chrome.deb \
      && rm /tmp/chrome.deb
  fi
  if [ "$ORB_PARAM_SAVE_CACHE" = 1 ]; then
    save_cache
  fi
fi

TESTING_CHROME_VERSION=${PROCESSED_CHROME_VERSION::-2}
# test/verify installation
if [[ "$PROCESSED_CHROME_VERSION" != "latest" ]]; then
  if google-chrome-$ORB_PARAM_CHANNEL --version | grep "$PROCESSED_CHROME_VERSION" >/dev/null 2>&1; then
    :
  elif google-chrome-$ORB_PARAM_CHANNEL --version | grep "$TESTING_CHROME_VERSION" >/dev/null 2>&1; then
    :
  else
    echo "Google Chrome v${PROCESSED_CHROME_VERSION} (${ORB_PARAM_CHANNEL}) failed to install."
    exit 1
  fi
else
  if google-chrome-$ORB_PARAM_CHANNEL --version >/dev/null 2>&1; then
    :
  else
    echo "The latest release of Google Chrome (${ORB_PARAM_CHANNEL}) failed to install."
    exit 1
  fi
  echo "$(google-chrome-$ORB_PARAM_CHANNEL --version) has been installed to $(command -v google-chrome-$ORB_PARAM_CHANNEL)"
  echo "Chrome: $PROCESSED_CHROME_VERSION" >>"${HOME}/.browser-versions"
fi
