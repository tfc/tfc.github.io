---
title: "Mixed C++ Monorepo Project Structure Development and Build Workflow"
tags: c++, nix
---

<!-- cSpell:words Pfeifer monorepo composability buildable ccache -->
<!-- cSpell:ignore iostream cout liba libb libc libd subproject endmacro -->
<!-- cSpell:ignore myapp AARCH vdso libstdc libm aarch SYSV stdenv -->
<!-- cSpell:ignore nixified frontends libgcc -->

Most big C++ projects lack a clear structure:
They consist of multiple modules, but it is not as easy to create individually
buildable, portable, testable, and reusable libraries from them, as it is with
projects written in Rust, Go, Haskell, etc. 
In this article, I propose a C++ project structure using CMake that makes it
easy to have incremental monorepo builds and a nice modular structure at the
same time.

<!--more-->

Let me show you how to structure a concrete example C++ project in a way that
works well for different perspectives while putting no burden on any 
participating party.
First, we have a look at the different perspectives and then how to realize a 
project structure that facilitates them.
In the end, we will build individual modules with nix - it's possible to do it
without nix, but it would also be much more work.

## Goal: Maximum Utility for Everyone

There are different perspectives from which a repository can provide value or
friction.
Most of the time, the people who write the code have their dominating share in
deciding how the structure of a project looks like: Developers.

### Incremental Builds for Developers

No matter what changed where in the monorepo, there should be one command that 
just builds and tests "it all" incrementally.
From this perspective, it seems like the best way is to have one build system 
that sets up dependencies and builds everything in a highly parallelized 
fashion.

### Fast CI/CD Pipelines

<div class="floating-image-right">
  ![](/images/traffic-jam.webp){width=300px}
</div>

What's best for developers performing incremental changes, is not automatically
good for CI/CD:
When changes go into a project by pushing onto a branch and/or opening a merge
request, CI/CD pipelines are triggered.
In monolithic builds, this means that for every changed code line or comment,
the whole repo is rebuilt.
Caching compiler frontends like [`ccache`](https://ccache.dev/) might be of help
in such situations, but caching at this level brings its own pitfalls and is not
applicable in all situations.

Structuring a project towards modularity and providing a way to build modules
individually is a good way to accelerate big pipelines:
Small module-internal changes only trigger the builds of the modules and their
dependents.
In some sense, this way we can facilitate incremental builds on a higher level.

### Modular Architecture 

<div class="floating-image-right">
  ![](/images/modularity-puzzle.gif){width=300px}
</div>

Generally, developers should try to not mix different domains in the same code.
Mixing domains hinders reusability and makes it harder to inspect for 
correctness.
Having code for different domains separated over different modules also 
facilitates testing:
Each module can have its unit test suite.
Often enough, I observed how easy it was to reduce the overall number of test
cases and their complexity by decomposing library code.
The best proof of the independence of a module is building it in isolation
without the surrounding code.

In multiple C++ projects that I have seen, "reusing library code" looked like 
this:

1. A developer would like to reuse an existing library for some new application.
2. The library is part of a big monorepo and is not easy to extract.
   Maybe it could be extracted by duplicating it, but duplication is considered
   bad in all circumstances.
3. Deadlines need to be met, so the compromise is to put the new application 
   into the same monorepo.
4. Over the years, the coupling and amount of specialization of the libraries 
   for the resident applications increases the general complexity.
5. At some point, a developer will repeat step 1. 
   This time, the slope towards the same procedure is even steeper.

Pointing this out in projects often leads to discussions where the problem is
not fully realized by the majority and hence downplayed.
In fact, convincing people of architectural improvements is often hard, because
this is a strategic consideration with long-term impact and not a tactical one.
The [book "A Philosophy of Software Design" by John Ousterhout](https://blog.galowicz.de/2022/12/05/book-review-a-philosophy-of-software-design/) 
provides some very interesting insights on strategic vs. tactical programmers.

A good way to convince colleagues is generating an architecture graph and
showing them that it contains many circular subgraphs.
No one is proud of projects with architectural graphs that look like a dish of
spaghetti.
However, generating architecture graphs is harder, the less modularized the 
project is - it's a catch-22 situation.

## Monolithic Repo == Monolithic Build System?

<div class="floating-image-right">
  ![Monoliths can help humanity but also be dangerous](/images/monolith.webp)
</div>

So we want to achieve that our C++ project structure is good for developers 
*and* pipelines, integrators, (re)users of library code, etc.
How do we get there?
It should be incrementally buildable for developers when they work at it, but
also be modular with all the good things that we mentioned before.

I created a minimal example app that has a somewhat complicated but clean 
dependency structure.
The code is already available on GitHub as a whole:
<https://github.com/tfc/cmake_cpp_example>

Starting the final app produces the following output:

```sh
$ ./app/MyApp
abcd
```

For every letter, it calls one of four library calls:

```cpp
#include <a.hpp>
#include <b.hpp>
#include <d.hpp>

#include <iostream>

int main() {
  std::cout << liba::function_a()
            << libb::function_b()
            << liba::function_c()
            << libd::function_d()
            << '\n';
}
```

<div class="floating-image-right">
  ![The abcd project dependency structure. Dashed arrows are private deps.](https://raw.githubusercontent.com/tfc/cmake_cpp_example/master/deptree.png)
</div>

The little architecture diagram on the right shows that libraries `A` and `B`
are direct dependencies, while `C`'s symbols are private to `A`, but 
re-exported by its header. 
`D` can be transitively reached because it is a public dependency of `A`.

The project structure looks like this, where all libraries and the app are 
located next to each other at the same level of the repository structure:

```sh
.
├── a
│   ├── CMakeLists.txt
│   ├── include
│   │   └── a.hpp
│   └── main.cpp
├── b
│   └── # similar to `a`
├── c
│   └── # similar to `a`
├── d
│   └── # similar to `a`
├── app
│   ├── CMakeLists.txt
│   └── main.cpp
├── CMakeLists.txt
└── README.md
```

Every subproject has its `CMakeLists.txt` that stands for itself as a 
standalone project and does not know the location of the others:
[CMake](https://cmake.org/) allows us to describe libraries in an 
object-oriented way where they get symbol names that can be exported to be 
imported by others.
Let's look at the `CMakeLists.txt` file of library `A`:

```cmake
cmake_minimum_required(VERSION 3.13)

# Note that this is a *standalone project* although it's in a subfolder of a
# monorepo
project(A CXX)

# Other modules can reference me as A::A
add_library(A main.cpp)
add_library(A::A ALIAS A) # this alias is explained later

target_include_directories(
  A PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
           $<INSTALL_INTERFACE:include>)

# We need library C and D. But what we don't need is knowing from where.
find_package(C REQUIRED)
find_package(D REQUIRED)

target_link_libraries(
  A
  PRIVATE C::C
  PUBLIC D::D)
```

With this structure, we have a library object that describes what it needs, but
not where it comes from.
CMake is able to discover dependencies via `pkg-config` or CMake-native files
when they are located in the standard system folders or listed in the 
environment variable [`CMAKE_MODULE_PATH`](https://cmake.org/cmake/help/latest/command/find_package.html).
If we use this mechanism instead of hardcoding paths, we buy ourselves a lot of
freedom.
I only omitted some lines that would be needed for running `make install`, but 
you can look [them up in the GitHub repo](https://github.com/tfc/cmake_cpp_example/blob/master/a/CMakeLists.txt).

All libraries and the app have similar simple `CMakeLists.txt` files which
describe what they need, but not where they come from.
We could now build them one after the other in the right order to get the final
application executable and provide the binaries (App + libraries as shared 
object files, or just the app if it is statically linked) as packages.
This would be more of an end-user scenario.
For other developers, we can also publish them as [Conan](https://conan.io/) 
packages.

The workflow that we want to provide for developers is building everything in
one invocation of `cmake` and `make`:

```sh
$ mkdir build && cd build
$ cmake ..
$ make
```

To enable this with our loosely coupled collection of libraries we can create a 
`CMakeLists.txt` file in the top-level directory of the repository:

```cmake
cmake_minimum_required(VERSION 3.13)

project(abc_example CXX)

# Define which library symbols are local sub-projects
set(as_subproject A B C D)

# Make find_package a dummy function for these sub-projects.
macro(find_package)
  if(NOT "${ARGV0}" IN_LIST as_subproject)
    # This is a forward call to the *original* find_package function
    _find_package(${ARGV})
  endif()
endmacro()

add_subdirectory(a)
add_subdirectory(b)
add_subdirectory(c)
add_subdirectory(d)
add_subdirectory(app)
```

This way, we support the developer's incremental workflow.
But at the same time, developers of other projects can reuse these libraries
without having to touch everything else.
If a library grows bigger and gets reused by multiple projects, it can easily be 
moved to its own repository.

The idea to rewrite CMake's 
[`find_package`](https://cmake.org/cmake/help/latest/command/find_package.html)
function originates from 
[Daniel Pfeifer's talk at C++Now 2017](https://www.youtube.com/watch?v=bsXLMQ6WgIk).
The talk contains much advice on how to use CMake the correct way and is 
generally a must-watch for every C and C++ developer.

The one thing that each library needs to do to prepare for being consumed this 
way, is to provide an alias like this:

```CMake
add_library(A::A ALIAS A)
```

Libraries that are imported using `find_package` get a `MyLib::MyLib` scope, 
but libraries that are imported using `add_subdirectory` don't, so we have to 
add it like this.

## Result

Incremental developer-oriented builds do now work with the typical `cmake` and 
`make` commands.
At the same time, this does not hinder anyone to create Debian/RPM/whatever 
packages for the individual libraries.

In order to show composability and packaging the nix way, I created nix 
derivations for each module, which look quite similar to the respective
`CMakeLists.txt` files but from a higher level:

```nix
# project file: a/default.nix
{ stdenv, cmake, libc, libd }:

stdenv.mkDerivation {
  name = "liba";
  buildInputs = [ libc libd ];
  nativeBuildInputs = [ cmake ];
  src = ./.;
}
```

The nixified library packages depend just on CMake and respectively on each 
other as depicted in the architecture diagram earlier.
An overlay file puts it all together:

```nix
# file: overlay.nix
final: prev: {
  liba = final.callPackage ./a { };
  libb = final.callPackage ./b { };
  libc = final.callPackage ./c { };
  libd = final.callPackage ./d { };
  myapp = final.callPackage ./app { };
}
```

The `callPackage` function fills out all the parameters from the derivations'
parameters, which you see in the first line of the example derivation.
the `liba` derivation finds `libc` and `libd` in the global scope of packages,
because the overlay defines them, too.
This way we can import a version of the nixpkgs package list with the overlay:

```nix
pkgs = import <nixpkgs> { overlays = [ (import ./overlay.nix) ]; }

# we can now access pkgs.myapp, pkgs.liba, etc. ...
```

The [`release.nix` file](https://github.com/tfc/cmake_cpp_example/blob/master/release.nix)
imports a pinned version of nixpkgs and exposes all these build targets.
We can now build them individually:

```sh
$ nix-build release.nix -A liba
$ nix-build release.nix -A libb
$ nix-build release.nix -A libc
$ nix-build release.nix -A libd
$ nix-build release.nix -A myapp
```

...which results in individual packages (of which the libraries could be
consumed by other projects, external to our repo).
Of course, building the `myapp` target attribute transitively builds all the
others that it depends on.

The most interesting thing that we can do at this point might be 
cross-compilation:
I added a few targets to also link the app statically and cross-compile it for 
AARCH64 and Windows, to demonstrate that the build system does not really need
to be prepared for this other than just being as portable as possible (mostly
by not holding CMake wrong):

```sh
# default build
$ ldd $(nix-build release.nix -A myapp)/bin/MyApp
        linux-vdso.so.1 (0x00007fffced69000)
        libstdc++.so.6 => .../libstdc++.so.6 (0x00007f03ea419000)
        libm.so.6      => .../libm.so.6 (0x00007f03ea339000)
        libgcc_s.so.1  => .../libgcc_s.so.1 (0x00007f03ea31f000)
        libc.so.6      => .../libc.so.6 (0x00007f03ea116000)
        .../ld-linux-x86-64.so.2 => .../ld-linux-x86-64.so.2 (0x00007f03ea631000)

# static build
$ ldd $(nix-build release.nix -A myapp-static)/bin/MyApp
        not a dynamic executable

# Aarch64 build
$ file $(nix-build release.nix -A myapp-aarch64)/bin/MyApp
... ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), ⏎
    dynamically linked, interpreter .../ld-linux-aarch64.so.1, ⏎
    for GNU/Linux 3.10.0, not stripped

# Windows build
$ file $(nix-build release.nix -A myapp-win64)/bin/MyApp.exe
... PE32+ executable (console) x86-64 (stripped to external PDB), for MS Windows
```

## Summary

What this project does on a high level is separate dependency management and
build management:
The CMake files resemble pure recipes which describe who depends on what.

Depending on the use case, the consumer decides how it all comes together by
either using the top-level CMake file or the nix dependency management.

Outside users can build the individual modules as packages and install them
in their systems globally, produce Conan packages, add them to docker images, 
or VMs, or consume them via the nix overlay.

If a library grows bigger and gets imported by more outside users, it is much
easier now to move it into its own repository (and maybe open-source it).


