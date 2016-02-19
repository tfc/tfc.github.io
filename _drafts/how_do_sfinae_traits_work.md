---
layout: post
title: How does the typical SFINAE type trait work?
---

bla bla bla.


{% highlight c++ linenos %}
template <typename U1>
struct is_dereferenceable
{
    template <typename U> static U& makeU();

    using yes_t = char;
    using no_t  = char[2];

    template <typename T1>
    static yes_t& f(T1 &x, char (*)[sizeof( *x )] = nullptr);
    template <typename T1>
    static no_t&  f(...);

    static constexpr bool value {sizeof(f<U1>(makeU<U1>())) == sizeof(yes_t)};
};
{% endhighlight %}

{% gist 94722889c003498c2528 %}
