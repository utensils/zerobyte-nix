# Shoutrrr - Notification library and CLI for various services
# https://github.com/nicholas-fedor/shoutrrr
{
  pkgs,
  system,
  lib,
}:

let
  version = "0.13.1";

  # SRI hashes for each platform
  hashes = {
    x86_64-linux = "sha256-TZrDstm5InQOalYf9da5rhnsJm7qTnmG18jLJtvsD8A=";
    aarch64-linux = "sha256-IHgZhsykJbmW/uYUsd6o7Wh3EIsUldduIKFZ0GkjrwI=";
    x86_64-darwin = "sha256-pzmAGRzbWYVHoZqvx6tsuxpuKcfIXMVNPXbKHeeAyxs=";
    aarch64-darwin = "sha256-DKQRzdDd1xccNqetscEKKzgyT1IatOlwPBwa4E8fbDc=";
  };

  # Map Nix system names to shoutrrr release naming convention
  archMap = {
    x86_64-linux = "linux_amd64";
    aarch64-linux = "linux_arm64v8";
    x86_64-darwin = "macOS_amd64";
    aarch64-darwin = "macOS_arm64v8";
  };

  isLinux = builtins.elem system [
    "x86_64-linux"
    "aarch64-linux"
  ];

in
pkgs.stdenv.mkDerivation {
  pname = "shoutrrr";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/nicholas-fedor/shoutrrr/releases/download/v${version}/shoutrrr_${archMap.${system}}_${version}.tar.gz";
    hash = hashes.${system};
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals isLinux [ pkgs.autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 shoutrrr $out/bin/shoutrrr
    runHook postInstall
  '';

  meta = with lib; {
    description = "Notification library and CLI for various services";
    homepage = "https://github.com/nicholas-fedor/shoutrrr";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "shoutrrr";
  };
}
