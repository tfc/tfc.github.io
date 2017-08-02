---
layout: post
title: Useful type traits with if_compiles semantics
---

SFINAE type traits are very mighty, because they can check a lot of properties of types in a non-intrusive way.
Unfortunately, they are extremely bloaty to implement.
The single interesting expression within an SFINAE type trait is surrounded by lots of boiler plate code, which is ugly to read and repetitive.
This article shows a nice one-liner approach to define new SFINAE type traits.

<!--more-->

> If you are not familiar with *SFINAE*, have a look at the article which [describes how SFINAE works](/2016/02/19/how_do_sfinae_traits_work).

## Encapsulating the Boiler Plate into a Macro

I learned about this useful little trick, when i attended [CPPCON](http://cppcon.org) in 2015.
Fedor Pikus gave an extremely interesting talk about template meta programming ([The recorded talk is on Youtube](https://youtu.be/CZi6QqZSbFg)). 
The presented macro was part of his talk.

When using SFINAE the same way as presented and explained in the blog post which explains SFINAE, the type trait will pretty much look the same all the time.
The only details which differ are of course the type traits *name*, and the *expression* which does the actual magic.

The following macro does construct a type trait from two parameters:
The later type name of the constructed type trait, and the expression which it shall check for compilability.

``` cpp
#define DEFINE_IF_COMPILES(NAME, EXPR) \
    template <typename U1> \
    struct NAME \
    { \
        template <typename U> static U& makeU(); \
        using yes_t = char; \
        using no_t  = char[2]; \
        \
        template <typename T1> \
        static yes_t& f1(T1 &x1, char (*a)[sizeof( EXPR )] = nullptr); \
        template <typename T1> \
        static no_t&  f1(...); \
        \
        static constexpr const bool value { \
            sizeof(NAME::f1<U1>(NAME::makeU<U1>())) == sizeof(NAME::yes_t)}; \
    }
```

The macro assumes a specific convention:
When checking an expression for compilability, the expression needs to be written in terms of an instance of the type on which the trait shall work.
This means, when the user writes `my_trait<FooType>::value`, the type trait will apply the expression defined by `EXPR`, on an artificial instance of type `FooType`.
In order to do that, `EXPR` needs access to such an instance, and the convention is, that such an instance is always provided with the name `x1`.

The following example will use the macro to create a type trait which can check if the user provided type is dereferenceable:

``` cpp
DEFINE_IF_COMPILES(is_dereferenceable, *x1);
```

The type trait's name is `is_dereferenceable`, and its expression is `*x1`.
It simply tries to dereference the artificial instance of the template type.

Usage then looks like the following:

``` cpp
static_assert(is_dereferenceable<int                  >::value == false, "");
static_assert(is_dereferenceable<int*                 >::value == true,  "");
static_assert(is_dereferenceable<vector<int>::iterator>::value == true,  "");
```

This is pretty cool and easy to use.
It is not necessary to look for specific members, specialize any template structs/functions, etc., to see if some type is dereferenceable like an array, an iterator, or a smart pointer.

Some more examples, which are hopefully self-explanatory enough:

``` cpp
DEFINE_IF_COMPILES(has_begin_function,             x1.begin());
DEFINE_IF_COMPILES(supports_addition_with_ints,    x1 + 123);
DEFINE_IF_COMPILES(supports_addition_with_strings, x1 + "abc");
DEFINE_IF_COMPILES(is_serializable,                x1.serialize());
```

It is possible to complicate this further by providing a macro which enables for expressions like `two_type_trait<T, U>::value`, which provides instances `x1` and `x2` (Example: `supports_addition<T, U>::value`, which tries to add: `x1 + x2`).
The macro is easily extensible to support that.

