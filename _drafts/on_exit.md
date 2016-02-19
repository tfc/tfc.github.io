---
layout: post
title: ON_EXIT - Combining Automatic Destruction and Lambdas
---

{% highlight c++ %}
template <class F>
class OnExit
{
    F f;

public:
    template <typename F_>
    OnExit(F_ &&f_) : f(std::forward<F_>(f_)) {}

    ~OnExit() { f(); }
};

struct OnExitHelper
{
    template <class F>
    OnExit<F> operator+(F &&f) const {return {std::forward<F>(f)}; }
};

#define COMBINE1(x, y) x##y
#define COMBINE(x, y) COMBINE1(x, y)
#define ON_EXIT const auto COMBINE(onexit, __LINE__) = OnExitHelper() + [&]()
{% endhighlight %}
