let
  sources = import ./nix/sources.nix { };
  pkgs = import sources.nixpkgs { };

  haskellPackages = pkgs.haskell.packages.ghc901;

  cleanSrc = let
    nonHaskell = [
      "*.nix"
      "css"
      "deploy.sh"
      "images"
      "nix"
      "posts"
      "templates"
    ];
  in pkgs.nix-gitignore.gitignoreSource nonHaskell ./.;
in
rec {
  blog-generator = haskellPackages.callCabal2nix "blog" cleanSrc { };

  release = pkgs.stdenv.mkDerivation {
    name = "blog.galowicz.de-content";
    src = ./.;
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

  dev-shell = haskellPackages.shellFor {
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
