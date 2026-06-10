{
  description = "Declarative multi-theme manager for NixOS + Hyprland";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      omarchyLib = import ./lib { inherit lib; };
      defaultTemplates = import ./templates;
      forAllSystems = f: lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f nixpkgs.legacyPackages.${system});
    in {
      homeManagerModules.default = { config, lib, pkgs, ... }:
        import ./modules/omarchy-themes {
          inherit lib pkgs defaultTemplates;
          inherit (omarchyLib) colors render;
        } { inherit config; };

      devShells = forAllSystems (pkgs: import ./devShells { inherit pkgs; });

      formatter = forAllSystems (pkgs: pkgs.alejandra);
    };
}
