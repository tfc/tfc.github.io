---
title: "Book Review: A Philosophy of Software Design"
tags: book
---

What does separate the truly great software developers from the average ones?
People have lots of opinions about this, but it's often hard to describe what
makes the code of a great engineer so good - and what part of it novice
programmers should really try to learn from.
John Ousterhout's book [A philosophy of Software Design](https://amzn.to/3B8ufgM)
aims to answer this question and actually introduces some extraordinarily
appropriate vocabulary for **your** next discussion about software quality.

<!--more-->


<div class="book-cover">
  ![Book Cover of "A philosophy of Software Design"](/images/books/a-philosophy-of-software-design.png)
</div>

## The Book

The book is originally from 2018 and its second edition has been released in 2021.
It has ~180 pages, so it is a very quick read.

John Ousterhout is a computer science professor for computer who has worked on
all kinds of software related topics, but also spent some time teaching how
to *design* software in general - or more precisely, looking at the design
itself of software as the underlying challenge.

The preface of the book begins with an observation, that is frustratingly true

> People have been writing programs for electronic computers for more than 80
> years, but there has been surprisingly little conversation about how to design
> those programs or what good programs should look like.

Even many very experiences programmers *just code* with the target to make *it
work*.

In his university lectures, as he also describes in this book, he lets his
students exercise the design of different kinds of software solutions for small
systems.
While doing that, he tried to find ways to explain the pitfalls that novice
programmers fall into, and what exactly experienced programmers do differently
so that the software they create not only works, but stays maintainable.

The experiences and insights he describes, were not new to me.
Most of the time I thought "Yeah I know this situation, and it's also clear to
me how to do it differently - but the problem is always *explaining* it to
programmers who don't think this way (yet)!"
But for all the principles and strategies that experienced developers follow
with their gut-feel that they developed over time, John found awesome vocabulary
and ways to explain them to programmers who don't know them yet.

## Content and Structure

I experienced the book like a journey over 2 main topics, which shall get their
own subsection each.
As the book is already relatively short and every programmer should read it
anyway, I won't go much into detail and instead just state the most important
points and principles.

### Symptoms and Causes of Complexity, Abstraction, Modules, and Interfaces

Apart from all the computer languages with their different specialties,
(non-)agile development methodologies, tooling as debuggers, linters, version
control systems, and techniques such as object-oriented/functional programs,
schools, universities and developers' book shelves typically lack material
about how software should generally be *designed*.

The average developer just changes their code until the tooling stops emitting
errors/warnings and the code actually does what it is written for.
In some cases, the rules from *clean code* literature are over-applied,
resulting in short but entangled code.
While doing that, the program's complexity increases.
Complexity is like a currency of programming: For more features, you give up
your program's initial simplicity.
This typically ends in programs of huge complexity that cannot be maintained
easily any longer.

Complexity never comes with big leaps but always with a stepwise increase.
The 3 main **symptoms** of complexity are:

Change Amplification

: Seemingly simple changes require modifications in many different places.

Cognitive Load

: The amount of project-knowledge that a developer needs to know in order to
  complete a task.

Unknown Unknowns

: It is not obvious which pieces of code must be modified to complete a task.

The 2 main **causes** of complexity are:

Dependencies

: A dependency exists when a given piece of code cannot be understood and
  modified in isolation. They can't be eliminated, but designed carefully.
  (This is a definition for the discussions in the book.
  Dependencies like installable libraries are not meant in this case)

Obscurity

: Obscurity occures when important information is not obvious.

In order to keep complexity under control (i.e. reach sustainable tradeoffs)
developers need the right mindset.
John distinguishes between two of them:

Tactical Programmers

: The main focus of the tactical programmer is to *get something working*, such
  as new features or bug fixes.

Strategic Programmers

: The strategic programmer does not think of "working code" as their primary
  goal (although accepting that delivered code must always be working).
  Their primary goal is a *great design*.

Most real companies' work culture and deadline pressure facilitates the rise of
tactical programmers (also called *tactical tornados*), which typically write
code with uncontrollable complexity.
Strategical programming requires an **investment mindset** for trading initial
upfront slowdown against long-term improvements.
The fight against continuously increasing complexity are continuous investments.
Discussions between strategic and tactical programmers are often frustrating.

The next topic is the organisation of code into modules (as in classes,
subsystems, or services) that communicate via interfaces.
Modules encapsulate the complexity of systems into domain-specific units.
John coins terms for 2 different kinds of modules:

Deep Modules

: The best modules provide powerful functionality over simple interfaces.
  They provide good abstraction by providing complex functionality but only
  exposing a small fraction of their internal complexity.
  One example are the 5 basic system calls for I/O in UNIX operating systems.

Shallow Modules

: In contrast to deep modules, shallow ones have relatively complex interfaces,
  compared to the functionality they provide.
  Many shallow interfaces do not even provide much keystroke saving when used,
  compared to their reimplementation.

Shallow modules are often a result of *classitis*.
Students at university, or readers of *clean code* lecture are often advised to
break code into small units.
If this advise is followed without much strategy, it often results in shallow
modules which are not much more than leaking abstractions.

Another interesting word that John introduces in this context is *temporal
decomposition*:
Developers often structure code modules according to the order
in which operations occur.
This does often lead to code that shares knowledge, but at different places in
the code, leading to change amplification, higher cognitive load, and unknown
unknowns again.

A good rule of thumb in module design that John comes up with is:

> It is more important for a module to have a simple interface than a simple
> implementation.

If a module ends up being too complex, but its interface is very simple, then
this means that it can easily be substituted by a better one.
Also, changes on such a module do not increase change amplification.

Another great principle is *define errors out of existence*:
John argues that error handling and exceptions make programs much more complex,
and a good way to reduce such complexity is representing data, interfaces, and
semantics in ways that make it impossible to encode erratic cases that need
special handling.

### How to Write Code

The second half is about the act of designing and writing code.
John argues that interfaces and modules should be designed twice:
Implementing a design for the first time often exposes new insights that would
lead to a different design in a second approach.

Working hard on the first design attempt, just to throw it away becasue it was
just a vehicle for learning how to do it right:
This is clearly not the mindset of the average programmer.
At first glance, it also looks like it would waste a lot of time, especially
from the point of view of a tactical programmer.

The next chapters are about comments, naming, modifying existing code,
consistency (of style/documentation/etc. across the project), performance,
and contain a lot of fine-grained advise that should not be unknown to the
working programmer.
Because it can't be summarized by few principles, i do just drop some
interesting highlights:
(These read like rules, and such should never be over-applied in dogmatic
fashion)

- If an interface **comment** describes its implementation, it indicates that
  the interface is shallow.
- If a variable or type **name** is inherently *hard to pick*, it indicates a
  bad abstraction.
- When modifying code:
  - After each change, the system should have the structure that it would have
    if yo had designed it from the start with that change in mind.
  - If you're not making the design better, you are probably making it worse.
- Software should be designed for ease of reading, not ease of writing.
- Test-driven development focuses attention on getting specific features
  working, rather than finding the best design.

John summarizes in his book's conclusion:

> The reward for being a good designer is that you get to spend a larger
> fraction of your time in the design phase, which is fun.
> Poor designers spend most of their time chasing bugs in complicated and
> brittle code.

## Summary

I really enjoyed this book because it gave me effective new vocabulary in the
epic fight against complexity, which is often more social than technical when
arguing with tactical programmers.

Read it, as early as possible, in your developer career.
