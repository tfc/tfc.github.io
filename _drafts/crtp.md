---
layout: post
title: CRTP
---

Some objects have different interfaces for doing the same thing in a different way.
One could either check if two objects are *equal*, or if both are *not different*.
Or one could ask if some container is *empty*, or if it has *zero size*.
Classes should sometimes provide multiple kinds to express the same thing to let the user decide which way to express something is more readable in a specific context.
But that does not mean, that the class developer has to express everything multiple times.
This article explains how *CRTP* can help out and remove potential duplicate code lines.

## The Example

Let's consider a class `Foo`, which enables its instances to be compared against each other.
`Foo`s can be equal, different, smaller, smaller-equal, larger, larger-equal, etc.

To keep the example very simple, class `Foo` does just contain a trivially comparable integer member.
All function parameters are non-`const` and by value, to not bloat the example code for the eye.

{% highlight c++ %}
class Foo
{
    int x;

public:
    // Constructors, destructors, etc...

    bool operator==(int o) const { return x == o; }
    bool operator!=(int o) const { return x != o; }

    bool operator< (int o) const { return x <  o; }
    bool operator> (int o) const { return x >  o; }

    bool operator<=(int o) const { return x <= o; }
    bool operator>=(int o) const { return x >= o; }

    // More repetitive lines of code
};
{% endhighlight %}

This is not really bad yet.
It is now possible to compare `Foo` instances with integers, which is fine.

But as soon as this code gets used, it becomes apparent, that the `Foo` instance must always be at the left side of the comparison, and the integer must always be at the right side of the comparison.

To fix this, one has to implement more operators:

{% highlight c++ %}
// Just turn around the parameters and use the already existing operators
bool operator==(int x, Foo foo) { return foo == x; }
bool operator!=(int x, Foo foo) { return foo != x; }

bool operator< (int x, Foo foo) { return foo >  x; } // Don't mess up the order!
bool operator> (int x, Foo foo) { return foo <  x; }

bool operator<=(int x, Foo foo) { return foo >= x; }
bool operator>=(int x, Foo foo) { return foo <= x; }
{% endhighlight %}

At this stage, one maybe realized that `x <= y` is the same as `!(x > y)`, and there is some code duplication by providing a special implementation for it...

