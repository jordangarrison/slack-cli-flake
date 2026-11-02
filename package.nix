# Slack's official CLI (https://github.com/slackapi/slack-cli), from Slack's release binaries. They are static Go
# builds, so this unpacks one and wraps it; there is no source build. `sources.json` holds the version and one hash per
# platform; `./update.sh` rewrites it.
#
# `binaryName` is the command's name. It is `slack`, as upstream names it; set it to something else (such as
# `slack-cli`) when the Slack desktop app, which also installs `bin/slack`, is in the same profile.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  binaryName ? "slack",
}:
let
  sources = lib.importJSON ./sources.json;
  inherit (sources) version;
  system = stdenvNoCC.hostPlatform.system;
  source = sources.platforms.${system} or (throw "slack-cli: Slack ships no release for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "slack-cli";
  inherit version;

  src = fetchurl {
    url = "https://downloads.slack-edge.com/slack-cli/slack_cli_${version}_${source.asset}.tar.gz";
    inherit (source) hash;
  };
  sourceRoot = ".";

  nativeBuildInputs = [ makeWrapper ];

  # Nix owns the version, so the wrapper turns off the CLI's own update check (it would try to replace itself in the
  # read-only store). Set SLACK_SKIP_UPDATE=0 to see upstream's notices again.
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/slack $out/libexec/slack-cli/slack
    makeWrapper $out/libexec/slack-cli/slack $out/bin/${binaryName} --set-default SLACK_SKIP_UPDATE 1
    # Only the Linux tarballs ship the license.
    if [ -f LICENSE ]; then install -Dm644 LICENSE $out/share/licenses/slack-cli/LICENSE; fi
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/${binaryName} --version | grep -F "v${version}"
    runHook postInstallCheck
  '';

  passthru.sources = sources;

  meta = {
    description = "Slack's command-line tool for creating, installing, and managing Slack apps";
    homepage = "https://docs.slack.dev/tools/slack-cli/";
    changelog = "https://github.com/slackapi/slack-cli/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = binaryName;
    platforms = builtins.attrNames sources.platforms;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
