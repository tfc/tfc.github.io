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
          pkgs = nixpkgs.legacyPackages.${system};
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
          inherit (pkgs) haskellPackages;
          blog-generator = pkgs.haskellPackages.callCabal2nix "blog" cleanSrc { };

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
