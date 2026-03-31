{
  description = "Nix-first setup for damnenv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, nixgl }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
      mkPkgs = system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ nixgl.overlay ];
        };
      damnenvModule = import ./nix/modules/damnenv.nix;
    in
    {
      homeManagerModules.default = damnenvModule;
      homeManagerModules.damnenv = damnenvModule;

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          packageSet = import ./nix/package-set.nix { inherit lib pkgs; };
          bundle = pkgs.buildEnv {
            name = "damnenv-packages";
            paths = packageSet.full;
          };
        in
        {
          default = bundle;
          damnenv = bundle;
          damnenv-packages = bundle;
        }
      );

      homeConfigurations.default =
        let
          system = builtins.currentSystem;
          pkgs = mkPkgs system;
          username =
            let value = builtins.getEnv "USER"; in
            if value != "" then value else "p";
          homeDirectory =
            let value = builtins.getEnv "HOME"; in
            if value != "" then value else "/home/${username}";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { repoRoot = self; };
          modules = [
            damnenvModule
            {
              home = {
                inherit username homeDirectory;
                stateVersion = "25.05";
              };

              programs.home-manager.enable = true;

              damnenv.enable = true;
              damnenv.theme =
                let
                  value = builtins.getEnv "DAMNENV_THEME";
                  legacyValue = builtins.getEnv "RANG_THEME";
                in
                if value != "" then value else if legacyValue != "" then legacyValue else "night-owl";
            }
          ];
        };
    };
}
