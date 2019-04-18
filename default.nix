{
  nixpkgs ? <nixpkgs>, #import ./nixpkgs.nix,
  pkgs ? import nixpkgs {},
  compiler ? "default",
  doBenchmark ? false
}:

let
  f = import ./derivation.nix;
  haskellPackages = if compiler == "default"
                       then pkgs.haskellPackages
                       else pkgs.haskell.packages.${compiler};

  variant = if doBenchmark then pkgs.haskell.lib.doBenchmark else pkgs.lib.id;
  drv = variant (haskellPackages.callPackage f {});
in
  if pkgs.lib.inNixShell then drv.env else drv
