---
layout: post
title: What is a Type Trait?
---

## Short Intro

This article explains, what so called *type traits* in C++ are.
Type traits have been there for quite a long time now. They are a meta programming technique which appears to use types and their sub types like functions at compile time, to control what the compiler actually compiles.

Looking at complex C++ meta programs, which appear seemlessly embedded into normal program code, is confusing at first.
It is like looking at brain fuck code.
That is, because the meta programming syntax is ugly and clumsy.
*Why is it so ugly?*
The answer is simply, that C++ was not designed from the very beginning to contain a meta programming language.
The language evolved, controlled by a consortium which always tried to keep newer language standards backwards compatible to older ones.
One day, people realized, that this growing little template engine is actually *Turing complete*. 
Soon, people started to write really crazy meta programs with it, which were able to elevate implementations of C++ libraries to a level of unprecedented usability, versatility and elegance (from the perspective of a user which has not seen the implementation). 
Data structures and functions can be implemented in a way, where they do magic of all kinds on any user provided type - with no overhead at runtime, because all the magic happens at compile time, resulting in completely fixed and optimized run time code.

However, back to the ugly syntax: one can really get used to it.

## Simplest example

Let's start with a simple example.
We implement a `not` meta programming function, which takes a simple `bool` parameter and returns its negation.

C++ template variables can contain types or values.
For template variables containing values, simple builtin integral types are supported. `bool` is one of them.
So let's write some code which does at compile time what we want to achieve:

{% highlight c++ %}
template <bool X>
struct not
{
    static constexpr bool value {!X};
};
{% endhighlight %}

This class just takes the parameter `X` which is provided using template syntax, and initializes its only member.
This member is `static`, so it can be accessed from the type directly without us having to allocate an instance of it first.
Furthermore, it is `constexpr`, which means that we can assume it is already accessible at compile time.

Actually using it looks like this:

{% highlight c++ %}
static_assert(not<true >::value == false, "");
static_assert(not<false>::value == true,  "");
{% endhighlight %}

We simply feed the structure with a `true`/`false` input value and scope down to its static member, to get at the return value. 
That's it, we just implemented a complicated way to express `bool y = not(x)`.

The cool thing is, that this code will be completely fixed at runtime, so the compiler can reduce it to a constant value which will reside in the binary.
*No* part of this will have to be evaluated at run time.

Of course, since the release of C++11, we also could have written:

{% highlight c++ %}
static constexpr not(bool x) 
{
    return !x;
}
{% endhighlight %}

...and both use this function at compile time and at run time.
This is amazingly useful, but it's not today's topic.

Getting back to clumsy template syntax, we could have implemented it a different way.
Many type traits need to be implemented this other way, because it's not always simple `true`/`false` situations:

{% highlight c++ %}
// (A)
template <bool X>
struct not
{
    static constexpr bool value {false};
};

// (B)
template <>
struct not<false>
{
    static constexpr bool value {true};
};
{% endhighlight %}

So we have two structs now.
Or, to be specific, one general definition `(A)` of `struct not` and a specialized one `(B)`.
The specialized one will be selected by the compiler when the user references this type, if the template parameters match.

Hence, if the user instanciates `not<false>`, the compiler will select `(B)` as the right implementation, because its described specialization is a perfect match.
And that implementation always contains the fixed value `true`.
Any other instantiation (This is easy, because if the input is not `false`, it's `true`, of course) matches the general implementation `(A)`, which always contains the value `false`.

## Next Example: Comparing types

Using that second, clumsiest possible implementation of `not`, we have a technique at hand to do more useful stuff.
We can, for example, ask at compile time if some user provided type which we got from some template parameter, is a specific type.
Maybe we have an if-else construct somewhere, and need this information to decide which branch to take.
This is easily possible:

{% highlight c++ %}
// (A)
template <typename T, typename U>
struct is_same_type
{
    static constexpr bool value {false};
};

// (B)
template <typename T>
struct is_same_type<T, T>
{
    static constexpr bool value {true};
};
{% endhighlight %}

Again, we have a general implementation `(A)`, and a specialized one `(B)`.
Both take two input types, in order to compare them, and they also both have the same static member variable, but they initialize it to different values.
Usage:

{% highlight c++ %}
static_assert(is_same_type<int, char>::value == false, "");
static_assert(is_same_type<int, int >::value == true,  "");
{% endhighlight %}

If both input types are equal, the specialized implementation `(B)` is a perfect match.
`(B)` still uses template type `T`, which is completely unspecified and could be anything, but it constraints its input parameters to be the same, which is exactly what we want to determine.

It is now perfectly fine to write code like:

{% highlight c++ %}
template <typename T>
T myfunc(T x)
{
    if (is_same_type<T, FooType>::value) {
        /* do something which is completely FooType specific */
    } else {
        /* do the general thing */
    }
}
{% endhighlight %}

Of course, this is just an alternative to:

{% highlight c++ %}
template <typename T>
T myfunc(T x)
{ /* do the general thing */ }

template <>
FooType myfunc(FooType x)
{ /* do something which is completely FooType specific */ }
{% endhighlight %}

It depends on the situation, which one is more useful/better to read/whatever.

## Last Example: Determining if `T` is a pointer type

The compiler behaves rather intelligent while trying to match template parameters.
One can constraint the parameter specializations to `const`, append `*` and `[N]` (where `N` is another integral template parameter), etc.

This example determines, if type `T` is a pointer.
This is useful in some situations.

{% highlight c++ %}
template <typename T>
struct is_pointer
{
    static constexpr bool value {false};
};

template <typename T>
struct is_pointer<T*>
{
    static constexpr bool value {true};
};
{% endhighlight %}

{% highlight c++ %}
static_assert(is_pointer<int >::value == false, "");
static_assert(is_pointer<int*>::value == true,  "");
{% endhighlight %}

However, this trait is not useful when asking if T is dereferenceable in general.
Pointers are dereferenceable, but iterators are also dereferenceable.
This trait is not mighty enough to detect that, but more advanced techniques like *SFINAE type traits* can easily do this job.
I will explain those in another article.

