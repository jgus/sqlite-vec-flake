{
  description = "sqlite-vec: native extension and Python bindings version-bumped ahead of nixpkgs.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-lib = {
      url = "github:jgus/flake-lib/v1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { nixpkgs, flake-utils, flake-lib, ... }:
    let
      pin = import ./pin.nix;
      inherit (pin) version sourceRev sourceHash;
      source = { type = "github"; owner = "asg017"; repo = "sqlite-vec"; };
      overlay = final: prev:
        let
          src = final.fetchFromGitHub {
            owner = "asg017";
            repo = "sqlite-vec";
            rev = sourceRev;
            hash = sourceHash;
          };
          sqliteVec = prev.sqlite-vec.overrideAttrs (_: {
            inherit version src;
          });
        in
        {
          sqlite-vec = sqliteVec;
          pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
            (pyfinal: pyprev: {
              sqlite-vec = pyprev.sqlite-vec.overridePythonAttrs (prevAttrs: {
                inherit version src;
                SETUPTOOLS_SCM_PRETEND_VERSION = version;
                dependencies = [ sqliteVec ];
                nativeCheckInputs = builtins.filter
                  (input: (input.pname or "") != "sqlite-vec")
                  (prevAttrs.nativeCheckInputs or [ ]) ++ [ sqliteVec ];
                postPatch = ''
                  cd python
                  mv extra_init.py sqlite_vec/
                  substituteInPlace sqlite_vec/__init__.py \
                    --replace-fail "@libpath@" "${final.lib.getLib sqliteVec}/lib/"
                '';
              });
            })
          ];
        };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            sqlite-vec = pkgs.python3.pkgs.sqlite-vec;
            default = pkgs.python3.pkgs.sqlite-vec;
            update-version = flake-lib.lib.mkUpdateVersion { inherit pkgs source; buildAttr = "sqlite-vec"; };
            update-branches = flake-lib.lib.mkUpdateBranches { inherit pkgs source; pinSchema = "github"; };
          };
        }) // {
      overlays.default = overlay;
    };
}
