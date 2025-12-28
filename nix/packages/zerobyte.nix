# Zerobyte - Self-hosted backup automation and management
# https://github.com/nicotsx/zerobyte
{
  pkgs,
  system,
  lib,
  config,
  shoutrrr,
}:

let
  isLinux = builtins.elem system [
    "x86_64-linux"
    "aarch64-linux"
  ];

  # Apply patches to upstream source
  patchedSrc = pkgs.applyPatches {
    name = "zerobyte-src-patched";
    src = config.zerobyte-src;
    patches = config.patches;
  };

  # Version from flake config (must match zerobyte-src tag)
  inherit (config) version;

in
pkgs.stdenv.mkDerivation {
  pname = "zerobyte";
  inherit version;

  src = patchedSrc;

  nativeBuildInputs = [
    pkgs.bun2nix.hook
    pkgs.makeWrapper
  ];

  # Fetch bun dependencies using the lockfile from this flake
  # bun2nix.hook populates node_modules from these pre-fetched deps (fully offline)
  bunDeps = pkgs.bun2nix.fetchBunDeps {
    bunNix = config.bunNix;
  };

  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)

    # Ensure bun doesn't try to install/fetch anything (deps provided by bun2nix.hook)
    # Network is blocked by Nix sandbox, but this makes failures clearer
    export BUN_INSTALL_BIN=$HOME/.bun/bin

    # Build the application (react-router build)
    bun run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Create output directories matching the expected structure
    mkdir -p $out/lib/zerobyte/dist
    mkdir -p $out/lib/zerobyte/drizzle
    mkdir -p $out/bin

    # Copy built assets (server expects dist/server and dist/client)
    cp -r dist/server $out/lib/zerobyte/dist/server
    cp -r dist/client $out/lib/zerobyte/dist/client
    cp -r app/drizzle/* $out/lib/zerobyte/drizzle/
    cp package.json $out/lib/zerobyte/

    # Copy node_modules for runtime dependencies
    cp -r node_modules $out/lib/zerobyte/

    # Create wrapper script with runtime dependencies
    # --chdir ensures server finds dist/client relative to package dir
    makeWrapper ${pkgs.bun}/bin/bun $out/bin/zerobyte \
      --chdir $out/lib/zerobyte \
      --add-flags "dist/server/index.js" \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            pkgs.restic
            pkgs.rclone
            shoutrrr
            pkgs.openssh
          ]
          ++ lib.optionals isLinux [
            pkgs.fuse3
            pkgs.davfs2
          ]
        )
      } \
      --set NODE_ENV "production"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Self-hosted backup automation and management";
    homepage = "https://github.com/nicotsx/zerobyte";
    license = licenses.agpl3Plus;
    platforms = platforms.unix;
    mainProgram = "zerobyte";
  };
}
