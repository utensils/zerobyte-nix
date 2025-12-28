# nix-darwin module for Zerobyte backup management service (macOS)
#
# EXPERIMENTAL/FUTURE USE
# macOS lacks Linux capabilities (CAP_DAC_READ_SEARCH, etc.) and uses TCC
# (Transparency, Consent, and Control) which blocks access to ~/Desktop,
# ~/Documents, etc. even for root. Full support requires significant code
# changes to handle TCC permission grants via System Preferences.
{ self }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.zerobyte;
in
{
  options.services.zerobyte = {
    enable = lib.mkEnableOption "Zerobyte backup management service";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.zerobyte;
      defaultText = lib.literalExpression "pkgs.zerobyte";
      description = "The Zerobyte package to use.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/zerobyte";
      description = "Directory to store Zerobyte data.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4096;
      description = "Port on which Zerobyte listens.";
    };

    serverIp = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "IP address to bind the server to.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Timezone for scheduling backups.";
    };

    resticHostname = lib.mkOption {
      type = lib.types.str;
      default = "zerobyte";
      description = "Hostname used for restic operations.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for Zerobyte.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create data directory
    system.activationScripts.zerobyte.text = ''
      mkdir -p ${cfg.dataDir}/data
      chmod 750 ${cfg.dataDir}
    '';

    launchd.daemons.zerobyte = {
      serviceConfig = {
        Label = "org.zerobyte.daemon";
        ProgramArguments = [ "${cfg.package}/bin/zerobyte" ];
        RunAtLoad = true;
        KeepAlive = true;
        WorkingDirectory = "${cfg.dataDir}";

        EnvironmentVariables = {
          NODE_ENV = "production";
          PORT = toString cfg.port;
          SERVER_IP = cfg.serverIp;
          RESTIC_HOSTNAME = cfg.resticHostname;
          DATABASE_URL = "${cfg.dataDir}/data/zerobyte.db";
          MIGRATIONS_PATH = "${cfg.package}/lib/zerobyte/drizzle";
          TZ = cfg.timezone;
        }
        // cfg.environment;

        StandardOutPath = "/var/log/zerobyte.log";
        StandardErrorPath = "/var/log/zerobyte.error.log";
      };
    };
  };
}
