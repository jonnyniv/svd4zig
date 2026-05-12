{
  description = "Basic zig flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      syspkgs = forAllSystems (system: nixpkgs.legacyPackages.${system});
    in
    {
      formatter = forAllSystems (system: syspkgs.${system}.nixfmt-tree);
      devShell = forAllSystems (
        system:
        syspkgs.${system}.mkShell {
          packages = with syspkgs.${system}; [
            zls_0_16
            zig_0_16
          ];
        }
      );
    };
}
