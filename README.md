# slack-cli-flake

Nix flake for [Slack's official CLI](https://docs.slack.dev/tools/slack-cli/)
([slackapi/slack-cli](https://github.com/slackapi/slack-cli)): create, install,
and manage Slack apps from a manifest in your repository. It repackages Slack's
release binaries (static Go builds); there is no source build.

Not affiliated with Slack or Salesforce. The CLI is Apache-2.0; the Nix code
here is MIT.

Not the same tool as nixpkgs' `slack-cli`, which is a different, third-party
command-line client.

## Quick start

```sh
nix run github:jordangarrison/slack-cli-flake -- --version
```

## Add it to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    slack-cli = {
      url = "github:jordangarrison/slack-cli-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

### In a dev shell

```nix
devShells.default = pkgs.mkShell {
  packages = [ inputs.slack-cli.packages.${pkgs.stdenv.hostPlatform.system}.default ];
};
```

### NixOS or Home Manager

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.slack-cli.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  # NixOS: environment.systemPackages = [ ... ];
}
```

### Overlay (for `pkgs.slack-cli`)

```nix
nixpkgs.overlays = [ inputs.slack-cli.overlays.default ];
```

The overlay replaces nixpkgs' own `slack-cli` (the third-party client) with
this one.

## With the Slack desktop app

The CLI's command is `slack`, and so is the desktop app's (`pkgs.slack`). Both
in one profile collide. Give the CLI another name:

```nix
(inputs.slack-cli.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
  binaryName = "slack-cli";
})
```

In a dev shell there is no collision: the shell's `slack` comes first on
`PATH`.

## What you get

- `bin/slack` (or `binaryName`): the CLI, wrapped with `SLACK_SKIP_UPDATE=1`.
  Nix owns the version, and the CLI's self-update would try to replace a file
  in the read-only store. Set `SLACK_SKIP_UPDATE=0` to see upstream's notices.
  Telemetry is left at upstream's default; set `SLACK_DISABLE_TELEMETRY=1` to
  turn it off.
- Platforms: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`. Slack also
  ships `x86_64-darwin`, which current nixpkgs-unstable no longer supports; the
  overlay still builds it on a nixpkgs that does, such as 26.05.

## Updating

```sh
./update.sh          # the latest release on GitHub
./update.sh 4.12.0   # an exact version
```

It prefetches the tarball for every platform, checks that each holds
`bin/slack`, and only then rewrites `sources.json`. A daily GitHub Actions
workflow runs it, refreshes `flake.lock`, builds the package, and commits
verified changes to `main`. CI builds every flake platform on each push.
