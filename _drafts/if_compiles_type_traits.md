---
layout: post
title: Useful type traits with if_compiles semantics
---

SFINAE type traits are very mighty, because they can check a lot of properties of types in a non-intrusive way.
Unfortunately, they are extremely clumsy to implement.
The single interesting expression within an SFINAE type trait is surrounded by lots of boiler plate code, which is ugly to read and repetitive.
This article shows a nice one-liner way to define new SFINAE type traits.

> If you are not familiar with *SFINAE*, have a look at [this blog post]({% post_url 2016-02-19-how_do_sfinae_traits_work %}).

{% highlight c++ %}
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

DEFINE_IF_COMPILES(is_dereferenceable, *x1);

static_assert(is_dereferenceable<int*                 >::value == true,  "foo");
static_assert(is_dereferenceable<int                  >::value == false, "bar");
static_assert(is_dereferenceable<vector<int>::iterator>::value == true,  "foo");
{% endhighlight %}
