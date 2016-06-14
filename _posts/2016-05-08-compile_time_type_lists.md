---
layout: post
title: Type Lists
---

Homogenuous data in purely functional programs is typically managed in *lists*.
Items can be appended or prepended to lists, different lists can be concatenated.
Lists can be filtered, transformed, mapped, reduced, etc.
Having all this nice stuff as a template meta library is quite an enabler for complex compile time meta programs.

There are already very complete meta programming libraries, just like [Boost.Hana](https://github.com/boostorg/hana) for example.
This article aims to explain, how *lists* of some kind of payload can be implemented in C++ template syntax. 
From scratch.

## All Roads Lead to Rome

There are several possibilities to implement lists in template meta language.
Different implemetations usually have different trade-offs, so i sketch two implementation variants and discuss their advantages and disadvantages.

### Way 1: Variadic template type lists

{% highlight c++ %}
template <typename ... Types> struct type_list {};

using my_list = type_list<Type1, Type2, Type3>;
{% endhighlight %}

That's basically it.
Type items are just listed as variadic template parameters.

### Way 2: Nested template type lists

{% highlight c++ %}
struct null_t {};

template <typename T, typename U>
struct tl
{
    using head = T;
    using tail = U;
};

using my_list = tl<Type1, tl<Type2, tl<Type3, null_t> > >;
{% endhighlight %}

Nested lists work with recursion.
Every element is basically a 2-tuple, wich contains the following:

1. `head`: The payload type of this list item
2. `tail`: The next list item, which is...
    - ...another tuple (This is the recursive part!)
    - ...a `null_t` list delimiter, which denotes the end of the list.

A look at the `my_list` line which shows how to instantiate a list using this method, quickly uncovers the clumsiness of this approach.
Such lists are hard to read when they grow longer, as there are more angle brackets than anything else.
The clumsiness of creating such type lists can be overcome with nice helpers.

## Advantages/Disadvantages

### Performance

> This article at first propagated, that **nested** type lists are much faster. Then i did some measurements with metashell, trusting that tool too early, and had the impression that **variadic** type lists are faster. Then i measured again, using real compilers (GCC/Clang), and the impression turned around again. Have a look at the measurements yourself.

The following measurements will show, that **nested template type lists** are compiled **faster** than variadic type lists.

I wrote a small meta program which generates both recursive and variadic type lists.
These type lists just contain integer types sequences.

#### Metashell

Metashell is an interactive meta programming shell, and it uses Clang to evaluate template code.
Using [metashell](http://metashell.org/)'s `evaluate -profile` command, i measured the time to create lists of both variants, and plotted that.
(Actually running `g++` or `clang++` yields different results, but metashell allowed me to measure the actual template instantiation, without measuring the overhead of starting the compiler in the shell etc.)

![Metashell: Compile time benchmark measuring creation time of integer sequence recursive vs. variadic type lists]({{ site.url }}/assets/compile_time_type_list_creation_benchmark_metashell.png)

Both variants seem to be within $$\mathcal{O}(n^2)$$, and variadic type lists prove to be significantly faster in metashell.

#### GCC/Clang

The compile times of real compilers are of course more interesting, when writing some serious meta programming code for productive use.
Interestingly, the numbers here are **completely different** than the numbers from the measurements in metashell.

![GCC/Clang: Compile time benchmark measuring creation time of integer sequence recursive vs. variadic type lists]({{ site.url }}/assets/compile_time_type_list_creation_benchmark_compilers.png)

Again, both variants seem to be within $$\mathcal{O}(n^2)$$.
But this time, nested type lists clearly win the race.

In fact, nested type lists are so much faster in this benchmarks, that it seems that they are **the** list implementation of choice.

The graphs of the nested type list runs in GCC/Clang appear really small and similar in the diagram, and it's hard to compare them from this picture.
I do not provide a diagram only showing these, because the lines are extremely noisy, not significantly different, and therefore the comparison between clang and GCC does not seem to be very meaningful in this case. 

### Readability

Creating a variadic template type list (way 1) is clearly **more intuitive** than the long and clumsy way to set up nested template type lists.
Variadic template type lists came with **C++11**.

Alghough i find writing list manipulating code nicer with the old school nested type lists.
Let me demonstrate that on an example function `prepend_t`, which takes a list, and an item, and prepends that item to the list.

For nested type lists, prepending an item to its front means wrapping it into a new list element tuple:

{% highlight c++ %}
// Prepend an item to a recursive type list
template <typename RecursiveList, typename T>
using prepend_t = tl<T, RecursiveList>;
{% endhighlight %}

For variadic type lists, this means that we need to extract what it contains already with pattern matching, and then create a new list:

{% highlight c++ %}
// Prepend an item to a variadic type list
template <typename VariadicList, typename T>
struct prepend;

template <typename ... ListItems, typename T>
struct prepend<tl<ListItems...>, T>
{
    type = typename prepend<T, ListItems...>::type;
};

template <typename VariadicList, typename T>
using prepend_t = tl<T, VariadicList>;
{% endhighlight %}

Of course, one can implement `prepend_t`, `append_t`, etc. helpers, and be fine without such pattern matching tricks, but this is another indirection which can make template meta programs slow again.
(Although the performance boost of variadic type lists might be good enough to allow for some indirection here and there).

Another thing about nested type lists:
The clumsyness of their creation can be overcome by creating actual variadic type lists first, and then transforming to recursive type lists:

{% highlight c++ linenos %}
template <typename ... Ts> struct make;

// Case: Normal recursion. Consume one type per call.
template <typename T, typename ... REST>
struct make<T, REST...> { 
    using type = tl<T, typename make<REST...>::type>;
};

// Case: Recursion abort, because the list of types ran empty
template <>
struct make<> { using type = null_t; };

template <typename ... Ts>
using make_t = typename make<Ts...>::type;

{% endhighlight %}

Using `make_t`, recursive lists can now be as nicely instantiated like variadic type lists: `using my_recursive_list = make_t<Type1, Type2, Type3>;`

The `make` struct in line 4 just unwraps the variadic type list (way 2) step by step using pattern matching, and transforms it into a nested template type list (way 1).
At some point it arrives at the last item, and the compiler will choose the `make` struct from line 11 for the last instantiation, which is where the `null_t` element is inserted to terminate the list.

In the following sections, we will implement some usual list library functions.
I chose to do that on nested type lists, because the implementation looks more like what one might already be used from other purely functional programming languages.
All of this is also possible with variadic type lists.

## Extracting Head and Tail of Lists

{% highlight c++ linenos %}
template <typename TList>
struct list_content;

template <typename Head, typename Tail>
struct list_content<tl<Head, Tail>> {
    using head = Head;
    using tail = Tail;
};

template <>
struct list_content<null_t> {
    using head = null_t;
    using tail = null_t;
};

template <typename TList>
using head_t = typename list_content<TList>::head;

template <typename TList>
using tail_t = typename list_content<TList>::tail;
{% endhighlight %}

The `list_content` helper struct applies pattern matching to whatever list is provided as a parameter.
It gives access to `head` and `tail` by *lifting* those types out of the list type.
This code looks really similar to purely functional programming, and this *pattern matching* pattern will occur all the time when we go more complex.

Empty lists are defined to have a `null_t` head and tail.

 - **Line 2:** defines the general `list_content` *function* which takes one parameter - a list type.
 - **Line 5:** defines the head/tail return types in case a list is provided as a parameter. Its definition is specialized, which enables to pick out which types the list head contains.
 - **Line 11:** defines what happens if a list's tail or an empty list is provided as parameter. It returns `null_t` in both cases.

In case someone tries to use this function with non-list types, the compiler will error-out, as it cannot find a templated structure definition of `list_content` which would accept such type.

The `head_t` and `tail_t` helpers again spare some typing.
Those `using` helpers will look the same all the time, as they do no real work.

## Appending Items or Lists to a List's Tail

{% highlight c++ %}
// Function declaration: Takes a list, and a type. 
// Using (list, type) notation in following comments
template <typename TList, typename T>
struct append;

// (empty list, null_t item) -> Still an empty list
template <>
struct append<null_t, null_t> { using type = null_t; };

// (empty list, T) -> List which only contains T
// This is usually the recursion abort step when adding an item to a list
template <typename T>
struct append<null_t, T> { using type = tl<T, null_t>; };

// (list, T) -> Recurse until tail of list, and return a version with T at its end
template <typename Head, typename Tail, typename T>
struct append<tl<Head, Tail>, T>
{ using type = tl<Head, typename append<Tail, T>::type>; };

template <typename TList, typename T>
using append_t = typename append<TList, T>::type;
{% endhighlight %}

When appending items to a list, there are 4 cases, which is the cartesian product of `{non-empty list, empty list} x {real item, list terminator item}`:

| List case | item case | implementation strategy |
|:---------:|:---------:|-------------------------|
|`empty list` | `list terminator item` | Return an empty list, of course.|
|`empty list` | `real item` | Return a single-item list with the new item.|
|`non-empty list` | `list terminator item` | Just return the unchanged list.|
|`non-empty list` | `real item` | This is the only step which is not a trivial one-step thing. This function specialization calls itself recursively on the list's tail in order to get at its end and append the payload item there. |

The implementation contains of only 3 function specializations, instead of 4, although we just identified 4 different scenarios.
Because the `(non-empty list, list terminator item)` case is not implemented explicitly, the implementation will actually waste some computing cycles by appending `null_t` to the list.
This can easily be fixed, which is left as an exercise for the reader.

Another specialization of the function can be added in order to support **list concatenation**:

{% highlight c++ %}
// (empty list, non-empty list) -> Return the non-empty list
template <typename Head, typename T>
struct append<null_t, tl<Head, T>> { using type = tl<Head, T>; };
{% endhighlight %}

Even without this specialization, it is possible to append a list to another, but the result would be ill-formed, if the expected result is one concatenated list.
Imagine `l1 = tl<T1, null_t>` and `l2 = tl<T2, null_t>`: Without the new function specialization, appending `l2` to `l1` would result in `tl<T1, tl<tl<T1, null_t>, null_t>>`. 
This is actually correct, because we appended an item which is a list, to the list. (Which means that we just created a multi-dimensional list, or a *tree*)
The new specialization will *flatten* this down, so we get an ordinary one dimensional list as a result.

It has to be noted that this change does not work well any longer, if someone actually *wants* to append lists to lists in order to have *lists of lists*.
A production library would have separate functions for *appending* and *concatenating*.

## I Want to *see* Something. How Do I Print Results?

When playing around with such composed types, it's nice to see if all that actually worked.
To debug a list in different composition steps, it is valuable to print its state.

Printing at compile time can be done by just emitting a compile error.

{% highlight c++ %}
class Type1; // Just some artificial types
class Type2;
class Type3;

using list123 = make_t<Type1, Type2, Type3>;

// This is our little debugging helper. 
// By not defining it, but instantiating it, we provoke a compile error.
template <typename T> class debug_t;

debug_t<list123> d; // Does not compile, but unveils state
{% endhighlight %}

The output looks like this:

{% highlight bash %}
$ g++ main.cpp -std=c++14
main.cpp:65:18: error: aggregate ‘debug_t<tl<Type1, tl<Type2, tl<Type3, null_t> > > > dt’ has incomplete type and cannot be defined
 debug_t<list123> dt;
                  ^
{% endhighlight %}

It is a bit uncomfortable to fiddle it out, but the compiler error message reflects, that the list state is `<tl<Type1, tl<Type2, tl<Type3, null_t> > >`, which is what we expected.

Now we can append things to it...

{% highlight c++ %}
class Type4;

using new_list = append_t<list123, Type4>;

debug_t<new_list> d;
{% endhighlight %}
Output:
{% highlight bash %}
$ g++ main.cpp -std=c++14
main.cpp:68:19: error: aggregate ‘debug_t<tl<Type1, tl<Type2, tl<Type3, tl<Type4, null_t> > > > > dt’ has incomplete type and cannot be defined
 debug_t<new_list> dt;
                   ^
{% endhighlight %}

It is nice to see that `Type4` was correctly appended.
Concatenating a list to another does also work:

{% highlight c++ %}
class Type1;
class Type2;
class Type3;
class Type4;

using list1 = make_t<Type1, Type2>;
using list2 = make_t<Type3, Type4>;

using new_list = append_t<list1, list2>;

debug_t<new_list> d;
{% endhighlight %}
Output:
{% highlight bash %}
$ g++ main.cpp -std=c++14
main.cpp:69:19: error: aggregate ‘debug_t<tl<Type1, tl<Type2, tl<Type3, tl<Type4, null_t> > > > > dt’ has incomplete type and cannot be defined
 debug_t<new_list> dt;
                   ^
{% endhighlight %}

## Outlook

With not too much code (Although it is actually a lot and ugly code, compared to most other programming languages), it is possible to maintain lists of types.

In the next article i show how to put them to use in order to do useful stuff at compile time:
[Link to the article about transformations between user input/output and type lists]({% post_url 2016-05-14-converting_between_c_strings_and_type_lists
%})

One example of code which does heavily use type lists, is my fun [brainfuck interpreter template meta program on github](https://github.com/tfc/cpp_template_meta_brainfuck_interpreter). Link to is its [typelist.hpp list implementation](https://github.com/tfc/cpp_template_meta_brainfuck_interpreter/blob/master/typelist.hpp)
