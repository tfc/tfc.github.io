{
  description = "blog.galowicz.de static page generator";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    (flake-utils.lib.eachSystem [ flake-utils.lib.system.x86_64-linux ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        haskellSrc = pkgs.lib.sourceByRegex ./. [
          "^LICENSE$"
          "^Setup.hs$"
          "^blog.cabal$"
          "^src.*"
        ];
        inherit (pkgs) haskellPackages;
        blog-generator = pkgs.haskellPackages.callCabal2nix "blog" haskellSrc { };

        blogSrc = pkgs.lib.sourceByRegex ./. [
          "^css.*"
          "^images.*"
          "^posts.*"
          "^templates.*"
          "^.*\.md"
        ];

        release = pkgs.stdenv.mkDerivation {
          name = "blog.galowicz.de-content";
          src = blogSrc;
          buildInputs = [ blog-generator ];
          LANG = "en_US.UTF-8";
          LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
          buildPhase = ''
            blog-generator clean
            blog-generator build
          '';
          installPhase = ''
            cp -r _site $out
          '';
        };

      in
      {
        packages = {
          inherit blog-generator release;
          default = release;
        };

        devShells.default = haskellPackages.shellFor {
          packages = _: [ blog-generator ];
          buildInputs = with pkgs; [
            cabal-install
            ghcid
            hlint
            nixpkgs-fmt
            nodePackages.markdownlint-cli
          ];

          # `hoogle server --local`
          withHoogle = true;
        };
      }
    ));
}
