{
  lib,
  config,
  ...
}: let
  user = config.omarchy-themes-nixos.user;
  themes = config.home-manager.users.${user}.omarchy-themes.themes or {};
in {
  options.omarchy-themes-nixos = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "nic";
      description = "Home Manager username for theme specialisations";
    };
  };

  config.specialisation = lib.mkIf (themes != {}) (
    lib.mapAttrs (name: _: {
      configuration.home-manager.users.${user}.omarchy-themes.defaultTheme = lib.mkForce name;
    })
    themes
  );
}
