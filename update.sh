#!/usr/bin/env bash
#
# Bump sources.json to the latest Slack CLI release on GitHub (slackapi/slack-cli),
# or to the version given as the only argument:
#
#   ./update.sh          # latest release
#   ./update.sh 4.12.0   # an exact version
#
# It prefetches the release tarball for every platform in sources.json, checks
# that each holds bin/slack, and writes the file only when all of them succeed.

set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

# Run with tools from this flake's locked nixpkgs input, so neither CI nor users
# need a NIX_PATH or channel.
if [[ "${SLACK_CLI_UPDATE_ENV:-}" != 1 ]]; then
  exec nix shell --inputs-from . \
    nixpkgs#bash \
    nixpkgs#curl \
    nixpkgs#jq \
    nixpkgs#coreutils \
    nixpkgs#gnutar \
    nixpkgs#gzip \
    nixpkgs#nix \
    --command env SLACK_CLI_UPDATE_ENV=1 bash ./update.sh "$@"
fi

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [version]" >&2
  exit 2
fi

if [ "$#" -eq 1 ]; then
  version="${1#v}"
else
  # GITHUB_TOKEN, when set (as in CI), avoids the anonymous rate limit.
  auth=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi
  tag="$(curl -fsSL "${auth[@]}" -H 'Accept: application/vnd.github+json' \
    https://api.github.com/repos/slackapi/slack-cli/releases/latest | jq -er '.tag_name')"
  version="${tag#v}"
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "not a release version: $version" >&2
  exit 1
fi

current="$(jq -er '.version' sources.json)"
if [ "$version" = "$current" ]; then
  echo "slack-cli is already at $version"
  exit 0
fi

next="$(jq --arg version "$version" '.version = $version' sources.json)"
for system in $(jq -r '.platforms | keys[]' sources.json); do
  asset="$(jq -er --arg s "$system" '.platforms[$s].asset' sources.json)"
  url="https://downloads.slack-edge.com/slack-cli/slack_cli_${version}_${asset}.tar.gz"
  echo "prefetching $url" >&2
  prefetch="$(nix store prefetch-file --json --hash-type sha256 "$url")"
  path="$(jq -er '.storePath' <<<"$prefetch")"
  # Linux tarballs list bin/slack, macOS ones ./bin/slack.
  if ! tar -tzf "$path" | grep -qxE '(\./)?bin/slack'; then
    echo "$url does not contain bin/slack" >&2
    exit 1
  fi
  hash="$(jq -er '.hash' <<<"$prefetch")"
  next="$(jq --arg s "$system" --arg hash "$hash" '.platforms[$s].hash = $hash' <<<"$next")"
done

printf '%s\n' "$next" > sources.json
echo "slack-cli: $current -> $version"
