---
title: NixOS Community Oceansprint 2021 Report
tags: nix
---

This is my trip report from the awesome NixOS community hackathon on Lanzarote.
For more information please also have a look on the website:
[https://oceansprint.org](https://oceansprint.org)

<!--more-->

# The Sprint announcement

[Domen Kožar](https://twitter.com/domenkozar/status/1403409126173126664)
organized a hackathon for the Nix(OS) community on Lanzarote:

![Oceansprint Announcement on Twitter](/images/2021-12-oceansprint-announcement.png)

This was totally amazing news for me and i really wanted to participate
immediately.
I realized that i need to be quick because there were only ~15 slots.
Two days later the next announcement said:

![The Oceansprint was booked out 2 days later](/images/2021-12-oceansprint-full.png)


# The NixOS Community

There is an open source [package manager called (nix)](https://nixos.org)
(which is a ridiculously understated description) and a
[GNU/Linux distrubtion called NixOS](https://nixos.org)
that is based on top of nix.
This is all organized in the
[NixOS github organization](https://github.com/nixos) and mostly revolves around
the git repository [nixpkgs](https://github.com/nixos/nixpkgs) because this is
where most of the value is concentrated because this repository represents the
largest and most current collection of all Linux package distributions out there:

![repology.org graph showing the most vs. the most fresh package collections](/images/2021-12-repology.png)

Apart from that, the repository also contains a lot of NixOS module descriptions
that are used to compose a full NixOS system.

A description of all the value that i pull out of this open source project for
myself and my company is worth multiple blog articles alone, so please refer
to their homepage if you like to read more.

It's an unbelievable project.
If you are interested in contributing to the largest most-current free software
package collection in the world and/or an amazing GNU/Linux distribution on top
of that within a very nice and inclusive community, then this project is
definitely for you.


# Corona

The sprint has been cancelled roughly 2 weeks before its start due to the latest
Corona related warning level increase in Lanzarote/Spain.
Most of the participants travelled to Lanzarote anyway as it was still allowed
to meet in smaller groups.
Luckily, a few days before the sprint the warning level was decreased based on
the latest infection numbers, so we were again able to perform the sprint like
initially planned.

All participants have their vaccination. On monday and thursday everyone tested
themselves under supervision of each other before joining the group.

# Participants of the sprint

The participants who showed up over the week were the following ones:

Real name (nickname), Company

- Amon Stopinšek (`am-on`), Niteo, https://niteo.co
- Andreas Schrägle (`ajs124`), Helsinki Systems, https://helsinki-systems.de/
- Bernardo Meurer Costa (`lovesegfault`), Google
- Dario Bertini (`berdario`), Google
- Domen Kožar (`domenkozar`), Cachix Founder (Sponsor), https://www.cachix.org
- Florian Klink (`flokli`), Freelancer, https://flokli.de
- Jacek Galowicz (`tfc`/`jonge`), Cyberus Technology (Sponsor), https://cyberus-technology.de
- Janne Heß (`dasJ`), Helsinki Systems, https://helsinki-systems.de/
- Jonas Chevalier (`zimbatm`), Numtide Founder (Sponsor), https://numtide.com
- Marijan Petričević (`marijanp`), Freelancer, http://epilentio.hr
- Nejc Zupan (`zupo`), Niteo Founder (Sponsor), https://niteo.co
- Robert Hensing (`roberth`), Hercules Founder (Sponsor), https://hercules-ci.com
- Vo Minh Thu (`noteed`), Hypered CTO (Sponsor), https://hypered.io

# Location

The sprint location was Nejc's Villa at in Costa Teguise on the Spanish island
Lanzarote.

![The Oceansprint location](/images/2021-12-oceansprint-location.jpg)

# Daily Schedule

The official sprint day schedule began at 9:00 and ended at 17:00.
Every day ended with a brief standup meeting where everyone explained what
they achieved/struggled with.

The gold sponsor [Serokell](https://serokell.io/) also gave us a brief overview
of job opportunities in a dedicated talk slot.
The sprint found a good balance between giving the sponsors enough attention and
thankfulness but at the same time not distract any efforts.

# Socializing

Every day we had breakfast and lunch provided in form of a professional buffet.
After every productive day, the whole group went out for dinner, trying out
several local restaurants.
This way we really sticked together the whole week, which facilitated
easy get-to-know and socializing a lot:
The atmosphere was nice and relaxed!

During the work phases inbetween, everyone either worked alone or in teams
depending on their projects. While the great location allowed for sitting
outside around the big table, near the pool, on the balcony or inside the living
room for concentration phases, it was also very easy to sporadically group up
and discuss things. Or to just hang around at the pool and lament together how
hard life in the sun is.

Apart from work and food, Nejc also organized several activities like
swimming/surfing/hiking trips for whoever wanted to participate.
Another group went to surf school together on the weekend.

# Sprint Projects

## nix.dev UX enhancements

Nejc Zupan started to port the tutorials of https://nix.dev from
reStructuredText to Markdown.
The goal of this change is to lower the barrier for external
contributors, as markdown is simpler and better known than reStructuredText.

Another useful effort that he started is to get all code excerpts on the
website automatically tested by the CI. This will avoid frustration for
newcomers who might want to start to use nix for its reproducibility, so they
don't run into unreproducible tutorials.

## nix-casync

Florian Klink implemented [nix-casync](https://github.com/flokli/nix-casync),
a HTTP binary cache using the casync mechanism internally to efficiently store
NAR files in a deduplicated fashion, and provides an outlook on how to use it to
speed up substitution.

Blog article about this: https://flokli.de/posts/2021-12-10-nix-casync-intro/

## NixOS Composability Optimizations

Robert Hensing, Jonas Chevalier, and Vo Minh Thu experimented with and worked on
how to make NixOS systems smaller and more composable.
There are different reasons for this:

- Reduction of the nix expression evaluation time of whole system builds
- Reduction of overall system size
- Composability for better selection of what actually goes into the system,
  which is not only interesting for disk/mem usage reasons but also for reducing
  the trusted computing base
- Another interesting reason is getting towards interpreterless systems, as
  inspired by some company needs that Jacek described from some internal
  projects that use nix and NixOS

There were basically two approaches:

Robert created a
[pull request with a POC](https://github.com/NixOS/nixpkgs/pull/148456) that
shows how to whitelist NixOS modules into a system. This is different from the
usual approach because the NixOS function that evaluates a config imports *all*
the NixOS modules and then lets the user activate/deactivate things at will, but
has a lot of things already activated by default. "Blacklisting" features by
disabling them one by one in order to arrive at a minimal system is very
uncomfortable becasue you end up searching for which nix file enables what.
Some things also cannot be (easily) disabled this way.
Robert's approach is creating a function that does not work with a default
list of imports. He also added unit tests to facilitate regression-free
maintenance and extension of this effort.

Jonas and Thu experimented with [not-os](https://github.com/cleverca22/not-os),
which is a set of custom NixOS modules that remove systemd and create system
initialization scripts from scratch in order to reach a minimal system.
They resulted in an impressive written overview of what would need to be done
to minimize the system further and even reach systems without interpreters.
(Blog article coming on [Jonas's blog](https://zimbatm.com/))

Both approaches seem like they could be combined upstream with some amount of
work.

## MakeBinaryWrapper

Pointed at an existing
[pull request from user `bergkvist`](https://github.com/NixOS/nixpkgs/pull/124556)
by Robert, Jacek Galowicz stopped participating in the discussion about
minimizing NixOS systems and started helping improving and testing an
application wrapper that is called `makeBinaryWrapper`.
There is an existing tool called
[`makeWrapper`](https://nixos.org/manual/nixpkgs/stable/#fun-makeWrapper)
that can substitute any binary or
script by another script that first manipulates the shell environment in
user-specified form and then calls the original app/script, possibly with
prepended command line arguments.
The binary wrapper builds a tiny C program and compiles it instead of composing
a shellscript. This is interesting for the following reasons:

- MacOS's `execv` system call cannot call scripts, so `makeWrapper` does not
  work there (see more detailed description in the PR)
- Binaries can outperform bash
- Interpreterless systems must not have `makeWrapper` wrappers.

The wrapper does generally work but must be extended if it is chosen to
completely get rid of the default wrapper on NixOS systems, because some
derivations stretch the wrapper's capabilities so much that it's hard to model
the same behavior in simple C programs. This can be changed to the better with
follow-up contributions.

## NixOS Integration Test Driver Refactoring

After Jacek's porting of the NixOS integration test driver from Perl to Python
in 2019 after the NixCon in Brno, this driver implementation
[became the standard NixOS integration test driver in Nixos 20.03](https://nixos.org/manual/nixos/stable/release-notes.html#sec-release-20.03),
and the general interest in using and extending the driver for tests in the
community increased.
The driver code itself is growing in ways that should not happen in unmoderated
fashion, and not without giving it a proper architecture.

As a first step, the driver should be split up in individual files for each
of its functionality domains and put in a real Python package, in order to get
more improvements afterward.

Jacek introduced these ideas as a project idea for the sprint and
Marijan Petričević, Amon Stopinšek, and Vo Minh Thu jumped right into doing
this.

The first PR on this has already been merged:
https://github.com/NixOS/nixpkgs/pull/149329

## NixOS Integration Tests on MacOS

Nejc Zupan, Domen Kožar, and Marijan Petričević started working on the NixOS
integration test driver nix expression in order to enable for running the usual
integration tests with virtual networks of NixOS VMs, but on MacOS.

## Nix Community Ownership Bootstrapping

Bernardo Meurer Costa pointed out that the Nix(OS) community is currently
organized in a rather anarchistic fashion. This works very well on one hand
in the sense that many contributors maintain and enhance nixpkgs and NixOS
together and at the same time keep it stable and working.

On the other hand, recent problems with bogging down RFCs and in general bigger
decision processes stalling in endless discussions without any resulting
decision, indicate that the governance has potential to improve.

Bernardo studied different voting algorithms and chose which ones to quickly
employ for having a bootstrap voting process.
The process would start with a list of well-known contributors and the sprint
participants to decide who shall be part of an anytial group of leaders who
then are able to bootstrap general decision structures and processes.
It was a pity that Eelco was not here to share his opinions on this, but he
will also be included from the beginning.

## Cachix Deploy

Domen Kožar worked on and demonstrated the new cachix deploy feature, which can
be explained as "the hail service on steroids".
The cachix website will soon show this new feature.

## nixpkgs Refactorings

I don't have a perfect overview of what was done at the sprint as there were so
many things, but i also remember:

- Janne: Refactor the switch-to-configuration scripts
- Dario: Refactor Linux kernel module builds in nixpkgs
- Andreas: Fix the MariaDB derivation and MySQL tests
- Bernardo: Remove the perl script that merges Linux kernel configs in favor of
  better tooling
- Andreas: Substitute stage1 init scripts by proper systemd handling
