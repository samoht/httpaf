{
  description = "HTTP/AF Nix Flake";

  inputs.nix-filter.url = "github:numtide/nix-filter";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.inputs.flake-utils.follows = "flake-utils";
  inputs.nixpkgs.url = "github:anmonteiro/nix-overlays/anmonteiro/eio-0.12";

  outputs = { self, nixpkgs, flake-utils, nix-filter }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend (self: super: {
          ocamlPackages = super.ocaml-ng.ocamlPackages_5_1;
        });
      in
      rec {
        packages = pkgs.callPackage ./nix { nix-filter = nix-filter.lib; };
        defaultPackage = packages.httpaf;
        devShell = pkgs.callPackage ./shell.nix { inherit packages; };
      });
}
