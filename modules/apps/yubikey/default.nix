# YubiKey support: pcscd, udev rules, FIDO2 PAM auth (pam_u2f).
#
# Register each YubiKey once with a fixed origin so the mapping file works on
# every machine sharing this config (appid defaults to origin):
#   1) pamu2fcfg -o pam://myorg > u2f_keys        # first key
#   2) pamu2fcfg -n -o pam://myorg >> u2f_keys    # append additional keys
# Commit the file, point `apps.yubikey.authfile` at it, and set
# `apps.yubikey.origin` (and `appid`, if not relying on the default) to the
# same values used at registration.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.apps.yubikey;

  lockRules = lib.concatMapStrings (
    { vendorId, modelId }:
    let
      lockScript = pkgs.writeShellScript "yubikey-lock" ''
        sleep 1
        # Check if Yubikey is still present
        if ! ${pkgs.usbutils}/bin/lsusb -d ${vendorId}:${modelId} > /dev/null 2>&1; then
          ${pkgs.systemd}/bin/loginctl lock-sessions
        fi
      '';
    in
    ''
      ACTION=="remove",\
      ENV{ID_BUS}=="usb",\
      ENV{ID_MODEL_ID}=="${modelId}",\
      ENV{ID_VENDOR_ID}=="${vendorId}",\
      ENV{ID_VENDOR}=="Yubico",\
      RUN+="${lockScript}"
    ''
  ) cfg.lockDevices;
in
{
  options.apps.yubikey = {
    enable = lib.mkEnableOption "YubiKey support (pcscd, udev rules, PAM FIDO2)";

    control = lib.mkOption {
      type = lib.types.enum [
        "required"
        "requisite"
        "sufficient"
        "optional"
      ];
      default = "sufficient";
      description = ''
        PAM control flag for `pam_u2f`. Use `required` for multi-factor
        (password *and* YubiKey); `sufficient` allows the YubiKey to replace
        the password.
      '';
    };

    authfile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./u2f_keys";
      description = ''
        Key mapping file handed to `pam_u2f` (`settings.authfile`). Defaults
        to the per-user {file}`$XDG_CONFIG_HOME/Yubico/u2f_keys`. Generate one
        shared file with a fixed `origin` (see module header) and commit it to
        reuse registrations across machines.
      '';
    };

    origin = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "pam://myorg";
      description = ''
        FIDO origin passed to `pam_u2f` (`settings.origin`). Defaults to
        `pam://$HOSTNAME`, which binds each registration to one machine; set
        the same fixed value used with `pamu2fcfg -o` to share registrations
        across machines.
      '';
    };

    appid = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "pam://myorg";
      description = ''
        FIDO application ID passed to `pam_u2f` (`settings.appid`). Defaults
        to the `origin` value; must match `pamu2fcfg -i` if registration used
        a distinct one.
      '';
    };

    cue = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Prompt the user (`Please touch the device`) instead of waiting
        silently for the YubiKey.
      '';
    };

    lockOnRemoval = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Lock all sessions (`loginctl lock-sessions`) when a YubiKey is unplugged.";
    };

    lockDevices = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            vendorId = lib.mkOption {
              type = lib.types.str;
              default = "1050";
              description = "Yubico USB vendor ID.";
            };
            modelId = lib.mkOption {
              type = lib.types.str;
              description = "USB model/product ID of the YubiKey (e.g. `0407`).";
            };
          };
        }
      );
      default = [
        {
          vendorId = "1050";
          modelId = "0407";
        }
      ];
      example = [
        {
          vendorId = "1050";
          modelId = "0407";
        }
        {
          vendorId = "1050";
          modelId = "0404";
        }
      ];
      description = ''
        USB device IDs that trigger the auto-lock rule on removal
        (`lsusb -d vendor:model` must match the plugged-in key). `0407`
        covers YubiKey 5 CCID composite devices; check with `lsusb`.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional YubiKey-related packages to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [
        age-plugin-yubikey
        pam_u2f
        yubikey-manager
        yubihsm-connector
        # yubihsm-shell #this is broken in 25.11 / nixpkgs-unstable
      ]
      ++ cfg.extraPackages;

    services = {
      pcscd.enable = true;
      udev = {
        packages = [ pkgs.yubikey-personalization ];
        extraRules = lib.mkIf cfg.lockOnRemoval lockRules;
      };
    };

    security.pam.u2f = {
      enable = true;
      inherit (cfg) control;
      settings = {
        inherit (cfg)
          authfile
          origin
          appid
          cue
          ;
      };
    };
  };
}
