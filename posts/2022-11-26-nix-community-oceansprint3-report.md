---
title: NixOS Community Oceansprint late 2022 Report
tags: nix
---

<!-- cSpell:disable -->

This is my trip report from the late 2022 Oceansprint hackathon on Lanzarote.
For more information please also have a look on the website:
[https://oceansprint.org](https://oceansprint.org)

<!--more-->

# Oceansprint

[Oceansprint](https://oceansprint.org) is a regular hackathon event in the
NixOS community (i wrote a bit about the community and event location
[in the last article](/2021/12/12/nix-community-oceansprint-report))
that is planned to happen twice a year.
From 21.11. to 25.11.2022 it happened for the third time.
This time we were roughly ~20 participants.

After i was at the first oceansprint, skipped the second, and participated in
the third one again, i have experienced quite an increment in the overall
event's quality and the group activities.
Big kudos to Neyts Zupan, Domen Kozar and Florian Friesdorf for the great
organization!

![The Oceansprint location](/images/2021-12-oceansprint-location.jpg)

# Socializing

During the hacking sessions over the day, we all typically sat in groups based
on who worked together on something.
At breakfast and lunch there was typically some random regrouping involved,
and over the day there were also many sporadic discussions at the coffee
machine.
This, combined with the fact that 99% of the time everyone was disciplined in
speaking english, it was very nice to catch some interesting insights in
random topics when walking by.

![The catering [Original Tweet](https://twitter.com/nzupan/status/1594653961419644932)](/images/2022-oceansprint3-buffet.jpg)

Events that really lifted the interaction to a more fun level away from just
work-related discussions were the big grill party and the catamaran sailing
event (there was also wind surfing and hiking), as well as the regular
strandings at the cocktail bar "el kiosko".
We even went into the sauna together that Domen has on his balcony.
This way it was possible to get to talk to *everyone* in more detail over the
week without any hassle and simply having a great time.

# Sprint Projects

I will only describe the topics where i either participated or that i followed
more closely out of personal interest.
There were many more projects, and i am pretty sure they are covered by other
blog articles.

## Secure Boot on NixOS

[Julian Stecklina](https://twitter.com/blitzclone) (works at [Cyberus
Technology](https://cyberus-technology.de/)), Niklas Sturm (works at
[Secunet](https://www.secunet.com/)), and
[Raito Bezarius](https://twitter.com/Ra1t0_Bezar1us) worked together to support
Secure Boot on NixOS.
They were very successful this week: We have seen laptops booting with activated
Secureboot and the Gnome Device Security dialogue displaying a green
Secureboot entry:

![Activated Secureboot on NixOS [Original Tweet](https://twitter.com/blitzclone/status/1596108176914493440)](/images/2022-oceansprint3-secureboot.png)

There is already a pull request on github that introduces this work for at least
developer setups.
For secure and easy production use, some work on key management etc. is still
left to be done.
See the code and more details on github:
[github.com/blitz/lanzaboote](https://github.com/blitz/lanzaboote)

Multiple aspects of this make this project remarkable:

- Niklas and Julian did not know Raito before. The collaboration was a
  spontaneous result of talking about their project plans on the first evening.
- On every ocean sprint so far, we sent different Cyberus co-workers, and this
  is the first sprint with Secunet co-workers. So far, every co-worker who
  returned learned about new ways how to use nix and NixOS productively for both
  personal profit and also company goals.
- Both companies Cyberus Technology and Secunet are working with or evaluating
  NixOS internally. Getting Secureboot working in NixOS is an important mile
  stone.
- This is a great example of how the sponsorship money of both companies, which
  initially was a donation to support events of this kind, also turned out to be
  an investment with immediate return.

## Dream2nix enhancements

[Johannes Kirschbauer](https://github.com/hsjobeki) and
[David Hauer](https://github.com/davhau) worked together on improving the
[dream2nix](https://nix-community.github.io/dream2nix/) project.

From my perspective this is another remarkable collaboration between open source
maintainers and companies, as Johannes aims to push nix for frontend/UI projects
at secunet.
The Oceansprint has been the perfect chance to talk to David about how to get
the most value out of this for all parties over a beer in person.

## Noogle

Another thing that Johannes and David came up with, is Noogle:
A search machine for nix and nixpkgs library functions.

![Noogle Alpha [Original Tweet](https://twitter.com/domenkozar/status/1596168388195545088)](/images/2022-oceansprint3-noogle.jpg)

All Haskellers immediately cheered for this as this is like
[hoogle](https://hoogle.haskell.org/), a great tool for finding the right
function in all available packages.

# Sponsors

The sponsors are a very important topic, as such events would not be possible
without them.

![The sponsored Oceansprint Shirt [Original Tweet](https://twitter.com/domenkozar/status/1595004457653309440)](/images/2022-oceansprint3-shirt.jpg)

As one of the founders of Cyberus, i was interested in the company growing
into the Nix(OS) open source community, hence it was natural to become a sponsor
of this event.
In addition to that, i put some effort into convincing secunet to sponsor the
oceansprint, too, as we do work together with this awesome technology and they
are also interested having their colleagues to grow into the community.

After having spoken with the organisers [Neyts](https://twitter.com/nzupan) and
[Domen](https://twitter.com/domenkozar) at the
[NixCon 2022 in Paris](https://2022.nixcon.org/) about the topic of sponsoring,
i learned that they found it easier to motivate small businesses to participate
in sponsoring than the very big ones.

It seems like the pressure to be able to explain the value proposition of a
sponsoring is bigger for large company management.
So far i personally see the following reasons why companies should
sponsor/invest in conferences and hackathons like this:

- Sponsoring is a good way to reserve seats for your employees at such events.
  While attending, they will extend their network and as soon as some open
  source library or tool has a problem that needs to be fixed, discussing how
  to fix it quickly will be just a phone call with the maintainer away.
  I experienced the profit of such short communication channels at work very
  often already.
- The exposure to long-year community members helps a lot understanding the
  used technology better. Especially less experienced colleagues come back with
  a lot of enlightment, which is why we try to send different colleagues every
  time.
- Having your own employees hack together on things with people that are not on
  your payroll is a very efficient way to get work done for all participating
  sides.
- Events like this in the sun with great social activities are a great way to
  support the efforts of your most motivated co-workers. The overall motivation
  at such events is infectious.
- Most big companies use lots and lots of open source technology.
  Often, employees do not get enough time due to project constraints, or are
  legally not allowed to share code back.
  Sponsoring such events is a great way to give back.
