---
title: "Book Review: The Phoenix Project"
tags: book
---

<!-- cSpell:words Behr ITPI Spafford Eliyahu Goldratt Miyagi Kanban Andon -->
<!-- cSpell:words Behr Jidōka Autonomation Kaizen culting rebranding -->
<!-- cSpell:words overcommitted incentivized Beyoncé CISO Pesche -->
<!-- cSpell:words Taiichi Ohno Zuckerberg rebranded -->
<!-- cSpell:ignore -->

[The Phoenix Project](https://amzn.to/3hcHGpf) is a novel that has been declared
a must-read by many IT executives.
It provides smart solutions to the problems that most IT companies struggle with
and is at the same time educating to read.
What principles does it teach, and where does it fall short?

<!--more-->

<div class="book-cover">
  ![Book Cover of "The Phoenix Project"](/images/books/the-phoenix-project.jpg)
</div>

## Book & Authors

[Link to the Amazon Store Page](https://amzn.to/3hcHGpf)

The first edition of this book is from 2013, its second version is from 2014,
and the third version, which is called *the 5th-anniversary edition*, was
released in 2018.
This version of the book is ~350 pages for the main story but contains
additional ~70 pages for an excerpt of
[The DevOps Handbook](https://amzn.to/3iXmzHW).

[Gene Kim](http://www.realgenekim.me/) is a multi-award-winning CTO, researcher,
and author.
His books include [The DevOps Handbook](https://amzn.to/3iXmzHW),
[The Visible Ops Handbook](https://amzn.to/3W5QGf3), and
[Visible Ops Security](https://amzn.to/3uEkxPz).

[Kevin Behr](https://www.linkedin.com/in/kevinbehr/) is the founder of the
[Information Technology Process Institute (ITPI)](https://itpi.org/) and the
general manager and chief science officer of
[Praxis Flow LLC](https://www.praxisflow.com/).
He is also the co-author of [The Visible Ops Handbook](https://amzn.to/3W5QGf3).

[George Spafford](https://www.linkedin.com/in/gspafford/) is a
[research director for Gartner](https://www.gartner.com/analyst/38065).
His publications include articles and books on IT service improvement, as well
as co-authorship of [The Visible Ops Handbook](https://amzn.to/3W5QGf3), and
[Visible Ops Security](https://amzn.to/3uEkxPz).

## Content and Structure

<div class="floating-image-right black-border-image">
  ![Main Protagonist Bill Palmer](/images/books/the-phoenix-project-bill.jpg)
</div>

In this novel, the three gentlemen tell a story about DevOps and organizational
change.
Practically everyone who works in IT will recognize the situations depicted in
the book.
In 1984, [Dr. Eliyahu M. Goldratt](https://en.wikipedia.org/wiki/Eliyahu_M._Goldratt)
published the book [The Goal](https://en.wikipedia.org/wiki/The_Goal_(novel)),
which is a novel about bottlenecks in old-school manufacturing processes.
It seems like the Phoenix Project as a book is strongly inspired by this one:
*The Goal* was about optimizing production plants and *The Phoenix Project* is
about optimizing IT "plants", so to say.

I will introduce only the from my point of view most important three figures
out of twelve from the book:

The story is told from the perspective of the protagonist
[Bill Palmer]{.underline} and begins like this:

> Bill is an IT manager at Parts Unlimited.
> It's Tuesday morning, and on his drive into the office, Bill gets a call from
> the CEO.
> The company's new IT initiative, code named *Phoenix Project* is critical to
> the future of Parts Unlimited, but the project is massively over budget and
> very late.
> The CEO wants Bill to report directly to him and fix the mess in ninety days
> or else Bill's entire department will be outsourced.

<div class="floating-image-right black-border-image">
  ![Board Candidate Erik Reid](/images/books/the-phoenix-project-erik.jpg)
</div>

In the middle of all the turmoil that Bill experiences, he is asked to take time
to meet [Erik Reid]{.underline}, who is also described by other figures in the
book as a mysterious *tech hotshot*.
At first, Erik seems forced upon the protagonist, with no obvious specialty
other than forgetting everyone's names all the time.
Bill does not get why Erik is invited to become a board member.
Their interaction begins with strange homework that Erik gives Bill, like
finding out what "the four types of work" are and calling him afterward.
Erik seemingly knows a lot about optimizing IT organizations,
but he lets Bill find out most of it by himself instead of just explaining it.
This way he initially comes across as some complacent and self-imposed version
of [Mr. Miyagi](https://en.wikipedia.org/wiki/Mr._Miyagi).
Over the rest of the book, he proves to be a helpful genius and a great mentor
to Bill.
With Erik's help, he learns to use his new to get the chaos under control.


[Brent Geller]{.underline} is mentioned in the second chapter when some
huge infrastructure outage occupies a whole department.
Bill describes Brent to the reader:

<div class="floating-image-right black-border-image">
  ![Super 10X Engineer Brent Geller](/images/books/the-phoenix-project-brent.jpg)
</div>

> He's always in the middle of the important projects that IT is working on.
> I've worked with him many times.
> He's definitely a smart guy but can be intimidating because of how much he
> knows. What makes it worse is that he's right most of the time.

Throughout the story, Brent presents himself as the bottleneck of the entire
organization.
Due to his outstanding competence and knowledge of the company's software and
systems, practically nothing gets done without him.
This did not happen intentionally - it just ended up like this.

On the one hand, you want to have employees like Brent, because they are
enormously productive.
On the other hand, you don't want to depend too much on individual employees
like that, because this drives up your
[bus factor](https://en.wikipedia.org/wiki/Bus_factor).
As multiple bosses have direct "access" to Brent, he seems like a shared
resource.
The organizational problem with this is that he is seriously overcommitted
because there is no overarching plan/control of his time availability.
It even gets worse over time as he is pulled into every new emergency that
happens over time, which involuntarily makes him a full-time firefighter.
But he also never says *no*, because he is not the boss and may be too nice a
person.

The problem with Brents in companies has a striking similarity to the *priority
inversion problem* that brought down the
[Mars Pathfinder](https://en.wikipedia.org/wiki/Mars_Pathfinder) project.
Throughout the book's story, *the Brent Problem* is solved by meticulously
controlling Brent's schedule and protecting it and him from unauthorized
external influences.

While Bill and Erik form the team that conveys the book's main principles to
the reader, Brent embodies all the firefighting in IT companies.
Their interplay with all the other characters (which also are very original
and recognizable from what you know from other IT organizations, especially the
CISO John Pesche) is exciting to read, but let's continue with the principles
that the book teaches.

### The Four Types of Work

The *four types of work* that Erik teaches Bill are inspired by Dr. Eliyahu M.
Goldratt's
[Theory of Constraints](https://en.wikipedia.org/wiki/Theory_of_constraints).
This theory's main point is that to increase the throughput of a
system, its constraints (bottlenecks) need to be identified, and then everything
needs to be subordinated to the task of removing them.
All other efforts that don't concentrate on removing actual constraints are
futile.

The book slightly deviates from this school that stems from manufacturing to fit
its learnings into the world of modern IT organizations, which share some but
not all problems, or not the same way, with manufacturing organizations (storage
costs are for example not something that a software organization must optimize
away).
It takes nearly the first half of the book for Bill to identify the four types
of work that Erik asked him for.
The four types as presented in the story are:

Business Projects

: Business initiatives, most of the development work.
  The main reason for companies to even exist.

IT Operations Projects

: IT Operations exist to support the Business.
  They are not an end in itself, but end up being so complex that they make
  practically every big company an IT company compared to how many employees
  are hired to operate IT infrastructure and projects.

The exact amount of business and IT operations projects is often not properly
tracked.

Changes

: *Changing* and updating processes and (infra)structure is another type of work.
  The tasks of maintaining the normal business of some big infrastructure and
  the task of changing something in it are most of the time contradictory
  because it is hard to find ways how to do both at the same time.
  Changes are typically strategic and proactive.

Unplanned Work

: Unplanned work is urgent firefighting that keeps organizations from reaching
  their goals.
  Technical debt is the main driver behind it.
  Unplanned work hinders employees from keeping up with planned work, because of
  the exceptional urgency that it has, e.g. before release deadlines.
  Erik mentions *anti-work* as another synonym.
  Unplanned work is tactical and reactive.

In chapter 19, Eric Reid explains the impact of unplanned work:

> "Unplanned work has another side effect.
> When you spend all your time firefighting, there's little time or energy
> left for planning.
> When all you do is react, there's not enough time to do the hard mental work
> of figuring out whether you can accept new work.
> So, more projects are crammed onto the plate, with fewer cycles available to
> each one, which means more bad multitasking, more escalations from poor code,
> which mean more shortcuts.
> As Bill said, 'around and around we go.' It's the IT capacity death spiral."

This categorization is simple to follow and to adapt your organization to.
If we look at a snapshot of an organization in good times, we would just need
business projects because these earn the money, and the IT projects
enable/support the business.
When everything goes well, no changes are needed because there is no unplanned
work.
But of course, times change, markets change, etc., and after some scaling up and
down structures cease to work correctly which creates unplanned work and the
need for change.

### The Three Ways

The three ways reminded me a lot of the ideals and principles that I learned
earlier from reading the
[Toyota Production System (TPS) Book by Taiichi Ohno](https://amzn.to/3VSudBY).
This is not completely surprising as Toyota developed its ideas of optimized
manufacturing after world war 2.
In the 80s, they were so efficient that the world started copying their ideas.
I will add some insights from the TPS to the learnings from the book to
show the overlap and practicality of the ideas.

Erik's adaption of how to adapt the constraint theory on IT in three ways
(/steps) looks like the following:

1.) Flow

: By *flow*, the book means the flow of *value* produced by the software, which
  originates in development and "moves" to operations.
  Customers wish for new features and bug/security fixes all the time.
  Maximizing this flow means increasing the *throughput* and decreasing the
  *wait times* (latencies) for such.
  This flow is increased by making work in progress (WIP) visible and then
  reducing batch sizes and work intervals, and enhancing the quality and defect
  prevention.
  With this global goal in mind, every value-adding stage that passes
  deliverables downstream to the next stage has to perform such optimizations.

At this point, this reads like a description of
[Kanban](https://en.wikipedia.org/wiki/Kanban):
Supervisors write work packages on cards and move them between columns that
indicate that something is planned, work in progress (WIP), or done.
At the same time, the amount of cards in the WIP stage is kept at a minimum.

![A Kanban Board to visualize WIP at a Toyota production plant ([source](https://www.toyota-global.com/company/history_of_toyota/75years/text/entering_the_automotive_business/chapter1/section4/item4.html))](/images/books/the-phoenix-project-kanban-board.jpg)

2.) Feedback

: The second way is all about the *defect prevention* that was mentioned in the
  first way, and the resolving of bottlenecks/constraints.
  The earlier defects are detected, the faster and cheaper they can be fixed.
  (Ever heard of [Shift-Left](https://en.wikipedia.org/wiki/Shift-left_testing)?)
  For this reason, the organization must be built in a way that enables early
  defect detection.
  As soon as a defect is detected, instead of finding the one to blame, the
  organization must concentrate on the opportunity to learn from the defect and
  optimize the flow to prevent it from happening again.

In Toyota production facilities, this is called
[Andon](https://en.wikipedia.org/wiki/Andon_(manufacturing)):
Whenever a defect is found (or an accident happens), workers would pull the
*Andon Cord* which immediately stops the assembly line and signals one of many
numbered light indicators on an *Andon board*.
A supervisor would then rush for assistance to find out how to resolve the
problem and prevent it in the future.
(Which sometimes results in small fixes, sometimes in going up the organization
hierarchy to find more involved solutions)

![An Andon board at a Toyota production plant ([source](https://www.toyota-global.com/company/history_of_toyota/75years/text/entering_the_automotive_business/chapter1/section4/item4.html))](/images/books/the-phoenix-project-andon-board.jpg)

Workers are typically incentivized to keep the throughput of their assembly line
maximized.
At first sight, this incentive contradicts the other incentive to keep the
quality high if this means stopping the assembly line from time to time.
This might be reminiscent of programmers who are encouraged to create as many
"green" (finished) JIRA tickets as possible per sprint in a hurry, which keeps
them from stopping from time to time what these are actually used for and how to
think better in terms of quality increase and defect avoidance.

When automatic production machines/robots are enhanced with automatic quality
checks, this is called
[Jidōka (Autonomation)](https://en.wikipedia.org/wiki/Autonomation).
The equivalent of this in software engineering is unit- and integration tests
that are executed after *every little change*.
These can (but in many companies don't) act as quality gates that need before
some code change is merged into a release-relevant branch.

Creating fast feedback is critical to achieving quality, reliability, and safety
in the technology value stream.
The challenge is to balance the seemingly contradictive mix of incentives:
On the one hand, workers shall work quickly to produce high throughput.
On the other hand, they shall take some time to look out for defects and
interrupt production if they find any.
This combination is achieved by distributing responsibility for quality over
*all* the links in the production chain.

At Google, you can find this principle embodied by
[The Beyoncé Rule](https://www.oreilly.com/library/view/software-engineering-at/9781492082781/ch01.html),
which says *"If you liked it, you should have put a CI test on it"* -
or more formally:

> "If a product experiences outages or other problems as a result of
> infrastructure changes, but the issue wasn’t surfaced by tests in our Continuous
> Integration (CI) system, it is not the fault of the infrastructure change."

The comparison with production facilities lags a little bit because the
factory optimization theory does not directly map to how software engineering
works:
The output of a factory worker is assembled parts, while the output of a
software developer is changed software (which resembles blueprints).

3.) Continual Learning and Experimentation

: The third way is about creating an organization with a culture of continual
  learning and experimentation.
  The book argues that high-performing operations require and actively promote
  learning, with workers performing experiments in their daily work to generate
  new improvements. (Remember the [review of John Ousterhout's book
  "A Philosophy of Software Design"](/2022/12/05/book-review-a-philosophy-of-software-design/)
  that says that code should be designed twice?)
  The third way can only be achieved by companies that create an atmosphere
  in which workers feel safe to experiment, speak up, and suggest changes.

In the Toyota Production System, continuous improvement culture throughout the
whole company from the CEO to the line worker is called
[Kaizen](https://en.wikipedia.org/wiki/Kaizen).
As an electrical engineer, this way of looking at an organization reminded me of
the [Systems Theory](https://en.wikipedia.org/wiki/Systems_theory) lectures at
university and [Cybernetics](https://en.wikipedia.org/wiki/Cybernetics)
literature.

## Interpretation and Opinion

During my career, I felt intrigued by ideas/schools like
[Scrum](https://en.wikipedia.org/wiki/Scrum_(software_development)),
[agile](https://en.wikipedia.org/wiki/Agile_software_development),
[Kanban](https://en.wikipedia.org/wiki/Kanban_(development)),
[Extreme Programming](https://en.wikipedia.org/wiki/Extreme_programming), etc.
because they promise a cure for many problems that IT companies have, but the
real-life adaptions that I have seen in most companies were rather
underwhelming.
It does not seem like you can get a few employees a Scrum certification, use
Kanban boards in JIRA and that's it.
For that reason, I decided to delve deeper into this topic, and find the
original literature behind it, which ultimately led me to read the book about
[The Toyota Production System](https://amzn.to/3BxYPAt).
That was an eye-opening experience because reading the original literature
empowers one to assess the value behind all the structures and processes better
in relation to the big-picture outcome that they shall achieve.
Today I know that most companies simply do it wrong, mostly by
[cargo-culting](https://en.wikipedia.org/wiki/Cargo_cult_programming)
what the latest books say without having understood completely what they are
aiming for.

Much later, I read the Phoenix project and got to know the Theory of Constraints
that it refers to.
Due to this order, I got the impression that the theory of constraints is kind
of a *rebranding* of the learnings from the TPS, as they are so strikingly
similar.

However, no one in IT companies ever reads TPS, but the Phoenix Project has been
a confirmed must-read by many in the IT industry.
Being an impactful book that motivated many professionals to change things for
the better, it proved its value in the book market to me.
Not to forget that it was so much fun to read because it's a novel and not a
boring textbook (which is another reason for its popularity)!
The fact that it is a novel that explains it at a high level also brought many
managers and deciders to read it, and finally adopt the right mindset on how to
tackle IT.

Looking at the **four kinds of work**, I experienced that many employees confuse
*change control* with *unplanned work*.
In the last few years, I have seen Phoenix-Project-educated employees fighting
some *change* work because they were clogged with *unplanned work*, claiming
that the change project is unplanned work.
Many employees would jump on piles of unplanned work without reflecting that
*this* is the thing they need to fight (or believing that it's hopeless to try)
- this is priority inversion at work.
It seems like it is not trivial for many to change perspectives just by reading
a novel.

This confusion was sometimes due to the fact that you can't ask someone to
change something without reducing the burden of meeting deadlines from them at
some other point.
It happens a lot that managers try to keep the machine running and don't dare to
relieve some resources from firefighting to make them available for strategic
change.
But even if they do,
[organization structures often defend against change](https://lsaglobal.com/blog/how-top-leaders-combat-the-7-most-common-reasons-employees-fight-change/).
Just handing out the Phoenix Project to people without further moderation is not
enough, with all the misunderstandings that I have seen.

Looking at the **three ways**, it's clear that the first two are mostly
technical challenges.
Most companies do not keep up well, but fixing that is "just" a technological
challenge that a company can put their smartest employees and best managers on.
It is a matter of priority, resources, and the right technology.
Throw away your waterfall planning and stateful asynchronous testing pipelines.
Replace it with proper processes and synchronous quality barriers.
I am happy to help:
[Let's schedule a meeting and look at it together](https://calendly.com/jacek-galowicz/60-minute-meeting).

The third way seems to be the hardest one because it is not technical but
purely about the social part of organizations:
Organizations consist of humans which sometimes hoard information, withhold it
for political reasons, and/or distort it to look better.
Some feel insecure (Especially among IT jobs, the impostor syndrome seems
widespread) and just try to keep their job.
The majority of employees are not bursting with motivation for performance and
desire for change, but are happy to find a defined list of tasks that they can
complete every week and in return feed their family and pay off their house
mortgage.
Many just want to secure their jobs and income by showing up in the morning,
following all the rules, signing off in the late afternoon, and making sure that
they did not do anything wrong.
There is nothing wrong with such an attitude - but it also does not model the
self-reflective and improvement-hungry worker that the Toyota Production System
and Theory of Constraints are asking for.

On the other side, organizations are often managed by strict processes and
rules, and trying to change them can result in punishment.
In many companies, the best way to make a career is to not do anything wrong.
So in between all the average employees, the ones who stand up for change might
be trimmed down by the org.

Both the TPS and the third way envision an organization that consists of a
majority of self-thinking and motivated workers who like to experiment -
but without experimentation being an explicit task and instead more an implicit
part of every workday.
(This sounds like the
[*strategic programmer* from John Ousterhout's book](/2022/12/05/book-review-a-philosophy-of-software-design))

The majority of humans are not like this.
After looking at our school system, it's not surprising:
People spend ten to twenty years of their early life in school and university
(For me it was 13 years of school, three for the Bachelor's and two for
the Master's degree - close to 20 years!).
At school, you learn that you are successful when you say what the teacher wants
to hear, and your answers must fit in the boxes of the exam paper (or worse, you
must check one of the four options given in a multiple-choice test).
If you had some teachers that were not like this - good for you - but it's not
the experience of the majority.
It does not get much better at university, which is more difficult but success
still equals giving the right answers and results in exam papers.
Trying something new and doing it differently than others did before is not part
of the education system, which teaches conformity above everything else.
(In the next book review, we will see what this has to do with the
[Overfitting Problem](https://en.wikipedia.org/wiki/Overfitting).)
To put it bluntly: Our school systems produce employees who expect their tasks
to be given in tickets that are presented like exam questions and which are not
to be questioned themselves regarding the task, the deliverable, or the method.
This way to look at it is especially interesting when looking at famous
college/university dropouts who were successful because they did *not* walk the
intended paths (Bill Gates, Mark Zuckerberg, Steve Jobs, etc.).

The remaining challenge for IT leaders of organizations is to find out how to
*empower the minority* of employees that show motivation for change,
experimentation and improvement before they are trimmed down by the rest of the
organization, or before they quit to launch their own business.
All the TPS/Theory of Constraints ideas need to be taken on by those.
The organization (and the part of the org which does not care about change or
even fights it) must give them enough room.

## Summary

Although I typically don't read novels, I was not able to put this one down
until I finished it!
The characters and the development around them are very relatable.
It was exciting to see the protagonist go through a lot of trouble and
frustration but then finally pick up on a great success path.
The name *Brent* has become a synonym for human constraints in the company I
worked at in the last few years.

The idea to model a business with the three ways and divide the different
kinds of work into four categories makes sense.
It is just a model, and no model is ever a silver bullet that fits everywhere,
but I found this way to look at the structures and processes of an IT company
very convincing.
The underlying ideas are very old but they are rebranded in a way that helps IT
specialists apply them in their world.
The vocabulary also helps in convincing others.

This book is another must-read, but only for those who haven't read the primary
TPS literature, or for those who simply prefer fun-to-read novels.
