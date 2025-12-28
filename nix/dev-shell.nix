# Development shell for zerobyte
{
  pkgs,
  system,
  shoutrrr,
  bun2nixPkgs,
}:

let
  # Menu script
  menuScript = pkgs.writeShellScriptBin "menu" ''
    echo ""
    echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\033[1;37m  zerobyte-nix\033[0m \033[0;90m- Nix flake development environment\033[0m"
    echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo -e "\033[0;90m  Tools:\033[0m"
    echo -e "    bun       \033[0;32m$(${pkgs.bun}/bin/bun --version)\033[0m"
    echo -e "    node      \033[0;32m$(${pkgs.nodejs}/bin/node --version)\033[0m"
    echo -e "    restic    \033[0;32m$(${pkgs.restic}/bin/restic version 2>/dev/null | head -1 | awk '{print $2}')\033[0m"
    echo ""
    echo -e "\033[0;90m  Commands:\033[0m"
    echo -e "    \033[1;33mupdate-bun-nix\033[0m     Regenerate bun.nix from upstream"
    echo -e "    \033[1;33mnix flake update\033[0m   Update all flake inputs"
    echo -e "    \033[1;33mmenu\033[0m               Show this menu"
    echo ""
    echo -e "\033[1;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
  '';

  # Update bun.nix script
  updateBunNixScript = pkgs.writeShellScriptBin "update-bun-nix" ''
    # Extract version from flake.nix config
    VERSION=$(${pkgs.gnugrep}/bin/grep -oP 'version = "\K[^"]+' flake.nix | head -1)
    if [ -z "$VERSION" ]; then
      echo -e "\033[1;31m==>\033[0m Could not extract version from flake.nix"
      exit 1
    fi
    TAG="v$VERSION"

    echo -e "\033[1;34m==>\033[0m Fetching zerobyte $TAG..."
    tmpdir=$(mktemp -d)
    ${pkgs.git}/bin/git clone --depth 1 --branch "$TAG" https://github.com/nicotsx/zerobyte "$tmpdir" || exit 1
    echo -e "\033[1;34m==>\033[0m Generating bun.nix..."
    (cd "$tmpdir" && ${bun2nixPkgs.bun2nix}/bin/bun2nix -o "$(pwd)/bun.nix") || exit 1
    cp "$tmpdir/bun.nix" ./bun.nix
    rm -rf "$tmpdir"
    echo -e "\033[1;32m==>\033[0m Updated bun.nix for $TAG"
    echo -e "\033[0;90m    Commit: git add bun.nix && git commit -m 'chore: update bun.nix'\033[0m"
  '';

in
pkgs.mkShell {
  buildInputs = [
    # Dev shell commands
    menuScript
    updateBunNixScript

    # JavaScript runtime and package manager
    pkgs.bun
    pkgs.nodejs

    # Development tools
    pkgs.biome
    pkgs.typescript

    # bun2nix CLI for regenerating bun.nix
    bun2nixPkgs.bun2nix

    # External tools (for local testing)
    pkgs.restic
    pkgs.rclone
    shoutrrr

    # Database tools
    pkgs.sqlite

    # Utilities
    pkgs.git
    pkgs.curl
    pkgs.jq
  ];

  shellHook = ''
    menu
  '';
}
