# NixOS module for Zerobyte backup management service
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

    user = lib.mkOption {
      type = lib.types.str;
      default = "zerobyte";
      description = "User account under which Zerobyte runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "zerobyte";
      description = "Group under which Zerobyte runs.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to create the user and group automatically.
        Set to false if using an existing user account.
      '';
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

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the firewall for Zerobyte.";
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

    fuse = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable FUSE mounting capabilities.
          Requires CAP_SYS_ADMIN and access to /dev/fuse.
          Enables NFS, SMB, and WebDAV volume mounts.
        '';
      };
    };

    protectHome = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable ProtectHome systemd security hardening.
        When true, /home, /root, and /run/user are inaccessible.
        Set to false if you need to backup home directories.
      '';
    };

    extraReadWritePaths = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
      default = [ ];
      example = [
        "/mnt/storage"
        "/backup"
      ];
      description = ''
        Additional paths the service can write to.
        Accepts both string paths and Nix store paths.
        Use this for custom repository locations outside of dataDir.
        Required because ProtectSystem=strict makes the filesystem read-only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = lib.mkIf cfg.createUser {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      description = "Zerobyte service user";
    };

    users.groups.${cfg.group} = lib.mkIf cfg.createUser { };

    # Ensure dataDir and data subdir exist with correct ownership
    # Note: Zerobyte also creates data/ via fs.mkdir, but tmpfiles ensures correct ownership
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.zerobyte = {
      description = "Zerobyte backup management service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        NODE_ENV = "production";
        PORT = toString cfg.port;
        SERVER_IP = cfg.serverIp;
        RESTIC_HOSTNAME = cfg.resticHostname;
        DATABASE_URL = "${cfg.dataDir}/data/zerobyte.db";
        MIGRATIONS_PATH = "${cfg.package}/lib/zerobyte/drizzle";
        TZ = cfg.timezone;
      }
      // cfg.environment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/zerobyte";
        Restart = "on-failure";
        RestartSec = 5;

        WorkingDirectory = cfg.dataDir;

        # Capabilities
        # - CAP_SYS_ADMIN: Required for FUSE mounts
        # - CAP_DAC_READ_SEARCH: Required to read restricted directories
        # - CAP_DAC_OVERRIDE: Required to write to directories not owned by service user
        AmbientCapabilities =
          lib.optional cfg.fuse.enable "CAP_SYS_ADMIN"
          ++ lib.optional (!cfg.protectHome) "CAP_DAC_READ_SEARCH"
          ++ lib.optional (cfg.extraReadWritePaths != [ ]) "CAP_DAC_OVERRIDE";
        CapabilityBoundingSet =
          lib.optional cfg.fuse.enable "CAP_SYS_ADMIN"
          ++ lib.optional (!cfg.protectHome) "CAP_DAC_READ_SEARCH"
          ++ lib.optional (cfg.extraReadWritePaths != [ ]) "CAP_DAC_OVERRIDE";

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = cfg.protectHome;
        # Disable when capabilities are needed
        NoNewPrivileges = !cfg.fuse.enable && cfg.protectHome && cfg.extraReadWritePaths == [ ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = !cfg.fuse.enable;
        LockPersonality = true;
        MemoryDenyWriteExecute = false; # Required for bun/V8
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = !cfg.fuse.enable;

        # Allow write access to data directory
        ReadWritePaths = [ cfg.dataDir ] ++ (map toString cfg.extraReadWritePaths);
      }
      # State directory (only set when using default dataDir)
      // lib.optionalAttrs (cfg.dataDir == "/var/lib/zerobyte") {
        StateDirectory = "zerobyte";
        StateDirectoryMode = "0750";
      }
      # FUSE device access
      // lib.optionalAttrs cfg.fuse.enable {
        DeviceAllow = [ "/dev/fuse rw" ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
