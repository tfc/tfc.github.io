---
layout: post
title: Setting up a C++ project environment with nix
---

This article explains how to quickly set up a C++ project environment with
complete toolchain- and dependency management with `nix`.
[`nix`](https://nixos.org/nix/) is a powerful package manager for Linux and
other Unix systems (It is indeed a more powerful alternative to [`conan`](
https://conan.io/) and [`docker`]( https://www.docker.com/)) that makes package
management reliable and reproducible.
After setting up the project and playing around with it, we will **parametrize**
the project description in order to automatically build it with different
compilers and dependency library versions (GCC 7 & 8, Clang 7 & 8, lib `boost`
1.6.6 - 1.6.9, lib `poco` 1.9.0 & 1.9.1).

<!--more-->

Let's start with a fresh system where no C++ compiler and no development
libraries are installed.
The only tool that we require to be installed is `nix` (see the [installation
guide on nixos.org](https://nixos.org/nix/download.html) for installation
instructions), because we are going to use it to perform the toolchain and
dependency setup.

## Creating a little example C++ Project

Let's write a C++ program with the following dependencies:

- C++ compiler, of course. That might be GCC or Clang.
- `boost` library (<https://www.boost.org>)
- `poco` library (<https://pocoproject.org>)

For the sake of having a simple example app, the program does nothing more than
printing what compiler it was built with and which versions of `boost` and
`poco` it is linked against.

``` bash
#include <boost/lexical_cast.hpp>
#include <Poco/Environment.h>
#include <iostream>

#if defined(__clang__)
#define CC "clang++"
#elif defined (__GNUC__)
#define CC "g++"
#else
#define CC "<unknown compiler>"
#endif

int main() {
  std::cout << "Hello World!\n"
    << "Compiler: " << CC << " " << __VERSION__ << '\n'
    << "Boost: " << (BOOST_VERSION / 100000) << '.'
                 << (BOOST_VERSION / 100 % 1000) << '.'
                 << (BOOST_VERSION % 100) << '\n'
    << "POCO: " << (Poco::Environment::libraryVersion() >> 24) << '.'
                << (Poco::Environment::libraryVersion() >> 16 & 0xff) << '.'
                << (Poco::Environment::libraryVersion() >> 8 & 0xff)
                << '\n';
}
```

We can either *install* a C++ compiler by running `nix-env` with the
appropriate arguments, or just run a shell that exposes a C++ compiler in its
`PATH` environment.
Let us not clutter the system's `PATH` environment with compilers from the
beginning, because often people would use different compilers for each project
anyway.

``` bash
$ nix-shell -p gcc

[nix-shell:~]$ c++ --version
g++ (GCC) 7.4.0
Copyright (C) 2017 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

We are now in a shell that includes GCC's C++ compiler in its `PATH`:

``` bash
[nix-shell:~/src/nix_cmake_example]$ echo $PATH
...:/nix/store/ghzg4kg0sjif58smj2lfm2bdvjwim85y-gcc-wrapper-7.4.0/bin:...
```

I trimmed the rest of the path list.
What's important here: The path list is full of paths that begin with
`/nix/store/...`.
Each of them could be considered what one would call a *package* on typical
Linux distributions.
We can easily install multiple compilers with different versions, or even
the same version with different sets of patches applied, next to each other
in `/nix/store` and not have any of them collide during a project's build,
because `nix` does simply only map the packages into the current `PATH` that
are needed.

> `nix` does even more than just exposing packages via the `PATH` to the
> executing shell: For a running build process it does also hide all paths
> that are *not* listed in the dependencies of a package in order to avoid
> unknown dependencies lurking into the project.
> In order to achieve that, it uses [*namespaces*](
> https://en.wikipedia.org/wiki/Linux_namespaces), similar to [Docker](
> https://www.docker.com/).
> See also: [nixos.wiki about **sandboxing**](
> https://nixos.wiki/wiki/Nix#Sandboxing), and [nix manual: `sandbox` setting
> ](https://nixos.org/nix/manual/#conf-sandbox)

The full procedure of using `nix-shell` to setup the environment and building
and running the app looks like this:

``` bash
$ nix-shell -p gcc boost poco

$ c++ -o main main.cpp -lPocoFoundation -lboost_system

$ ./main
Hello World!
Compiler: g++ 7.4.0
Boost: 1.67.0
POCO: 1.9.0
```

> Running the compiled binary can of course be done without `nix-shell`.

One would typically add a file called `default.nix` to the project folder:

``` nix
with import <nixpkgs> {};

stdenv.mkDerivation {
  name = "my-app";
  src = ./.;

  buildInputs = [ boost poco ];

  buildPhase = "c++ -o main main.cpp -lPocoFoundation -lboost_system";

  installPhase = ''
    mkdir -p $out/bin
    cp main $out/bin/
  '';
}
```

This buys us that we can simply run `nix-build` to configure, build and package
the project into the nix store with a single command.
Developers would still use `nix-shell` for incremental builds between source
modifications.
`nix-shell` does also consult `default.nix` in order to setup the dependencies
right, so we don't need the `-p` parameter list any longer.

Very short overview over the most important lines:

- `stdenv` is an object in the nix expression language that is imported from
  `<nixpkgs>`. `nixpkgs` is a globally available nix expression with all the
  packages. `stdenv` contains the compiler and other things needed to compile
  projects.
- `buildInputs` lists compile time and run time dependencies of the project.
- `buildPhase` is a shell hook that describes how to build the program.
- `installPhase` describes what files should be copied into the nix store.

We're covering how this works in detail only in minimal depth.
More information about nix derivations:

- [`nix` manual section about derivations](
  https://nixos.org/nix/manual/#ssec-derivation)
- <https://nixos.wiki/wiki/C>

> It looks like we're using `nix` as a build system now - in fact,
> `mkDerivation` is a function that creates a so called "builder script" that
> is able to detect if we are using a Makefile based project (with or without
> autoconf), a CMake project, or a set of other build systems, and then
> executes the right steps according to the build system.
> One cool detail is that we would typically not touch `CMakeFile` or other
> files in order to use `nix` - this way users who do not want to or cannot
> use `nix` are able to use their own tools for dependency management.
>
> `mkDerivation` is a very versatile and complex helper: See the [`nix` manual
> section about derivations](https://nixos.org/nix/manual/#ssec-derivation)

In this example we use no build system, hence need to use the `buildPhase`
hook to define how our little application is compiled and linked.

Someone else who checks out this project and who has installed `nix` can
now simply run:

``` bash
$ nix-build
these derivations will be built:
/nix/store/dw9d2r7rykym08fzmdgf6v0ia2sn6hq9-my-app.drv
building '/nix/store/dw9d2r7rykym08fzmdgf6v0ia2sn6hq9-my-app.drv'...
unpacking sources
unpacking source archive /nix/store/8zwsvxdkpjnyxnm9qs33qw3bi12h9gbm-nix_simple
source root is nix_simple
patching sources
configuring
no configure script, doing nothing
building
installing
post-installation fixup
shrinking RPATHs of ELF executables and libraries in /nix/store/5ldpivphfbya4xw6kcss9vcdvp1mzrcf-my-app
shrinking /nix/store/5ldpivphfbya4xw6kcss9vcdvp1mzrcf-my-app/bin/main
strip is /nix/store/0y7jmqnj48ikjh37n3dl9kqw9hnn68nq-binutils-2.31.1/bin/strip
stripping (with command strip and flags -S) in /nix/store/5ldpivphfbya4xw6kcss9vcdvp1mzrcf-my-app/bin
patching script interpreter paths in /nix/store/5ldpivphfbya4xw6kcss9vcdvp1mzrcf-my-app
checking for references to /tmp/nix-build-my-app.drv-0/ in /nix/store/5ldpivphfbya4xw6kcss9vcdvp1mzrcf-my-app...
/nix/store/5ldpivphfbya4xw6kcss9vcdvp1mzrcf-my-app

$ ./result/bin/main
Hello World!
Compiler: g++ 7.4.0
Boost: 1.67.0
POCO: 1.9.0
```

The compiler, all libraries etc. are automatically downloaded and put into
action.
Much simpler than with [conan](https://conan.io/)!

That is basically it: If the program grows, we will certainly switch
to some build system - `nix` supports that without having to add nix-specific
stuff into the build files (GNUMake, CMake, meson, etc. are supported.
Have a look into the [`nixpkgs` git repository folder for supported build
systems](https://github.com/NixOS/nixpkgs/tree/master/pkgs/development/tools/build-managers)).
If the number of dependencies grows, be that libraries or compile time tools,
we can simply add them to the nix expression.

## Building the code with different dependency versions

The `default.nix` expression results in one so-called *derivation* that `nix`
can materialize into a binary package in the nix storage.
Let us now write another nix expression that takes multiple `boost` library
versions, multiple `poco` library versions and multiple compilers, and
that results in a *set* of derivations that nix can materialize using those.

We will use the following variety of dependency versions:

- GCC 7 & 8
- Clang 7 & 8
- lib `poco` 1.9.0 & 1.9.1
- lib `boost` 1.6.6 - 1.6.9

...which results in $2 * 2 * 2 * 4 = 32$ different binaries.

Quick spoiler: The result of the nix expression that we are going to write
will allow us to build and execute these 32 binaries with a single `nix-build
release.nix` command.

``` bash
$ for path in $(nix-build release.nix); do \
>   echo "===="; \
>   echo "Output of $path/bin/main:"; \
>   $path/bin/main; \
> done
# trimmed a lot of build output...
====
Output of /nix/store/246an1m3rwwgz58qc8hfwvqh28899ckm-my-app-clang7-poco190-boost166/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 7.0.1 (tags/RELEASE_701/final)
Boost: 1.66.0
POCO: 1.9.0
====
Output of /nix/store/cfh1cy03kly9wq6x6dzlza4d9kads6cd-my-app-clang7-poco190-boost167/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 7.0.1 (tags/RELEASE_701/final)
Boost: 1.67.0
POCO: 1.9.0
====
Output of /nix/store/jjbpj24x4gp2vpn355j0qsy117yrkhrd-my-app-clang7-poco190-boost168/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 7.0.1 (tags/RELEASE_701/final)
Boost: 1.68.0
POCO: 1.9.0
====
Output of /nix/store/f9fgwzpq9gn85abx9h1zr5c6j3bs4ks2-my-app-clang7-poco190-boost169/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 7.0.1 (tags/RELEASE_701/final)
Boost: 1.69.0
POCO: 1.9.0
====
Output of /nix/store/1wwff8p5rxjqjkhqifvhy833bl3mf8l3-my-app-clang7-poco191-boost166/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 7.0.1 (tags/RELEASE_701/final)
Boost: 1.66.0
POCO: 1.9.1
====
Output of /nix/store/3jdv2l0gp3za4q5rj8s4859bpiyscg0m-my-app-clang7-poco191-boost167/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 7.0.1 (tags/RELEASE_701/final)
Boost: 1.67.0
POCO: 1.9.1
====
Output of /nix/store/fcbypavfzrw8ajngaim7srvn9fylj7b3-my-app-clang7-poco191-boost168/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 7.0.1 (tags/RELEASE_701/final)
Boost: 1.68.0
POCO: 1.9.1
====
Output of /nix/store/a8d1mwqiay3qx60fzp6m70q89s0mpcwx-my-app-clang7-poco191-boost169/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 7.0.1 (tags/RELEASE_701/final)
Boost: 1.69.0
POCO: 1.9.1
====
Output of /nix/store/lhxdhmi9ficg9v9mkxv4zz9s4759r5z6-my-app-clang8-poco190-boost166/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 8.0.0 (tags/RELEASE_800/final)
Boost: 1.66.0
POCO: 1.9.0
====
Output of /nix/store/x4f34gi6p6ipa8lvqx2aj36nzipk2yv1-my-app-clang8-poco190-boost167/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 8.0.0 (tags/RELEASE_800/final)
Boost: 1.67.0
POCO: 1.9.0
====
Output of /nix/store/dqmy8gmkshi8glg2ldidpclzq2mrqbvw-my-app-clang8-poco190-boost168/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 8.0.0 (tags/RELEASE_800/final)
Boost: 1.68.0
POCO: 1.9.0
====
Output of /nix/store/s5qw1ff2qbx2aswnlvd7l7d60fdfyr0y-my-app-clang8-poco190-boost169/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 8.0.0 (tags/RELEASE_800/final)
Boost: 1.69.0
POCO: 1.9.0
====
Output of /nix/store/wf4ygk9lhkmfv98f9g05pndv4a0320j1-my-app-clang8-poco191-boost166/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 8.0.0 (tags/RELEASE_800/final)
Boost: 1.66.0
POCO: 1.9.1
====
Output of /nix/store/xg34s1bzr2h57hsbj6z0g93mwni7jcgk-my-app-clang8-poco191-boost167/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 8.0.0 (tags/RELEASE_800/final)
Boost: 1.67.0
POCO: 1.9.1
====
Output of /nix/store/bhjzyxr1wpjnkdr1wm72142l0hlndsnz-my-app-clang8-poco191-boost168/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 8.0.0 (tags/RELEASE_800/final)
Boost: 1.68.0
POCO: 1.9.1
====
Output of /nix/store/r1nd2gb7r45vpldnbiprdnyg7y29k08f-my-app-clang8-poco191-boost169/bin/main:
Hello World!
Compiler: clang++ 4.2.1 Compatible Clang 8.0.0 (tags/RELEASE_800/final)
Boost: 1.69.0
POCO: 1.9.1
====
Output of /nix/store/3jfbck6mcrgjfpya8p8x293sfkqi0w5b-my-app-gcc7-poco190-boost166/bin/main:
Hello World!
Compiler: g++ 7.4.0
Boost: 1.66.0
POCO: 1.9.0
====
Output of /nix/store/cvlxdps8k666dgim3xp04xkm4qzbvkby-my-app-gcc7-poco190-boost167/bin/main:
Hello World!
Compiler: g++ 7.4.0
Boost: 1.67.0
POCO: 1.9.0
====
Output of /nix/store/ipk381rlahkv6wbwccmv7pibwghdbw7c-my-app-gcc7-poco190-boost168/bin/main:
Hello World!
Compiler: g++ 7.4.0
Boost: 1.68.0
POCO: 1.9.0
====
Output of /nix/store/pl9y9njmyc2ws4i4mgfnhdxxsbrzasj3-my-app-gcc7-poco190-boost169/bin/main:
Hello World!
Compiler: g++ 7.4.0
Boost: 1.69.0
POCO: 1.9.0
====
Output of /nix/store/svxr6826wm0sx9mm8sgy1v2aq2v1nx2p-my-app-gcc7-poco191-boost166/bin/main:
Hello World!
Compiler: g++ 7.4.0
Boost: 1.66.0
POCO: 1.9.1
====
Output of /nix/store/hfwv308iaykb4ygnjpjfxwy6xf1rr0s3-my-app-gcc7-poco191-boost167/bin/main:
Hello World!
Compiler: g++ 7.4.0
Boost: 1.67.0
POCO: 1.9.1
====
Output of /nix/store/2bxawcdkgjbvn756q93r65vym19b2jip-my-app-gcc7-poco191-boost168/bin/main:
Hello World!
Compiler: g++ 7.4.0
Boost: 1.68.0
POCO: 1.9.1
====
Output of /nix/store/zgzw1bbx935fm209lxnn01n14sv8f9a8-my-app-gcc7-poco191-boost169/bin/main:
Hello World!
Compiler: g++ 7.4.0
Boost: 1.69.0
POCO: 1.9.1
====
Output of /nix/store/jgsxmqgwmqqv2sbcmnx63abb3ymfsqc5-my-app-gcc8-poco190-boost166/bin/main:
Hello World!
Compiler: g++ 8.3.0
Boost: 1.66.0
POCO: 1.9.0
====
Output of /nix/store/3j9q4bn2id2iqza44n39mzi4cqzhqlz2-my-app-gcc8-poco190-boost167/bin/main:
Hello World!
Compiler: g++ 8.3.0
Boost: 1.67.0
POCO: 1.9.0
====
Output of /nix/store/7czfqh3fbjpslnar101b472kzlhxlcdc-my-app-gcc8-poco190-boost168/bin/main:
Hello World!
Compiler: g++ 8.3.0
Boost: 1.68.0
POCO: 1.9.0
====
Output of /nix/store/9vmwm0zzsgxqm6v5yxzjdjkhgxqqdnqr-my-app-gcc8-poco190-boost169/bin/main:
Hello World!
Compiler: g++ 8.3.0
Boost: 1.69.0
POCO: 1.9.0
====
Output of /nix/store/n34v5f23jhpcc20hyszdn270p9wyzfbz-my-app-gcc8-poco191-boost166/bin/main:
Hello World!
Compiler: g++ 8.3.0
Boost: 1.66.0
POCO: 1.9.1
====
Output of /nix/store/bq9pijnw746ilp1ar8xwb7bl3v1ypy0y-my-app-gcc8-poco191-boost167/bin/main:
Hello World!
Compiler: g++ 8.3.0
Boost: 1.67.0
POCO: 1.9.1
====
Output of /nix/store/pzqa2sraf1xhji9bk6namwg6x4ar9sgq-my-app-gcc8-poco191-boost168/bin/main:
Hello World!
Compiler: g++ 8.3.0
Boost: 1.68.0
POCO: 1.9.1
====
Output of /nix/store/vb3ha6skwnj2h5k691jxcn7pxa8gs90i-my-app-gcc8-poco191-boost169/bin/main:
Hello World!
Compiler: g++ 8.3.0
Boost: 1.69.0
POCO: 1.9.1
```

As the first step, let us first decompose the `default.nix` file into a file
`derivation.nix` and another file `release.nix`.

The new `derivation.nix` file contains the pure package description without
knowledge about where the dependencies come from:

``` nix
{ boost, poco, stdenv }:

stdenv.mkDerivation {
  name = "my-app";
  src = ./.;

  buildInputs = [ boost poco ];

  buildPhase = "c++ -std=c++17 -o main main.cpp -lPocoFoundation -lboost_system";

  installPhase = ''
    mkdir -p $out/bin
    cp main $out/bin/
  '';
}
```

The first line states that the content of this file is a *function* that
accepts a dictionary with the keys `boost`, `poco`, and `stdenv` as input
arguments.
It does then finally return a derivation.
A derivation can be materialized into a package with the binary by `nix`.

This means that we can regard `derivation.nix` like a mathematical function
\
$deriv (compiler, boost, poco) \rightarrow derivation$.

The next step is then to use that function $deriv$ and feed it with the cartesian
product of all 32 input combinations.
The file `release.nix` does just that:

``` { .numberLines .nix }
{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {}
}:

let
  compilers = with pkgs; {
    gcc7 = stdenv;
    gcc8 = overrideCC stdenv gcc8;
    clang7 = overrideCC stdenv clang_7;
    clang8 = overrideCC stdenv clang_8;
  };

  pocoLibs = {
    poco190 = pkgs.poco;
    poco191 = pkgs.poco.overrideAttrs (oldAttrs: {
      name = "poco-1.9.1";
      src = pkgs.fetchzip {
        url = "https://github.com/pocoproject/poco/archive/poco-1.9.1.zip";
        sha256 = "0d5d6cxv5k0r0kcr2zjsxzjbpd8s1x8dmwzsjh04yq470i8jw9zz";
      };
    });
  };

  boostLibs = {
    inherit (pkgs) boost166 boost167 boost168 boost169;
  };

  originalDerivation = [ (pkgs.callPackage (import ./derivation.nix) {}) ];

  f = libname: libs: derivs: with pkgs.lib;
    concatMap (deriv:
      mapAttrsToList (libVers: lib:
        (deriv.override { "${libname}" = lib; }).overrideAttrs
          (old: { name = "${old.name}-${libVers}"; })
      ) libs
    ) derivs;

  overrides = [
    (f "stdenv" compilers)
    (f "poco"   pocoLibs)
    (f "boost"  boostLibs)
  ];
in
  pkgs.lib.foldl (a: b: a // { "${b.name}" = b; }) {} (
    pkgs.lib.foldl (a: f: f a) originalDerivation overrides
  )
```

This code looks a bit more complicated, but it does a lot of things:

- It defines the variety of compilers and libraries in the variables
  `compilers`, `pocoLibs`, and `boostLibs`.
  - note that `nixpkgs` already contains lib `poco` version 1.9.0, but not
    1.9.1 - we simply override its package description to use the latest 1.9.1
    source from poco's github repository.
- Function `f` contains all the magic: It reapplies the original function
  `deriv` with one library input overloaded from a library list argument!
- The list `overrides` contains the list of function `f` applications that
  shall be applied over the original derivation.
- The last 2 lines of code apply all the transformations within a simple `fold`

This explanation is very brief.
The whole code might look pretty much familiar to everyone who is not used to
nix but has some experience with purely functional programming languages.
Explaining the code in detail to developers who neither know `nix` nor any
functional programming, would explode the scope of this article.

## Summary

We have seen how simple it is to quickly set up an ad-hoc C++ programming
environment with a compiler and libraries, without cluttering the system.

We have "packaged" our little project with a roughly ~10 LOC short `default.nix`
Users with solely `nix` installed can clone this project from git, run
`nix-build` and get the binary. Simple as that.

With less than 50 LOC we implemented a nix expression that builds our
application in 32 different variants with different compilers and library
versions.

There is a git repository with all project files that is available for checkout:
<https://github.com/tfc/nix_cpp_cartesian_dependencies>

## Outlook

What else can be done from here? The advantages and strengths of `nix` have
*by far* not been exhausted in this example.

### Maximum Reproducibility: Pinning `nixpkgs`

Whenever we referenced packages, we got them from the magical nix expression
`<nixpkgs>`.
This package source is a *channel* that can be updated with `nix-channel
--update`, which is similar to running `apt-get update` on Debian-like Linux
distros.
Of course, an update of the channel also updates the packages and thus might
break the whole build.

With `nix`, we can simply **pin** the package list to a version that is known
to work.

In the github repository of this example, i did so with [nixpkgs.nix](
https://github.com/tfc/nix_cpp_cartesian_dependencies/blob/master/nixpkgs.nix).

Using this technique, one can be pretty confident, that the project will
still work in all configurations in a few years, which makes our build procedure
pretty reproducible.

### Nix CI: Hydra

Since `nix` is simply a tool that can be installed on Linux, Mac, and other UNIX
systems, it can also be run in different CIs.

The NixOS project does however come with its own CI:
[Hydra](https://nixos.org/hydra/).
I am running my own instance on <https://hydra.kosmosgame.com> and installed
this project as a jobset on it:

[This article's project in hydra](https://hydra.kosmosgame.com/jobset/github/nix_cpp_cartesian_dependencies#tabs-jobs)

The code does a bit more than covered in this article:
I added a nix expression [`output.nix`](
https://github.com/tfc/nix_cpp_cartesian_dependencies/blob/master/output.nix)
that does not only build the application in all variants, but also executes
them and stores their results in the nix store.
This way they can be looked at in the browser like here: [example output](
https://hydra.kosmosgame.com/build/265)

### Fully Reproducible, Automatic Integration Tests

Nix expressions do not only allow for simple ad-hoc packaging of binaries:
They are mighty enough to describe whole-system descriptions.
In fact, the NixOS installer ISOs, the Virtualbox NixOS demo VM image, the
Amazon AMIs, Microsoft Azure Blobs, etc. are all built from nix expressions.

I build a little more complicated example and put it on github:
<https://github.com/tfc/nix_cmake_example>

In a nutshell, this repository contains a C++ server application that uses
PostgreSQL as a database backend and a Python client application that provides
a little web server interface to the same database.
In order to test such an application one needs a host with a confiured and
running PostgreSQL instance.

The C++ app is built in different configurations - all configurations are
automatically tested in VMs that are automatically created, spun up, and
destroyed afterwards.

![Hydra example output](
https://github.com/tfc/nix_cmake_example/raw/master/doc/hydra_nix_example.png)

The whole output can be inspected on
<https://hydra.kosmosgame.com/jobset/github/nix_cmake_example#tabs-jobs>

### Cross Compilation

Just touching this topic by dropping some links

- <https://nixos.wiki/wiki/Cross_Compiling>
- <https://matthewbauer.us/blog/beginners-guide-to-cross.html>
