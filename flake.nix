{
  description = "kirjaimia, jotka jätän piirtämättä — poem site";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        hs = pkgs.haskellPackages;
        site = hs.callCabal2nix "poems-platform" ./. { };
      in {
        packages.default = site;
        apps.default = flake-utils.lib.mkApp { drv = site; exePath = "/bin/site"; };
        devShells.default = hs.shellFor {
          packages = _: [ site ];
          nativeBuildInputs = [ pkgs.cabal-install pkgs.nodejs pkgs.git-crypt ];
        };
      });
}
