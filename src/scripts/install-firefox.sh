#!/bin/bash
if [[ $EUID == 0 ]]; then export SUDO=""; else export SUDO="sudo"; fi
# FUNCTIONS
grab_firefox_version() {
  if [[ "$ORB_PARAM_FIREFOX_VERSION" == "latest" ]]; then
    # extract latest version from mozilla product details API

    FIREFOX_VERSION_STRING=$(curl \
      https://product-details.mozilla.org/1.0/firefox_versions.json |
      jq '.LATEST_FIREFOX_VERSION')

    # strip leading/trailing "
    temp="${FIREFOX_VERSION_STRING%\"}"
    FIREFOX_VERSION="${temp#\"}"
    echo "Latest stable version of Firefox is $FIREFOX_VERSION"
  else
    FIREFOX_VERSION="$ORB_PARAM_FIREFOX_VERSION"
    echo "Selected version of Firefox is $FIREFOX_VERSION"
  fi

  # create Firefox download URL base
  FIREFOX_URL_BASE="https://archive.mozilla.org/pub/firefox/releases/$FIREFOX_VERSION"
}

installation_check() {
  if command -v firefox >/dev/null 2>&1; then
    if firefox --version | grep "$FIREFOX_VERSION" >/dev/null 2>&1; then
      echo "firefox $FIREFOX_VERSION is already installed"
      exit 0
    else
      echo "A different version of Firefox is installed ($(firefox --version)); removing it"
      $SUDO rm -f "$(command -v firefox)"
    fi
  fi
}

# mac: setup version, install packages, then continue
if uname -a | grep Darwin >/dev/null 2>&1; then
  echo "System detected as MacOS"
  grab_firefox_version
  installation_check
  HOMEBREW_NO_AUTO_UPDATE=1 brew install gnupg coreutils >/dev/null 2>&1
# deb/ubuntu/other linux: setup version, install packages, then continue
else
  echo "System detected as Linux"
  grab_firefox_version
  installation_check

  if command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y \
      alsa-lib \
      bzip2 \
      dbus-glib-devel \
      gtk2-devel \
      gtk3-devel \
      libXt-devel \
      perl \
      which \
      >/dev/null 2>&1
  else
    $SUDO apt-get update >/dev/null 2>&1 &&
      $SUDO apt-get install -y \
        libasound-dev \
        libxt6 \
        libgtk-3-dev \
        libdbus-glib-1-2 \
        >/dev/null 2>&1
  fi
fi

# import public key
curl --silent --show-error --location --fail --retry 3 "$FIREFOX_URL_BASE/KEY" | gpg --import >/dev/null 2>&1

# download shasums
curl -O --silent --show-error --location --fail --retry 3 "$FIREFOX_URL_BASE/SHA256SUMS.asc" || curl -O --silent --show-error --location --fail --retry 3 "$FIREFOX_URL_BASE/SHA512SUMS.asc"
curl -O --silent --show-error --location --fail --retry 3 "$FIREFOX_URL_BASE/SHA256SUMS" || curl -O --silent --show-error --location --fail --retry 3 "$FIREFOX_URL_BASE/SHA512SUMS"

# verify shasums
gpg --verify SHA256SUMS.asc SHA256SUMS || gpg --verify SHA512SUMS.asc SHA512SUMS
rm -f SHA256SUMS.asc || rm -f SHA512SUMS.asc
FIREFOX_MAJOR_VERSION=$(echo "$FIREFOX_VERSION" | awk -F. '{print $1}')
# setup firefox download
if uname -a | grep Darwin >/dev/null 2>&1; then
  FIREFOX_FILE="Firefox%20$FIREFOX_VERSION"
  PLATFORM=mac
  FILE_EXT=dmg
else
  FIREFOX_FILE="firefox-$FIREFOX_VERSION"
  PLATFORM=linux-x86_64
  if [ "$FIREFOX_MAJOR_VERSION" -ge 135 ]; then
    FILE_EXT=tar.xz
  else
    FILE_EXT=tar.bz2
  fi
fi

FIREFOX_FILE_LOCATION="$PLATFORM/en-US/$FIREFOX_FILE"

FIREFOX_FILE_NAME="$PLATFORM-en-US-$FIREFOX_FILE"

if [ "$ORB_PARAM_SAVE_CACHE" = 1 ] && [ -f "/tmp/firefox" ]; then
  echo "Cache found."
  mv /tmp/firefox "$FIREFOX_FILE_NAME.$FILE_EXT"
else
  # download firefox
  echo "Downloading firefox"
  curl --silent --show-error --location --fail --retry 3 \
    --output "$FIREFOX_FILE_NAME.$FILE_EXT" \
    "$FIREFOX_URL_BASE/$FIREFOX_FILE_LOCATION.$FILE_EXT"
fi

if [ "$ORB_PARAM_SAVE_CACHE" = 1 ]; then
  cp "$FIREFOX_FILE_NAME.$FILE_EXT" /tmp/firefox
fi

if uname -a | grep Darwin >/dev/null 2>&1; then
  echo "No PGP data for macOS Firefox releases; skipping PGP verification"

  perl -i -pe "s&mac/en-US/Firefox $FIREFOX_VERSION&mac-en-US-Firefox%20$FIREFOX_VERSION&g" SHA256SUMS
  perl -i -pe "s&mac/en-US/Firefox $FIREFOX_VERSION&mac-en-US-Firefox%20$FIREFOX_VERSION&g" SHA512SUMS
else
  # only do this step if .asc file exists for this version
  if [[ $(curl --silent --location --fail --retry 3 \
    "$FIREFOX_URL_BASE/$FIREFOX_FILE_LOCATION.$FILE_EXT.asc") ]]; then

    curl --silent --show-error --location --fail --retry 3 \
      --output "$FIREFOX_FILE_NAME.$FILE_EXT.asc" \
      "$FIREFOX_URL_BASE/$FIREFOX_FILE_LOCATION.$FILE_EXT.asc"

    # verify download archive
    gpg --verify "$FIREFOX_FILE_NAME.$FILE_EXT.asc" "$FIREFOX_FILE_NAME.$FILE_EXT"
    rm -f "$FIREFOX_FILE_NAME.$FILE_EXT.asc"
  fi

  perl -i -pe "s%linux-x86_64/en-US/firefox%linux-x86_64-en-US-firefox%g" SHA256SUMS
  perl -i -pe "s%linux-x86_64/en-US/firefox%linux-x86_64-en-US-firefox%g" SHA512SUMS
fi

grep "$FIREFOX_FILE_NAME.$FILE_EXT" SHA256SUMS | sha256sum -c - ||
  grep "$FIREFOX_FILE_NAME.$FILE_EXT" SHA512SUMS | sha512sum -c -
rm -f SHA256SUMS || rm -f SHA512SUMS

# setup firefox installation
if uname -a | grep Darwin >/dev/null 2>&1; then
  hdiutil attach "$FIREFOX_FILE_NAME.$FILE_EXT" >/dev/null 2>&1
  $SUDO cp -R /Volumes/Firefox/Firefox.app /Applications

  hdiutil eject /Volumes/Firefox >/dev/null 2>&1
  $SUDO rm -f "$FIREFOX_FILE_NAME.$FILE_EXT"

  echo -e "#\!/bin/bash\n" >firefox
  perl -i -pe "s|#\\\|#|g" firefox
  echo -e "/Applications/Firefox.app/Contents/MacOS/firefox \"\$@\"" >>firefox

  $SUDO mv firefox "$ORB_PARAM_FIREFOX_INSTALL_DIR"
  $SUDO chmod +x "$ORB_PARAM_FIREFOX_INSTALL_DIR/firefox"

  # test/verify version
  if firefox --version | grep "$FIREFOX_VERSION" >/dev/null 2>&1; then
    echo "$(firefox --version) has been installed in the /Applications directory"
    echo "A shortcut has also been created at $(command -v firefox)"
  else
    echo "Something went wrong; the specified version of Firefox could not be installed"
    exit 1
  fi

else
  if [ "$FIREFOX_MAJOR_VERSION" -ge 135 ]; then
    $SUDO tar -xzf "$FIREFOX_FILE_NAME.$FILE_EXT"
  else
    $SUDO tar -xjf "$FIREFOX_FILE_NAME.$FILE_EXT"
  fi
  $SUDO rm -f "$FIREFOX_FILE_NAME.$FILE_EXT"
  $SUDO mv firefox "$ORB_PARAM_FIREFOX_INSTALL_DIR/firefox-$FIREFOX_VERSION"
  $SUDO chmod +x "$ORB_PARAM_FIREFOX_INSTALL_DIR/firefox-$FIREFOX_VERSION/firefox"
  $SUDO ln -s "$ORB_PARAM_FIREFOX_INSTALL_DIR/firefox-$FIREFOX_VERSION/firefox" /usr/local/bin/firefox

  # test/verify version
  if echo "$(firefox --version)esr" | grep "$FIREFOX_VERSION" >/dev/null 2>&1; then
    echo "$(firefox --version) has been installed to $(command -v firefox)"
  else
    echo "Something went wrong; the specified version of Firefox could not be installed"
    exit 1
  fi
fi
