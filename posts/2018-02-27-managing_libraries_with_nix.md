---
layout: post
title: Managing libraries with Nix
---

While learning Haskell and using its really smart library dependency management tools ([`cabal`](https://www.haskell.org/cabal/) and [`stack`](https://docs.haskellstack.org/en/stable/README/)), i realized that the C++ eco system has a problem:
There are no handy _established_ tools that let the developer declare which libraries (and versions) are required for a project which can then be automatically installed in a portable way.
[`Nix`](https://nixos.org/nix/) however convinced me to be more versatile and powerful than [Conan](https://www.conan.io/) and handier than [Docker](https://www.docker.com/), [Vagrant](https://www.vagrantup.com/), etc. (although it's fair to say that i am mixing use cases here a little bit!)
In this article, i am going to showcase this great tool a little bit.

<!--more-->

This article is rather long (mostly because of many command line excerpts).
Feel free to jump to the end, where we will compile and run the same project with 3 different compilers just by changing the command line a bit.

## Use case example

So i have been developing a little library to see if i can implement a handy parser library in C++ that models how you build parsers in Haskell using the [`parsec` library](https://hackage.haskell.org/package/parsec).

The project can be checked out on [github.com/tfc/attoparsecpp](https://github.com/tfc/attoparsecpp). It is however not important to look into it.
This article is not at all about parsers, Haskell, or my specific library.
My little project shall just serve as an example project that has unit tests and benchmarks.

For libraries it is important that they build warning-free with:

- different compilers
- even different compiler versions

In addition to that, it is a nice-to-have to also compare the benchmark numbers among those!

However, the library has the following dependencies:

- [`catch`](https://github.com/catchorg/Catch2) for building the unit tests
- [`benchmark` (from Google)](https://github.com/google/benchmark) for building the benchmarks

That means: in order to build this project you need to install those.
Some developers just install them the oldschool way or they pull them in as git submodules and then embedd them into the `Makefile` (or `cmake` pendants etc.).
Some other developers would define Docker images (or Vagrant etc.).
There is also the Conan package manager which enables the developer to just define which libraries are needed.

## Installing Nix

Let us now completely concentrate on Nix. What is it? [The Nix homepage](https://nixos.org/nix/) states:

> Nix is a powerful package manager for Linux and other Unix systems that makes package management reliable and reproducible.
> It provides atomic upgrades and rollbacks, side-by-side installation of multiple versions of a package, multi-user package management and easy setup of build environments.
> ...

Nix can be installed on Linux, Mac, and other Unixes.
(I guess it can be installed in the Linux-Subsystem on Windows, but i am not sure as i am no Windows user).
Just as a side note: There is even a [Linux distribution called "NixOS"](https://nixos.org/).

The installation of Nix is really simple.
Please first study the content of [`https://nixos.org/nix/install`](https://nixos.org/nix/install) and then run the following command in the bash (Or run the parts of the script you like. It is interesting how about 90% of the critisizm on Nix concentrate on this shell command.):

``` bash
$ curl https://nixos.org/nix/install | sh
```

The installation script will download and extract a large tarball into the `/nix` folder on your system.
In order to create that directory, `sudo` has to be used once.
After the installation, there will never be any need to use `sudo` in combination with nix calls again.
It is generally possible to install nix on systems where even creating `/nix` is not allowed (see the [installation guide](https://nixos.wiki/wiki/Nix_Installation_Guide) for more details).

> Everything can be removed again by just deleting `/nix` and removing the bash profile changes that make the nix binaries visible.

## Installing project dependencies

After cloning the C++ project on a mac where only `git` and `clang++`, we will have trouble building the project without installing the libraries:

``` bash
$ cd test && make
c++ -O2 -std=c++14 -c main.cpp
main.cpp:2:10: fatal error: 'catch/catch.hpp' file not found
#include <catch/catch.hpp>
         ^~~~~~~~~~~~~~~~~
1 error generated.
make: *** [main.o] Error 1
```

For the unit tests, we only need the `catch` library.
That's easy, as the Nix repository has that.

> Another "catch" is that the `make` call ended up invoking `c++`, which is our Mac system compiler that is not really prepared to be used with Nix-installations of packages.
> This is part of some mechanics which the Nix docs cover much better.

``` bash
$ nix-env -qaP --description | grep catch
nixpkgs.catch               catch-1.9.6               A multi-paradigm automated test framework for C++ and Objective-C (and, maybe, C)
# ...
```

So let's build it with catch installed:

```
$ nix-shell -p clang -p catch

[nix-shell:~/project_dir]$ cd test && make
clang++ -O2 -std=c++14 -c main.cpp
clang++ -O2 -std=c++14 -I../include -c test.cpp
test.cpp:127:46: error: too many arguments provided to function-like macro invocation
            REQUIRE( r->first == vect_t{'a', 'b', 'c'});
                                             ^
/nix/store/gsklw95pxb9npyqpfpczagchk8kdsgzb-catch-1.9.6/include/catch/catch.hpp:11450:9: note: macro 'REQUIRE' defined here
#define REQUIRE( expr ) INTERNAL_CATCH_TEST( "REQUIRE", Catch::ResultDisposition::Normal, expr  )
# ...
```

Ok, the compiler can find the `catch.hpp` header, but it does not compile.
The problem here is that i wrote the unit tests with `catch2` and the package in the Nix repo is a little bit too old.
I learned Nix the hard way by doing the following:

## Writing our own Nix expressions

The Nix ecosystem provides a rich database of packages for everything which does not only include libraries, but also applications.
In this case however, the library is too old and we need a more current one.

While the `catch` library just consists of a single header that is really easy to download, it is also a really simple example for building a Nix derivation that automatically obtains it from github and provides it for building.
So let's do that here. We will also install a newer google benchmark library (which is a bit more complicated as it is not header-only) this way later.

A Nix derivation is kind of a cooking recipe that tells where to get what and what to do with it in order to make it useful.
In order to get catch version 2.1.2, we create a file `catch.nix` in the project folder:

``` { .numberLines }
# file: catch.nix
{ stdenv, fetchurl }:

stdenv.mkDerivation rec {
  name = "catch-${version}";
  version = "2.1.2";

  src = fetchurl {
      url = "https://github.com/catchorg/Catch2/releases/download/v2.1.2/catch.hpp";
      sha256 = "e8b8f3109716891aa99b1a8e29cd0d627419bdc4a8d2eeef0d8370aaf8d5e483";
  };

  # It is just the file. No unpacking needed. Seems like we need to create
  # _some_ folder, otherwise we get errors.
  unpackCmd = "mkdir dummy_dir";

  installPhase = ''
    mkdir -p $out/include/catch
    cp ${src} $out/include/catch/catch.hpp
  '';

  meta = {
    description = "A modern, C++-native, header-only, test framework for unit-tests, TDD and BDD - using C++11, C++14, C++17 and later";
    homepage = http://catch-lib.net;
  };
}
```


There is a lot of *voodoo* going on here for anyone who does not know Nix.
Nix is its own scripting language (a purely functional one), that is why it that script initially looks so complicated.
The important parts are:

- lines 8-11, `fetchurl`:
    - Where to get the catch header file?
    - For control reasons we also define what hash it needs to have.
- lines 17-20, `installPhase`:
    - We define that `catch.hpp` needs to be installed into `$out/include/catch/catch.hpp`, wherever that is.

Let us bring `nix-shell` to use that file and install catch for us:

``` bash
$ nix-shell -p 'with (import <nixpkgs> {}); callPackage ./catch.nix {}'
these derivations will be built:
  /nix/store/byy8sgy8crdhzyvjxzzbq4zhg8kbvhpp-catch.hpp.drv
  /nix/store/v75n72czr0vgqz4zacrzk2wsrr1jg1kc-catch-2.1.2.drv
these paths will be fetched (0.82 MiB download, 4.50 MiB unpacked):
  /nix/store/0cs9d2ml9cql18l1vsxrdmjliiz0p0rg-bash-4.4-p12-info
  /nix/store/0p2m9iz8w4551qkgzsqvl2vm2ilyb6ww-stdenv-darwin
  /nix/store/2pvbzmacxfhm1akl9a5shqrk47i53cpv-libssh2-1.8.0-dev
  /nix/store/cxz0drsrlbmdi1krr0n57zfcswjmrv5i-mirrors-list
  /nix/store/czw3qnwsify74b5bljll1lmm8k6kk09h-curl-7.55.1-dev
  /nix/store/icm30zksjzx8546d02y9gi4vzdi42j2w-bash-4.4-p12-man
  /nix/store/kwclw4knsrs6l4fi98wnzg713r8p0wls-openssl-1.0.2l-dev
  /nix/store/n2aycrbi6myl9wqr6b7w2n578j505czd-curl-7.55.1-man
  /nix/store/w4m16gcmlxsgx468p7k3993vwf6i6hsx-bash-4.4-p12-dev
  /nix/store/yw461g3iqihmq6i1mrjn6khbwn6gx0rl-bash-4.4-p12-doc
# ...
building path(s) ‘/nix/store/62g4h135grzi5xn5y7hyrxg1r8ac408g-catch-2.1.2’
unpacking sources
unpacking source archive /nix/store/4nx2d1j5jnnb9zqlmpl45g68msqycfjy-catch.hpp
# ...
patching script interpreter paths in /nix/store/62g4h135grzi5xn5y7hyrxg1r8ac408g-catch-2.1.2
```

There was a lot going on after firing that command: Nix even installed `curl` and all its dependencies, because it needs a tool to download the header file.
The last line tells us that there is now something in `/nix/store/62g4h135grzi5xn5y7hyrxg1r8ac408g-catch-2.1.2
`.
Let's have a look into it:

``` bash
[nix-shell:~/Desktop/p]$ ls -lsa /nix/store/62g4h135grzi5xn5y7hyrxg1r8ac408g-catch-2.1.2/include/catch/catch.hpp
428 -r--r--r-- 1 root wheel 435409 Jan  1  1970 /nix/store/62g4h135grzi5xn5y7hyrxg1r8ac408g-catch-2.1.2/include/catch/catch.hpp
```

Ok, so whenever we add this strange path to the compiler command line using `-I/nix/store/...`, then our tests will compile.

Let's again start the nix shell with our catch derivation and clang and GNU make and try again:

``` bash
$ nix-shell -p clang 'with (import <nixpkgs> {}); callPackage ./catch.nix {}'

[nix-shell:~/project_dir]$ cd test && make
clang++ -O2 -std=c++14 -c main.cpp
clang++ -O2 -std=c++14 -I../include -c test.cpp
clang++ -O2 -std=c++14 -I../include -c math_expression.cpp
clang++ -o main main.o test.o math_expression.o

[nix-shell:~/project_dir]$ ./main
===============================================================================
All tests passed (172 assertions in 11 test cases)
```

Yes, that went well!

> (The `-I/nix/store/...` parameter was handled for us implicitly) by the Nix-installed compiler

It is however pretty ugly to call `nix-shell` with all those arguments that are hard to memorize.
For this purpose we can define a `default.nix` file that will be automatically sourced by Nix:

```
# file: default.nix
{ pkgs ? import <nixpkgs> {}, }:
rec {
  myProject = pkgs.stdenv.mkDerivation {
    name = "attoparsecpp";
    version = "dev-0.1";
    buildInputs = with pkgs; [
      (callPackage ./catch.nix { })
    ];
  };
}
```

There's again some voodoo for Nix-novices, but the important part is that we call our package `catch.nix` in the context of a standard build environment (`stdenv`).
With `stdenv` we don't need to reference the compiler explicitly any longer.

Now, we can do the following:

``` bash
$ nix-shell --command "cd test && make -B -j4 && ./main"
clang++ -O2 -std=c++14 -c main.cpp
clang++ -O2 -std=c++14 -I../include -c test.cpp
clang++ -O2 -std=c++14 -I../include -c math_expression.cpp
clang++ -o main main.o test.o math_expression.o
===============================================================================
All tests passed (172 assertions in 11 test cases)
```

Nix finds our `default.nix` file and gets everything in order.

Ok, great.
How about running benchmarks?

``` bash
$ nix-shell --command "cd benchmark && make -B -j4 && ./main"
clang++ -O2 -std=c++14 -I../include main.cpp -o main -lbenchmark -lpthread
main.cpp:7:10: fatal error: 'benchmark/benchmark.h' file not found
#include <benchmark/benchmark.h>
         ^~~~~~~~~~~~~~~~~~~~~~~
1 error generated.
make: *** [Makefile:8: main] Error 1
```

Seems like we need to install google benchmark, too.
There is a `gbenchmark` package, but it's again too old.
Nothing we couldn't fix with our own Nix expression, though:

``` { .numberLines }
# file googlebench.nix
{ stdenv, fetchFromGitHub, cmake }:

stdenv.mkDerivation rec {
  name = "googlebench-${version}";
  version = "1.3.0";

  src = fetchFromGitHub {
      owner = "google";
      repo = "benchmark";
      rev = "v${version}";
      sha256 = "1qx2dp7y0haj6wfbbfw8hx8sxb8ww0igdfrmmaaxfl0vhckylrxh";
  };

  nativeBuildInputs = [ cmake ];

  meta = {
    description = "google benchmark";
  };
}
```

Building the benchmark library involves compiling it with `cmake`, as it is more than just headers.
Luckily, the Nix expression language came with its own library installed.
It has handy little helpers like `fetchFromGitHub` that accepts some arguments needed to construct a download link from it and automatically unpack it!

The line `nativeBuildInputs` instructs Nix to install `cmake` for building this package.
Everything else is automatically deduced.
After adding this Nix derivation to our `default.nix` file, it will build google benchmark for us before we can run our own makefile:

``` bash
$ nix-shell --command "cd benchmark && make -B -j4 && ./main"
these derivations will be built:
  /nix/store/vbi7a7kjxz24zmq7lwaa044735hdlmb3-benchmark-v1.3.0-src.drv
  /nix/store/il7biicbp3pa39nl5ffkyi9b1wwkw0b1-googlebench-1.3.0.drv
these paths will be fetched (0.12 MiB download, 0.44 MiB unpacked):
  /nix/store/i1b5rym52fhqkdz2kzaqn1gnk6nhf0b7-unzip-6.0
# ...
clang++ -O2 -std=c++14 -I../include main.cpp -o main -lbenchmark -lpthread
Run on (8 X 2300 MHz CPU s)
2018-02-27 21:50:34
-----------------------------------------------------------------------
Benchmark                                Time           CPU Iterations
-----------------------------------------------------------------------
measure_word_parsing/10                 55 ns         55 ns   12703483
measure_word_parsing/100              1107 ns       1105 ns     654444
measure_word_parsing/1000             6021 ns       6012 ns     125101
measure_word_parsing/10000           47889 ns      47812 ns      13667
measure_word_parsing/100000         481643 ns     480574 ns       1428
measure_word_parsing/1000000       4865444 ns    4854115 ns        130
measure_word_parsing/10000000     54049501 ns   53973846 ns         13
measure_word_parsing_BigO             5.40 N       5.39 N
measure_word_parsing_RMS                 2 %          2 %
measure_vector_filling/10              457 ns        455 ns    1683712
measure_vector_filling/100            2282 ns       2279 ns     305181
# ...
```

Yes, that's some successful benchmark output!
This time it even installed `unzip` in case we don't have it, yet.

However, we do not have to care about anything library-related other than linking.
The Makefile does not reflect any knowledge of Nix or the install location of our dependencies:

``` bash
$ cat benchmark/Makefile
default: main

CXXFLAGS=-O2 -std=c++14

LDFLAGS=-lbenchmark -lpthread

main: main.cpp ../include/parser.hpp ../include/math_expression.hpp
	$(CXX) $(CXXFLAGS) -I../include main.cpp -o main $(LDFLAGS)

clean:
	rm -rf main *.o
```

## Compiling and running tests with different compilers

So... when pulling in compilers and libraries is so simple with Nix - how about checking if our library compiles with all compilers and versions of those?

We need to add a little modification to the `default.nix` file in order to *parametrize* it:

``` { .numberLines }
# file default.nix
{
    pkgs   ? import <nixpkgs> {},
    stdenv ? pkgs.stdenv
}:
rec {
  myProject = stdenv.mkDerivation {
    name = "attoparsecpp";
    version = "dev-0.1";
    buildInputs = with pkgs; [
      (callPackage ./catch.nix { })
      (callPackage ./googlebench.nix { stdenv = stdenv; })
    ];
  };
}
```

We applied the following changes:

- line 4: We added `stdenv` as a named parameter of this Nix derivation. `pkgs.stdenv` is its default value.
- line 7: Now we use `stdenv.mkDerivation` instead of `pkgs.stdenv.mkDerivation`.
- line 12: If our `stdenv` changes, this change is also forwarded into the `googlebench.nix` derivation. (Which then needs to be built just for this compiler, too)

With this change, we can now build and execute our tests with different compilers just by changing varying `nix-shell` arguments.
Let's try GCC now:

``` bash
$ nix-shell \
>  --command "\$CXX --version && cd test && make -B -j4 && ./main" \
>  --arg stdenv "with (import <nixpkgs> {}); gccStdenv"
these derivations will be built:
  /nix/store/cs2r1wbz8n33fspdlqrcm5pf174qdgcj-googlebench-1.3.0.drv
these paths will be fetched (35.32 MiB download, 145.96 MiB unpacked):
  /nix/store/1krs71lr68pvwjf21fq3f8wbw4c460sh-gcc-6.4.0
  /nix/store/gya4nskw8khp28vy0f8m01lf4z8337cz-stdenv-darwin
  /nix/store/yn7m3qnp0m3kf1acpjyxwqxzf3b40jf8-gcc-wrapper-6.4.0
# ...
g++ (GCC) 6.4.0
Copyright (C) 2017 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

g++ -O2 -std=c++14 -c main.cpp
g++ -O2 -std=c++14 -I../include -c test.cpp
g++ -O2 -std=c++14 -I../include -c math_expression.cpp
g++ -o main main.o test.o math_expression.o
===============================================================================
All tests passed (172 assertions in 11 test cases)
```

The magic `--arg stdenv "with (import <nixpkgs> {}); gccStdenv"` line pushed a GCC build environment into the `stdenv` variable.
The `$CXX --version` command in the `--command` part of the command line shows that it's really GCC 6.4.0 now (instead of clang).

We can do the same with GCC 7:

``` bash
$ nix-shell \
  --command "\$CXX --version && cd test && make -B -j4 && ./main" \
  --arg stdenv "with (import <nixpkgs> {}); overrideCC gccStdenv gcc7"
these derivations will be built:
  /nix/store/860fz8zccpxnia4ahzmxcvygms29nn1y-stdenv-darwin.drv
  /nix/store/lnhid58mlkgcaqq6dg0mnaly7y2p1ap4-googlebench-1.3.0.drv
these paths will be fetched (37.09 MiB download, 154.89 MiB unpacked):
  /nix/store/27mxffxnw9q070wqfzhpn3p32h0kafws-gcc-7.2.0-lib
  /nix/store/nknfwhafb2cwlrrwxh5dcwbdznf1fzq1-gcc-7.2.0
  /nix/store/xxb7a4i2y7mn6y0mkkzgy2cgnd78hahp-gcc-wrapper-7.2.0
# ...
g++ (GCC) 7.2.0
Copyright (C) 2017 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

g++ -O2 -std=c++14 -c main.cpp
g++ -O2 -std=c++14 -I../include -c test.cpp
g++ -O2 -std=c++14 -I../include -c math_expression.cpp
g++ -o main main.o test.o math_expression.o
===============================================================================
All tests passed (172 assertions in 11 test cases)
```

Easy. It downloads *another* GCC and uses that for building.

Using the same strategy, we can also run our benchmarks with all these compilers.
We could even write a Nix derivation that actually does this and generates a nice GNUPlot chart from all benchmark runs.

## Fallout

While playing around, we installed at least 3 different compilers and recompiled the google benchmark library for each of them.
A nice thing about this is that this all needs to be done only once.
The resulting packages can then be used again on the next invocation of a `nix-shell` environment.
Even better: if another project happens to need the same compiler/libraries, then they are in place already!
These things are shared system wide now:

``` bash
$ find /nix/store \( -name "*googlebench*" -or -name "*gcc*" -or -name "*catch*" or -name "*clang*" \) -type d -maxdepth 1
/nix/store/62g4h135grzi5xn5y7hyrxg1r8ac408g-catch-2.1.2
/nix/store/2bz86w853wz8q036armrqzds1wh41l2d-googlebench-1.3.0
/nix/store/294rz6hxllqp5iqag01p2ymv37g25zhz-googlebench-1.3.0
/nix/store/02hca1p50i735iimv28cj9l0lmdzwljn-googlebench-1.3.0
/nix/store/5giskx5cy9q2qhv946svwmqw77vbr2iy-clang-4.0.1
/nix/store/mx8870valpdhywaaq16sdiiajrpyj4q7-clang-wrapper-4.0.1
/nix/store/1krs71lr68pvwjf21fq3f8wbw4c460sh-gcc-6.4.0
/nix/store/1p5bg2c6pd2v1lgnf0823sxcilf73ydi-gcc-6.4.0-lib
/nix/store/yn7m3qnp0m3kf1acpjyxwqxzf3b40jf8-gcc-wrapper-6.4.0
/nix/store/nknfwhafb2cwlrrwxh5dcwbdznf1fzq1-gcc-7.2.0
/nix/store/27mxffxnw9q070wqfzhpn3p32h0kafws-gcc-7.2.0-lib
/nix/store/xxb7a4i2y7mn6y0mkkzgy2cgnd78hahp-gcc-wrapper-7.2.0
```

So we can see that we have one version of clang, two versions of GCC, just one version of catch and three versions of googlebench.
There is of course only one version of catch becasue it is just a header that does not need to be recompiled for different compilers.

But how does Nix know which googlebench installation belongs to which clang/GCC?

The long cryptic prefix of every package folder is the *hash of its build configuration*!
The compiler choice is part of the build configuration, of course.

If another project has dependencies that overlap with ours in the sense that some dependency turns out to have the same configuraiton hash for the same package, then it will be shared.
As soon as the configuration changes a little bit - another package is created.

We can now delete everything with one command:

``` bash
$ nix-collect-garbage -d
removing old generations of profile /nix/var/nix/profiles/per-user/tfc/profile
removing old generations of profile /nix/var/nix/profiles/per-user/tfc/channels
finding garbage collector roots...
# ...
deleting unused links...
note: currently hard linking saves 0.00 MiB
606 store paths deleted, 358.10 MiB freed
```

That's it.
Our system is free of everything what was installed just for this project.

## Purity

By running `nix-shell --pure`, it is possible to *hide* everything which was not explicitly declared to be available:

``` bash
$ nix-shell --pure -p gcc7

[nix-shell:~]$ clang++
bash: clang++: command not found

[nix-shell:~]$ exit

$ nix-shell --pure -p clang

[nix-shell:~]$ g++
bash: g++: command not found
```

Using `--pure`, we can check if our `default.nix` *really* contains the complete list of dependencies.
That feature is something most other dependency management tools don't do for us.

This way it cannot happen that a project builds on one computer, but not on the other, just because someone forgot to install something else that is implicitly needed.

## Summary

Nix just helped us with:

- fetching, compiling, and installing dependencies including compilers and libraries
- easily changing the compiler and version between builds
- managing all those dependencies without interference
- getting rid of it again

Maybe Conan would also have been able to do that (apart from the `--pure` feature).
Nix however does not only work for C/C++ projects:
It can be used for Rust, Haskell, Python, Ruby, etc. etc. - because it is a *universal* dependency manager.

Writing your own Nix derivations is only necessary if custom- or extremely new package versions are needed.
It is also not hard to do.
Existing packages can be rebuilt with different configurations, too.

Being completely amazed, i also installed NixOS on my laptop.
What's great there is that i am now able to configure the whole system with just one `.nix` configuration file.
When that file changes, Nix automatically restarts only the affected services.
If it does not work, then it is possible to roll the system back to a previous configuration. (Remember all the stuff in `/nix/store/...`? It's still there until it's garbage-collected!)
The same system configuration could be used to clone the system elsewhere, etc.

This article is really just scratching the surface of Nix/NixOS's possibilities.


