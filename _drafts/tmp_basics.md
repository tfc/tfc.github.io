---
layout: post
title: Template Meta Programming Basics
---

## Getting Values Out of Types

{% highlight c++ %}
template <int n>
struct int_type
{
    static constexpr int value {n};
};
{% endhighlight %}

## Function Calling

{% highlight c++ %}
using function_result = typename function<parameter_type>::type;
{% endhighlight %}

{% highlight c++ %}
template <typename T>
struct to_pointer
{
    using type = T*;
};

using int_pointer = typename to_pointer<int>::type; // int *
{% endhighlight %}

## Function Call Using-Clause Helpers

{% highlight c++ %}
template <typename param>
using function_t = typename function<param>::type;
{% endhighlight %}

## Pattern Matching

{% highlight c++ %}
template <int n>
is_ten
{
    static constexpr bool value {false};
};

template <>
is_ten<10>
{
    static constexpr bool value {true};
};

static constexpr bool result {is_ten<12>::value}; // false
{% endhighlight %}

## Variadic Type List Unrolling



## If-Else Branches

{% highlight c++ %}
template <bool condition, typename true_t, typename false_t>
if_else 
{
    using type = false_t; 
};

template <typename true_t, typename false_t>
if_else<true, true_t, false_t>
{
    using type = true_t;
};

template <bool condition, typename true_t, typename false_t>
using if_else_t = typename if_else<condition, true_t, false_t>::type;

struct even_t;
struct odd_t;

using result = if_else<5 % 2 == 0, even_t, odd_t>;
{% endhighlight %}

TODO: Advise to use pattern matching if possible for performance reasons
