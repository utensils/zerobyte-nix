# zerobyte-nix

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Nix Flake](https://img.shields.io/badge/Nix-Flake-blue?logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![NixOS](https://img.shields.io/badge/NixOS-Module-5277C3?logo=nixos&logoColor=white)](https://nixos.org/)

Nix flake for [Zerobyte](https://github.com/nicotsx/zerobyte) - a self-hosted backup automation and management application powered by [Restic](https://restic.net/).

## Features

- Pure Nix flake packaging of Zerobyte
- NixOS module with systemd service
- Includes [shoutrrr](https://github.com/containrrr/shoutrrr) for notifications
- FUSE mount support on Linux

## Usage

### Run directly

```bash
nix run github:jamesbrink/zerobyte-nix
```

### Add to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zerobyte-nix.url = "github:jamesbrink/zerobyte-nix";
  };

  outputs = { self, nixpkgs, zerobyte-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        zerobyte-nix.nixosModules.default
        {
          services.zerobyte = {
            enable = true;
            port = 4096;
            openFirewall = true;
          };
        }
      ];
    };
  };
}
```

### Use the overlay

```nix
{
  nixpkgs.overlays = [ zerobyte-nix.overlays.default ];
}
```

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Zerobyte service |
| `port` | int | `4096` | Port to listen on |
| `dataDir` | path | `/var/lib/zerobyte` | Data directory |
| `user` | string | `"zerobyte"` | User to run as |
| `group` | string | `"zerobyte"` | Group to run as |
| `openFirewall` | bool | `false` | Open firewall port |
| `fuse.enable` | bool | `true` | Enable FUSE support (Linux only) |
| `protectHome` | bool | `true` | Enable ProtectHome hardening |
| `extraReadWritePaths` | list | `[]` | Additional writable paths |

## Development

```bash
# Enter development shell
nix develop

# Build the package
nix build

# Run integration tests (NixOS only)
nix build .#checks.x86_64-linux.integration
```

## Updating

This flake follows upstream releases (tags). To update to a new version:

```bash
# 1. Update version in flake.nix (both zerobyte-src URL and config.version)
#    zerobyte-src.url = "github:nicotsx/zerobyte/v0.21.0"
#    version = "0.21.0"

# 2. Update flake.lock
nix flake update zerobyte-src

# 3. Regenerate bun.nix (in devshell)
nix develop
update-bun-nix

# 4. Test and commit
nix build
git add flake.nix flake.lock bun.nix
git commit -m "chore: update to v0.21.0"
```

The `bun.nix` file must always match the upstream release referenced in `flake.lock`.

## Patches

This flake applies patches from upstream PRs not yet merged:

- [PR #253](https://github.com/nicotsx/zerobyte/pull/253) - Adds configurable `PORT` and `MIGRATIONS_PATH` environment variables

## License

This Nix flake packaging is licensed under the MIT License - see [LICENSE](LICENSE) for details.

Zerobyte itself is licensed under the [GNU Affero General Public License v3.0 (AGPL-3.0)](https://github.com/nicotsx/zerobyte/blob/main/LICENSE).

## Credits

- [Zerobyte](https://github.com/nicotsx/zerobyte) by nicotsx
- [Restic](https://restic.net/) backup program
- [shoutrrr](https://github.com/containrrr/shoutrrr) notification library
