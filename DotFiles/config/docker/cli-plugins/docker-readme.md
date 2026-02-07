ln -sfn "$(command -v docker-compose)" "$DOCKER_CONFIG/cli-plugins/docker-compose"
chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"

# Ensure XDG config dir exists
mkdir -p ~/.config/docker

# Set/overwrite only the "currentContext" field (keeps other fields if present)
CFG=~/.config/docker/config.json
if [ -f "$CFG" ]; then
  jq '.currentContext="colima"' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
else
  printf '{ "currentContext": "colima" }\n' > "$CFG"
fi


## CRed helper
brew install docker-credential-helper
command -v docker-credential-osxkeychain

CFG="$HOME/.config/docker/config.json"
mkdir -p "$(dirname "$CFG")"
if [ -f "$CFG" ]; then
  jq '.credsStore="osxkeychain"' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
else
  printf '{ "currentContext": "colima", "credsStore": "osxkeychain" }\n' > "$CFG"
fi