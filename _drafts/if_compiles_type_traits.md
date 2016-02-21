---
layout: post
title: Useful type traits with if_compiles semantics
---

Dies das.

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

static_assert(is_dereferenceable<int*                 >::value == true, "foo");
static_assert(is_dereferenceable<int                  >::value == false, "bar");
static_assert(is_dereferenceable<vector<int>::iterator>::value == true, "foo");
{% endhighlight %}

