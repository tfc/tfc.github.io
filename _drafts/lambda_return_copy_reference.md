---
layout: post
title: Functions and Lambdas Returning Copies Versus References
---

C++14 came with some help regarding automatic return type deduction.

TODO: Find another example in Scott Meyer's Book.

{% highlight c++ %}
template <typename T> class debug_t;

class }

decltype(auto) f1(const A &a) { return  a ; }
decltype(auto) f2(const A &a) { return (a); }

debug_t<decltype( f1(A{}) )> d;
{% endhighlight %}






