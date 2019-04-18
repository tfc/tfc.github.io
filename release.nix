with import (import ./nixpkgs.nix) {};

pkgs.stdenv.mkDerivation {
  name = "blog.galowicz.de-content";
  src = ./.;
  buildInputs = [ (import ./default.nix {}) ];
  buildPhase = "blog-generator build";
  installPhase = ''
    cp -r _site $out
  '';
}
