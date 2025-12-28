# Package set for zerobyte and dependencies
{
  pkgs,
  system,
  lib,
  config,
  bun2nixPkgs,
}:

let
  shoutrrr = import ./shoutrrr.nix {
    inherit pkgs system lib;
  };

  zerobyte = import ./zerobyte.nix {
    inherit
      pkgs
      system
      lib
      config
      shoutrrr
      ;
  };

in
{
  inherit zerobyte shoutrrr;
}
