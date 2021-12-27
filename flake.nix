{
  description = "blog.galowicz.de static page generator";

  inputs.nixpkgs.url = github:nixos/nixpkgs/nixos-21.11;
  inputs.flake-utils.url = github:numtide/flake-utils;

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          ghcVersion = "901";
          haskellOverlay = final: prev: let
            inherit (final.haskell.lib) dontCheck;
          in {
            haskellPackages = prev.haskell.packages."ghc${ghcVersion}".override {
              overrides = hFinal: hPrev: {
                shakespeare = dontCheck hPrev.shakespeare;
              };
            };
          };
          pkgs = nixpkgs.legacyPackages.${system}.extend haskellOverlay;
          inherit (pkgs) haskellPackages;
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
            pkgs.nix-gitignore.gitignoreSource nonHaskell ./.;
          blogGenerator = haskellPackages.callCabal2nix "blog" cleanSrc { };
        in
        {
          inherit blogGenerator;

          release = pkgs.stdenv.mkDerivation {
            name = "blog.galowicz.de-content";
            src = pkgs.nix-gitignore.gitignoreSource [ ] ./.;
            buildInputs = [ blogGenerator ];
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

          devShell = haskellPackages.shellFor {
            packages = _: [ blogGenerator ];
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
      );
}
