#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi
# installation check
if uname -a | grep Darwin >/dev/null 2>&1; then
  if ls /Applications/*Google\ Chrome* >/dev/null 2>&1; then
    if [ "$ORB_PARAM_REPLACE_EXISTING" == "1" ]; then
      echo "$(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version)is currently installed; replacing it"
      HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall google-chrome >/dev/null 2>&1 || true
      $SUDO rm -rf /Applications/Google\ Chrome.app >/dev/null 2>&1 || true
    else
      echo "$(/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --version)is already installed"
      exit 0
    fi
  else
    echo "Google Chrome is not currently installed; installing it"
  fi
elif grep Alpine /etc/issue >/dev/null 2>&1; then
  if command -v chromium-browser >/dev/null 2>&1; then
    if [ "$ORB_PARAM_REPLACE_EXISTING" == "1" ]; then
      echo "$(chromium-browser --version)is currently installed; replacing it"
      $SUDO apk del --force-broken-world chromium >/dev/null 2>&1 || true
      $SUDO rm -f "$(command -v chromium-browser)" >/dev/null 2>&1 || true
    else
      echo "$(chromium-browser --version)is already installed to $(command -v chromium-browser)"
      exit 0
    fi
  else
    echo "Google Chrome (via Chromium) is not currently installed; installing it"
  fi
elif command -v yum >/dev/null 2>&1; then
  if command -v google-chrome >/dev/null 2>&1; then
    if [ "$ORB_PARAM_REPLACE_EXISTING" == "1" ]; then
      echo "$(google-chrome --version)is currently installed; replacing it"
      $SUDO yum remove -y google-chrome-stable >/dev/null 2>&1 || true
      $SUDO rm -f "$(command -v google-chrome)" >/dev/null 2>&1 || true
    else
      echo "$(google-chrome --version)is already installed to $(command -v google-chrome)"
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
  # Universal MacOS .pkg with license pre-accepted: https://support.google.com/chrome/a/answer/9915669?hl=en
  CHROME_MAC_URL="https://dl.google.com/chrome/mac/stable/accept_tos%3Dhttps%253A%252F%252Fwww.google.com%252Fintl%252Fen_ph%252Fchrome%252Fterms%252F%26_and_accept_tos%3Dhttps%253A%252F%252Fpolicies.google.com%252Fterms/googlechrome.pkg"
  CHROME_TEMP_DIR="$(mktemp -d)"
  curl -L -o "$CHROME_TEMP_DIR/googlechrome.pkg" "$CHROME_MAC_URL"
  sudo /usr/sbin/installer -pkg "$CHROME_TEMP_DIR/googlechrome.pkg" -target /
  sudo rm -rf "$CHROME_TEMP_DIR"
  xattr -rc "/Applications/Google Chrome.app"
  echo '#!/usr/bin/env bash' >> google-chrome
  echo '/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome "$@"' >> google-chrome
  sudo mv google-chrome /usr/local/bin/
  sudo chmod +x /usr/local/bin/google-chrome
  # test/verify installation
  if google-chrome --version >/dev/null 2>&1; then
    echo "$(google-chrome --version)has been installed in the /Applications directory"
    echo "A shortcut has also been created at $(command -v google-chrome)"
    exit 0
  else
    echo "Something went wrong; Google Chrome could not be installed"
    exit 1
  fi
elif command -v yum >/dev/null 2>&1; then
  # download chrome
  if [[ "$ORB_PARAM_CHROME_VERSION" == "latest" ]]; then
    CHROME_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
  else
    CHROME_URL="https://dl.google.com/linux/chrome/rpm/stable/x86_64/google-chrome-stable-$ORB_PARAM_CHROME_VERSION-1.x86_64.rpm"
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
  rm -rf google-chrome.rpm liberation-fonts.rpm
else
  # download chrome
  if [[ "$ORB_PARAM_CHROME_VERSION" == "latest" ]]; then
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | $SUDO apt-key add -
    $SUDO sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
    $SUDO apt-get update
    $SUDO apt-get install google-chrome-stable
  else
    # Google does not keep older releases in their PPA, but they can be installed manually. HTTPS should be enough to secure the download.
    wget --no-verbose -O /tmp/chrome.deb "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${ORB_PARAM_CHROME_VERSION}-1_amd64.deb" \
      && $SUDO apt-get install -y /tmp/chrome.deb \
      && rm /tmp/chrome.deb
  fi
  $SUDO sed -i 's|HERE/chrome"|HERE/chrome" --disable-setuid-sandbox --no-sandbox|g' "/opt/google/chrome/google-chrome"
fi

# test/verify installation
if [[ "$ORB_PARAM_CHROME_VERSION" != "latest" ]]; then
  if google-chrome --version | grep "$ORB_PARAM_CHROME_VERSION" >/dev/null 2>&1; then
    :
  else
    echo "Something went wrong; Google Chrome could not be installed"
    exit 1
  fi
else
  if google-chrome --version >/dev/null 2>&1; then
    :
  else
    echo "Something went wrong; Google Chrome could not be installed"
    exit 1
  fi
  echo "$(google-chrome --version) has been installed to $(command -v google-chrome)"
  echo "Chrome: $ORB_PARAM_CHROME_VERSION" >>"${HOME}/.browser-versions"
fi
