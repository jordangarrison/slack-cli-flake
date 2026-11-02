{
  description = "Slack's official CLI (slackapi/slack-cli), packaged for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      # The platforms Slack ships release binaries for (sources.json) that this nixpkgs still supports. x86_64-darwin
      # stays in sources.json for the overlay on older nixpkgs, such as 26.05.
      systems = builtins.filter (system: builtins.elem system nixpkgs.lib.systems.flakeExposed) (
        builtins.attrNames (builtins.fromJSON (builtins.readFile ./sources.json)).platforms
      );
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        slack-cli = pkgs.callPackage ./package.nix { };
        default = slack-cli;
      });

      overlays.default = final: _prev: {
        slack-cli = final.callPackage ./package.nix { };
      };

      apps = forAllSystems (
        pkgs:
        let
          slack-cli = {
            type = "app";
            program = pkgs.lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.slack-cli;
            meta = self.packages.${pkgs.stdenv.hostPlatform.system}.slack-cli.meta;
          };
        in
        {
          inherit slack-cli;
          default = slack-cli;
        }
      );

      checks = forAllSystems (pkgs: {
        inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) slack-cli;
        # The desktop-app workaround: the same CLI under another command name.
        renamed = self.packages.${pkgs.stdenv.hostPlatform.system}.slack-cli.override {
          binaryName = "slack-cli";
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
