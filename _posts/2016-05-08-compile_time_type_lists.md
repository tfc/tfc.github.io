---
layout: post
title: Type Lists
---

Homogenuous data in purely functional programs is typically managed in *lists*.
Items can be appended or prepended to lists, different lists can be concatenated.
Lists can be filtered, transformed, mapped, reduced, etc.
Having all this nice stuff as a template meta library is quite an enabler for complex compile time meta programs.

Using templated types, it is easily possible to chain types in **two different ways**:

## All Roads Lead to Rome

There are several possibilities to implement lists in template meta language.
Unfortunately, some roads are really slow ones, so i sketch two possibilities and choose one in order to proceed with that.

### Way 1: variadic template type lists

{% highlight c++ %}
template <typename ... Types> struct type_list {};

using my_list = type_list<Type1, Type2, Type3>;
{% endhighlight %}

With relatively simple template code, such lists can be traversed in order to do all kinds of things with them.

Although this kind of list implementation looks more intuitive than the second way, i experienced performance problems using it in more complex examples.
It seems that variadic template type lists are not as nice to handle for the compiler, and lead to **long compilation times**.
It will become clear, why the other way is faster.

### Way 2: Nested template type lists

{% highlight c++ %}
struct null_t {};

template <typename T, typename U>
struct tl
{
    using head = T;
    using tail = U;
};

using my_list = tl<Type1, tl<Type2, tl<Type3, null_t>>>;
{% endhighlight %}

Nested lists work with recursion.
Every element contains its payload type, which is the actual semantic list element, and the rest of the list.
The rest of the list does then again contain an item and the rest of the rest oft the list, or it is a `null_t` item denoting the end of the list.

A look at the `my_list` line which shows how to instantiate a list using this method, quickly uncovers the clumsiness of this approach.
Such lists are hard to read when they grow longer, as there are more angle brackets than anything else.
The clumsiness of creating such type lists can be overcome with nice helpers.

Transforming such lists, however, is much faster, because most of the list can be reused by the compiler.
Appending an item to its front means wrapping it into a new list element tuple:

{% highlight c++ %}
using append_to_front = tl<Foo, my_list>;
{% endhighlight %}

Doing this with variadic template type lists would mean that the compiler has to create a completely new type.
I learned from my experience playing with type lists, that these lists are *the* way to go when manipulating them a lot. 
Variadic template type lists can be used for transforming from user input to work representation and back (This is done once before and after processing in the bulk of the meta program).

Speaking of user input transformations, this is how it can be done:

{% highlight c++ linenos %}
template <typename T, typename ... REST>
struct make { using type = tl<T, typename make<REST...>::type>; };
template <typename T>
struct make<T> { using type = tl<T, null_t>; };

template <typename ... Ts>
using make_t = typename make<Ts...>::type;
{% endhighlight %}

Using `make_t`, lists can now be instantiated like this: `using my_list = make_t<Type1, Type2, Type3>;`

The `make` struct in line 2 just unwraps the variadic type list step by step and transforms it into a nested template type list.
At some point it arrives at the last item, and the compiler will choose the `make` struct from line 4 for the last instantiation, which is where the `null_t` element is inserted to terminate the list.

`make_t` is just a little helper which spares some writing.

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

 - `empty list` and `list terminator item`: Return an empty list, of course.
 - `empty list` and `real item`: Return a single-item list with the new item.
 - `non-empty list` and `list terminator item`: Just return the unchanged list.
 - `non-empty list` and `real item`: This is the only step which is not a trivial one-step thing. This function specialization calls itself:
	- Separate Head and Tail.
	- Compose a new list of `(Head, append(Tail, T))`.
	- This recursion aborts at `append(Empty List, T)`, which is the second bullet in the list.

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
This is actually correct, because we appended an item which is a list, to the list.
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

With not too much code (Although it is actually a lot and ugly code, compared to a lot of languages), it is possible to maintain lists of types.
Lists of types seem completely worthless at first sight, or at least only worth for demonstrating purely functional toy meta programs.

Have a look at a working implementation in my brainfuck template meta program on github: [Link to typelist.hpp](https://github.com/tfc/cpp_template_meta_brainfuck_interpreter/blob/master/typelist.hpp)

In the next article i will show how to put them to use in order to do useful stuff at compile time.
