---
layout: post
title: Type List Performance
---

Soon, after writing my first meta programs with C++ templates, i realized, that certain programming patterns lead to sky rocketing compile times.
I came up with rules of thumb like "*Prefer pattern matching over if_else_t*", and "*Prefer nested type lists over variadic type lists*".
But i did not how much faster which pattern is, i just knew about tendencies.
Finally, i sat down to write some compile time benchmarks, and this blog posts presents the results.


# Creating Lists

## Metashell
![Metashell: Compile time benchmark measuring creation time of integer sequence recursive vs. variadic type lists](/assets/compile_time_type_list_creation_benchmark_metashell.png)

## Compilers
![GCC/Clang: Compile time benchmark measuring creation time of integer sequence recursive vs. variadic type lists](/assets/compile_time_type_list_creation_benchmark_compilers.png)

# Filtering Lists

{% highlight c++ %}
template <typename List>
struct odds
{
    static constexpr const int  val    {head_t<List>::value};
    static constexpr const bool is_odd {(val % 2) != 0};
    using next = typename odds<tail_t<List>>::type;
    using type = if_else_t<is_odd, prepend_t<next, head_t<List>>, next >;
};

template <>
struct odds<rec_tl::null_t>
{
    using type = rec_tl::null_t;
};

template <>
struct odds<var_tl::tl<>>
{
    using type = var_tl::tl<>;
};

template <typename List>
using odds_t = typename odds<List>::type;
{% endhighlight %}

{% highlight c++ %}
{% endhighlight %}
{% highlight c++ %}
{% endhighlight %}
{% highlight c++ %}
{% endhighlight %}
{% highlight c++ %}
{% endhighlight %}
{% highlight c++ %}
{% endhighlight %}

![bla](/assets/compile_time_type_list_filter_benchmark.png)
![bla](/assets/compile_time_type_list_filter_benchmark_recursive_only.png)
