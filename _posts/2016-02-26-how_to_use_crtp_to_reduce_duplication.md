---
layout: post
title: How to Use the CRTP to Reduce Duplication
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

## Comparison, The Other Way Around

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

At this stage, one maybe realized that `x <= y` is the same as `!(x > y)` (same applies to `<` and `!(>=)`), and there is already some code duplication by providing a special implementation for it...

## The Fat Friend Who Likes Eating

Implementing such a ridiculous amount of operator definitions is tedious and error prone.
(*Every single one* of them needs to be tested to be sure that they are correct)

What if one could just inherit from some kind of *comparison helper* class, in order to additionally define a minimum amount of code, and the helper class would implement all the other bloaty operator lines in terms of this minimum of code?

That is exactly where CRTP comes to the rescue.
CRTP stands for ***C**uriously **R**ecurring **T**emplate **P**attern*.
There are multiple things which can be done with it, and they basically look like the following:

{% highlight c++ %}
template <typename INHERITOR_TYPE>
class bla_base_functionality
{
public:
    void generic_function_bla() { 
        generic_part_a();
        static_cast<INHERITOR_TYPE*>(this)->specialized_bla_part();
        generic_part_b();
    }
}; 

class Foo : public bla_base_functionality<Foo>
{
    // Befriend it, it can call our private implementation
    friend class bla_base_functionality<foo>;

    void specialized_bla_part() {
        // some foo-specific code
    }
};
{% endhighlight %}

This is an example for *static polymorphy*!
Class `Foo` just implements a specific part of some more generic function.
The rest is implemented in class `bla_base_functionality`.
This of course looks over-engineered, unless there are some more classes which derive from it and specialize its behaviour.

This pattern is a little bit strange in the beginning, but as soon as one gets his head around it, it is a very useful tool.

A specialized version of this is the *Barton-Nackman Trick*, and that is what helps out with the comparison operator mess.
The whole lot of operator definitions can be defined *once* in a CRTP base class, and then one can inherit from that in order to just implement the really needed minimum of code:

{% highlight C++ %}
template <typename T>
class comparison_impl
{
    const T& thisT() const { return *static_cast<const T*>(this); }
public:
    // operator== is implemented by T

    template <typename U>
    bool operator!=(const U& o) const { return !(thisT() == o); }

    // operator< is implemented by T

    template <typename U>
    bool operator>=(const U& o) const { return !(thisT() <  o); }

    // operator> is implemented by T

    template <typename U>
    bool operator<=(const U& o) const { return !(thisT() >  o); }
};
{% endhighlight %}

This is a super generic variant using a type `T` for the class which will inherit from this, and another type `U`.
Type `U` could be hardcoded to `T`, but then it would only allow for comparing the class with instances of *same type*.
Instead, it could also be another class-template parameter (`template <typename T, typename U> class comparison_impl {...};`), which would allow to compare with *any* type, but then it would still be a single type to which `T` could be compared.

The current version allows to make `T` comparable with multiple types at the same time:

{% highlight c++ %}
class Foo : public comparison_impl<Foo>
{
    int x;
public:
    // Ctors, Dtors, etc...

    bool operator==(const Foo &o) const { return x == o.x; }
    bool operator==(int        o) const { return x == o; }
};
{% endhighlight %}

`Foo` is now comparable with other `Foo` instances and with integers directly, using the `==` and `!=` operators.
In order to enable this, only the equality operator had to be implemented.
The other one is inherited from class `comparison_impl`.

The other operators are not implemented, but that is fine as long as anything which `comparison_impl` implements in terms of those remains unused.

## Comparison, The Other Way Around, Reloaded

There is again that limitation, that `Foo` must be at the left side of the comparison, and the other type must be at the right side of it.
In order to solve that, there needs to be some more code accompanying the header file which defines `comparison_impl`:

{% highlight c++ %}
template <typename U, typename T>
bool operator==(const U &lhs, const comparison_impl<T> &rhs) 
{
    return static_cast<T&>(rhs) == lhs;
}

template <typename U, typename T>
bool operator!=(const U &lhs, const comparison_impl<T> &rhs) 
{
    return static_cast<T&>(rhs) != lhs;
}

// same for the others...
{% endhighlight %}

It is strange, that these operator signatures match with `comparison_impl<T>` at the right side, but then cast it to T.
Why the hell is *that*?
If that operator would just match with `T` and `U` types as left and right operands, it would match pretty much *everything*, which is bad.
These operators shall only be used on types, which inherit from `comparison_impl`, so this is the right type for the right comparison operand.
Then it is casted to the inheriting type `T`, because that is the one actually implementing the operator.

One could now implement all the operators, and forever just always inherit from `comparison_impl` and save a lot of work and error potential.
But we are not done, yet.

This implementation has a major flaw:
What if we compare an instance `Foo` with another instance `Foo`?
The compiler will see `Foo::operator==(const Foo&)`, and also the freestanding `operator==(const U &lhs, const comparison_impl<T> &rhs)`, and both match.
It will error-out, telling us that these are two *ambiguous* implementations, which is true:

{% highlight shell %}
tfc@graviton comparison_impl $ clang++ -o main main.cpp -std=c++11 && ./main
main.cpp:80:8: error: use of overloaded operator '!=' is ambiguous (with operand types 'Foo' and 'Foo')
    (f != Foo(1));
     ~ ^  ~~~~~~
main.cpp:36:10: note: candidate function [with U = Foo]
    bool operator!=(const U& o) const { return !(thisT() == o); }
         ^
main.cpp:56:6: note: candidate function [with U = Foo, T = Foo]
bool operator!=(const U &lhs, const comparison_impl<T> &rhs)
     ^
{% endhighlight %}

## SFINAE to the Rescue

> If you are not familiar with *SFINAE*, have a look at the article which [describes how SFINAE works]({% post_url 2016-02-19-how_do_sfinae_traits_work %}).

In case class `Foo` already implements the operation, the right freestanding operator shall better not be *visible* for the compiler.
This can be done using *SFINAE* magic, using `enable_if`:

{% highlight c++ %}
template <typename U, typename T>
typename std::enable_if<!std::is_same<U, T>::value, bool>::type
operator==(const U &lhs, const comparison_impl<T> &rhs) 
{
    return static_cast<T&>(rhs) == lhs;
}

template <typename U, typename T>
typename std::enable_if<!std::is_same<U, T>::value, bool>::type
operator!=(const U &lhs, const comparison_impl<T> &rhs)
{
    return !(static_cast<const T&>(rhs) == lhs);
}
{% endhighlight %}

Maybe we just arrived at level "That's *exactly* why i don't get all this template bloat."

What happened, is that the return type `bool` of both functions was substituted by an SFINAE type trait.
`typename std::enable_if<condition, bool>::type` is a template type, which contains a type definition `type` in case `condition` is `true`.
If `condition` is `false`, then this type trait contains nothing, hence the return type of the whole function cannot be deduced.
Following SFINAE principles, the compiler drops this operator implementation from the candidate list in the `false` case, and this is exactly the desired behaviour in the *ambiguous overload* problem.

The condition is "`U` is not the same type as `some T>`", and can be expressed in template type trait language like this: `!std::is_same<U, T>::value`.

## What We Got

`comparison_impl` is now a useful helper, which can be used for any class which represents something which can be compared to itself or to other types.
The only operators which need to be implemented to exhaust the full support of `comparison_impl` are the following:

- `operator==` 
- `operator<`
- `operator>`

These 3 operators need to be implemented once per type, and each of them can be dropped in case it is not used.

Regarding testing: Assuming there is enough confidence in `comparison_impl` to not contain any typos, only these three operators need to be unit tested individually - the other operators which are derived from those, are then automatically also correct.

I put [the compiling example implementation of `comparison_impl` into a GitHub Gist](https://gist.github.com/tfc/d1d576eb75a1526331e9).
