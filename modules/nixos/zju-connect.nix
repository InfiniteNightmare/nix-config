{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.zjuConnect;

  zjuConnect = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "zju-connect";
    version = "1.3.0";

    src = pkgs.fetchurl {
      url = "https://github.com/Mythologyli/zju-connect/releases/download/v${finalAttrs.version}/zju-connect-linux-amd64.zip";
      hash = "sha256-PgqOUXtreAw/dp+9NzmWYHVLzPSc1mZ0nTPgu5LCpeI=";
    };

    nativeBuildInputs = [ pkgs.unzip ];

    unpackPhase = ''
      runHook preUnpack
      unzip "$src"
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 zju-connect "$out/bin/zju-connect"
      runHook postInstall
    '';

    meta = {
      description = "Go implementation of the ZJU RVPN client";
      homepage = "https://github.com/Mythologyli/zju-connect";
      license = lib.licenses.agpl3Only;
      mainProgram = "zju-connect";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  });

  passwordEnv =
    if cfg.passwordSecret != null then
      "ZJU_CONNECT_PASSWORD_FILE=${config.age.secrets.${cfg.passwordSecret}.path}"
    else
      "ZJU_CONNECT_PASSWORD_FILE=${cfg.passwordFile}";

  staticArgs = [
    "-protocol"
    cfg.protocol
    "-server"
    cfg.server
    "-port"
    (toString cfg.port)
    "-username"
    cfg.username
    "-socks-bind"
    cfg.socksBind
    "-http-bind"
    cfg.httpBind
  ]
  ++ lib.optionals (cfg.clientDataFile != null) [
    "-client-data-file"
    cfg.clientDataFile
  ]
  ++ cfg.extraArgs;

  hasPort = bind: bind != "" && lib.hasInfix ":" bind;
  bindPort = bind: lib.toIntBase10 (lib.last (lib.splitString ":" bind));
in
{
  options.services.zjuConnect = {
    enable = mkEnableOption "ZJU Connect system service";

    package = mkOption {
      type = types.package;
      default = zjuConnect;
      defaultText = literalExpression "packaged Mythologyli/zju-connect release binary";
      description = "Package providing the zju-connect binary.";
    };

    installCli = mkOption {
      type = types.bool;
      default = true;
      description = "Install zju-connect into the system profile.";
    };

    username = mkOption {
      type = types.str;
      default = "";
      description = "ZJU network account, usually the student or staff ID.";
    };

    passwordSecret = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Name of an agenix secret containing the ZJU account password.";
      example = "zju-connect-password";
    };

    passwordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime path to a plaintext password file. Prefer passwordSecret.";
      example = "/run/secrets/zju-connect-password";
    };

    protocol = mkOption {
      type = types.enum [
        "easyconnect"
        "atrust"
      ];
      default = "easyconnect";
      description = "ZJU Connect login protocol.";
    };

    server = mkOption {
      type = types.str;
      default = "rvpn.zju.edu.cn";
      description = "RVPN server address.";
    };

    port = mkOption {
      type = types.port;
      default = 443;
      description = "RVPN server port.";
    };

    socksBind = mkOption {
      type = types.str;
      default = "127.0.0.1:1080";
      description = "SOCKS5 proxy bind address.";
    };

    httpBind = mkOption {
      type = types.str;
      default = "127.0.0.1:1081";
      description = "HTTP proxy bind address. Set to an empty string to disable it.";
    };

    clientDataFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Client data file used by aTrust to persist login state.";
      example = "/var/lib/zju-connect/client_data.json";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the configured local proxy ports in the firewall.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional command-line arguments passed to zju-connect.";
      example = literalExpression ''[ "-disable-multi-line" "-zju-dns-server" "auto" ]'';
    };
  };

  config = {
    environment.systemPackages = mkIf cfg.installCli [ cfg.package ];

    assertions = mkIf cfg.enable [
      {
        assertion = cfg.username != "";
        message = "services.zjuConnect.username must be set when the service is enabled.";
      }
      {
        assertion = (cfg.passwordSecret != null) != (cfg.passwordFile != null);
        message = "Set exactly one of services.zjuConnect.passwordSecret or services.zjuConnect.passwordFile.";
      }
    ];

    systemd.tmpfiles.rules = mkIf (cfg.enable && cfg.clientDataFile != null) [
      "d ${builtins.dirOf cfg.clientDataFile} 0700 root root -"
    ];

    systemd.services.zju-connect = mkIf cfg.enable {
      description = "ZJU Connect";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = passwordEnv;
        ExecStart = pkgs.writeShellScript "zju-connect-start" ''
          set -euo pipefail
          password="$(${pkgs.coreutils}/bin/cat "$ZJU_CONNECT_PASSWORD_FILE")"
          exec ${lib.escapeShellArg "${cfg.package}/bin/zju-connect"} \
            ${lib.escapeShellArgs staticArgs} \
            -password "$password"
        '';
        StateDirectory = "zju-connect";
        WorkingDirectory = "/var/lib/zju-connect";
        NoNewPrivileges = true;
      };
    };

    networking.firewall.allowedTCPPorts = mkIf (cfg.enable && cfg.openFirewall) (
      lib.optionals (hasPort cfg.socksBind) [ (bindPort cfg.socksBind) ]
      ++ lib.optionals (hasPort cfg.httpBind) [ (bindPort cfg.httpBind) ]
    );
  };
}
