#!/bin/zsh
# Installs a display override that adds HiDPI sizes for an external display. Restart to apply.
#
#   ./override.sh install   [VENDOR PRODUCT WIDTHxHEIGHT]
#   ./override.sh uninstall [VENDOR PRODUCT]
#   ./override.sh print     [VENDOR PRODUCT WIDTHxHEIGHT]
#
# Without arguments it uses the first external display (needs ./build.sh first).
set -euo pipefail
cd "${0:A:h}"

command=${1:-}
if [[ $command != (install|uninstall|print) ]]; then
  echo "usage: ./override.sh install|uninstall|print [VENDOR PRODUCT [WIDTHxHEIGHT]]" >&2
  exit 2
fi
shift

if (( $# >= 2 )); then
  vendor=${1#0x} product=${2#0x} native=${3:-}
else
  [[ -x build/set-hidpi ]] || { echo "Run ./build.sh first" >&2; exit 1; }
  read -r _ vendor product native < <(build/set-hidpi -l) || { echo "No external display found" >&2; exit 1; }
fi

DIR="/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-$vendor"
FILE="$DIR/DisplayProductID-$product"

plist() {
  local w=${native%x*} h=${native#*x}
  hex_data() { printf '%08x' "$@" | xxd -r -p | base64 }

  # 100%, 90%, 80%, 75%, 62.5% and 50% of the native size. Each HiDPI entry is
  # (2x width, 2x height, 0x9, 0x200000), plus plain entries for the 2x and 1x sizes.
  typeset -aU entries
  for num den in 1 1 9 10 4 5 3 4 5 8 1 2; do
    local sw=$(( w * num / den )) sh=$(( h * num / den ))
    entries+=(
      "		<data>$(hex_data $((sw * 2)) $((sh * 2)) 9 0x200000)</data>"
      "		<data>$(hex_data $((sw * 2)) $((sh * 2)))</data>"
      "		<data>$(hex_data $sw $sh)</data>"
    )
  done

  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>DisplayVendorID</key>
	<integer>$((16#$vendor))</integer>
	<key>DisplayProductID</key>
	<integer>$((16#$product))</integer>
	<key>scale-resolutions</key>
	<array>
${(F)entries}
	</array>
</dict>
</plist>
EOF
}

case $command in
  print)
    plist
    ;;
  install)
    [[ -n $native ]] || { echo "Missing WIDTHxHEIGHT" >&2; exit 1; }
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    plist > "$tmp"
    plutil -lint "$tmp" > /dev/null
    sudo mkdir -p "$DIR"
    [[ -e $FILE && ! -e $FILE.backup ]] && sudo cp "$FILE" "$FILE.backup"
    sudo install -m 644 -o root -g wheel "$tmp" "$FILE"
    echo "Installed $FILE. Restart your Mac to load it."
    ;;
  uninstall)
    if [[ -e $FILE.backup ]]; then
      sudo mv "$FILE.backup" "$FILE"
      echo "Restored the previous $FILE. Restart your Mac to load it."
    elif [[ -e $FILE ]]; then
      sudo rm "$FILE"
      echo "Removed $FILE. Restart your Mac to apply."
    else
      echo "No override installed."
    fi
    ;;
esac
