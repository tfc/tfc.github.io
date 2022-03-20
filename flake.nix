{
  description = "blog.galowicz.de static page generator";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixos-21.11;
    flake-utils.url = github:numtide/flake-utils;
    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;
    flake-compat-ci.url = "github:hercules-ci/flake-compat-ci";
  };

  outputs = { self, nixpkgs, flake-utils, flake-compat, flake-compat-ci }:
    (flake-utils.lib.eachDefaultSystem
      (system:
        let
          # this is an overly specific selection. This is just for fun.
          ghcVersion = "901";
          haskellOverlay = final: prev: let
            cleanSrc =
              let
                nonHaskell = [
                  "*.nix"
                  "css"
                  "deploy.sh"
                  "images"
                  "nix"
                  "posts"
                  "templates"
                ];
              in
              final.nix-gitignore.gitignoreSource nonHaskell ./.;
            inherit (final.haskell.lib) dontCheck;
          in {
            #haskellPackages = prev.haskell.packages."ghc${ghcVersion}".override {
            haskellPackages = prev.haskellPackages.override {
              overrides = hFinal: hPrev: {
                shakespeare = dontCheck hPrev.shakespeare;
                blog-generator = hFinal.callCabal2nix "blog" cleanSrc {};
              };
            };
          };
          pkgs = nixpkgs.legacyPackages.${system}.extend haskellOverlay;
          inherit (pkgs) haskellPackages;
          inherit (pkgs.haskellPackages) blog-generator;

          release = pkgs.stdenv.mkDerivation {
            name = "blog.galowicz.de-content";
            src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
            buildInputs = [ blog-generator ];
            buildPhase = ''
              export LANG="en_US.UTF-8"
              export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
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
          };

          defaultPackage = release;

          devShell = haskellPackages.shellFor {
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
        )) // {
    ciNix = flake-compat-ci.lib.recurseIntoFlakeWith {
      flake = self;
      systems = [ "x86_64-linux" ];
    };
  };
}
