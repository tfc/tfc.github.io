---
layout: post
title: ON_EXIT - Combining Automatic Destruction and Lambdas
tags: c++
---

When using C-style libraries, dealing with resources which need to be constructed and destructed again, the code doing the construction/allocation and destruction/release often ends up being ugly and repetitive, because one can't easily stick with the *RAII* principle.
Especially when a whole set of resources is allocated, and the case that some allocation inbetween fails, all already allocated resources need to be correctly released again.
When wrapping such code in C++, it is possible to tidy such code paths up by using automatic destructor calls.

<!--more-->

## C-Style Example

The following example shall illustrate the problem:

``` cpp
void f()
{
    int ret;
    ResourceA *a;
    ResourceB *b;
    ResourceC *c;

    ret = acquire_a(&a);
    if (ret != 0) {
        // Nothing to release yet.
        return;
    }

    ret = acquire_b(a, &b);
    if (ret != 0) {
        // Don't forget to release
        release_a(a);
        return;
    }

    ret = acquire_c(&c);
    if (ret != 0) {
        // Don't forget to release here, too.
        // Often, the order is also important.
        release_b(b);
        release_a(a);
        return;
    }

    do_whatever_those_resources_were_acquired_for(c);

    release_c(c);
    release_b(b);
    release_a(a);
}
```

This example looks ugly and repetitive.
The programmer needs to write code manually which behaves correctly in all cases.
Half of the function looks very repetitive, and deals with boring details.
It is even quite error prone, if the programmer forgets one release somewhere, or messes up the correct order.

Another way to do this is using `goto`.
This looks more elegant, but for good reasons, using `goto` is also discouraged in the majority of projects/companies/communities.

``` cpp
void f()
{
    int ret;
    ResourceA *a;
    ResourceB *b;
    ResourceC *c;

    ret = acquire_a(&a);
    if (ret != 0) return;

    ret = acquire_b(a, &b);
    if (ret != 0) goto rel_a;

    ret = acquire_c(&c);
    if (ret != 0) goto rel_b;

    do_whatever_those_resources_were_acquired_for(c);

rel_c:
    release_c(c);
rel_b:
    release_b(b);
rel_a:
    release_a(a);
}
```

There are actually a lot of possible ways to implement, some safer and less error prone than the other.
Have a look at [this blog post, which shows more variants](http://codedgers.com/blog/2009/apr/8/3/).
The point is, that they are all ugly, and C++ provides syntax which can help fix that.

## The Nicely Looking Version

It would be much nicer to express "As soon as a resource is instantiated, it is also initialized.", and "As soon as a resource instance goes out of scope, it is released.", without doing anything else than instantiating it explicit.
This principle is indeed very usual within the C++ community, and it is called **RAII**, as in ***R**esource **A**llocation **I**s **I**nitialization*.

``` cpp
void f()
{
    int ret;
    ResourceA a;
    ResourceB b;
    ResourceC c;

    ret = acquire_a(&a);
    if (ret != 0) return;
    ON_EXIT { release_a(&a); };

    ret = acquire_b(&a, &b);
    if (ret != 0) return;
    ON_EXIT { release_b(&b); };

    ret = acquire_c(&c);
    if (ret != 0) return;
    ON_EXIT { release_c(&c); };

    do_whatever_those_resources_were_acquired_for(c);
}
```

This version does exactly that.
The macro `ON_EXIT` saves some code, and executes it, as soon as the current scope is left by returning from the procedure.
This version does also respect that the resources must be released in the opposite order of their allocation.

> Please note that this is ideally mixed with `shared_ptr`/`unique_ptr` with custom deleters. Please also have a look at this article, which describes [how to use smart pointers with custom delete procedures to automatically manage resources](/2016/02/21/automatic_resource_release_with_sdl).

The implementation is pretty simple:
`ON_EXIT` represents an anonymous class instance which contains a lambda expression, which is provided by the user.
The lambda expression (which contains the resource release code) will be executed by the anonymous object's destructor:

``` cpp
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
```

`OnExit` is the object which will be automatically put on the stack and calls the custom resource releasing lambda, as soon as it is deallocated again.

`OnExitHelper` is just there for syntax sugar:
Without any other macros, it is already possible to write `auto inst = OnExit() + [](){ release_code(); };`.
This already takes away the burden of having to define template types by hand, but it is not pretty, yet.

It is still necessary to express the declaration and initialization of a new variable, *name* it, and then initialize it with an expression which adds the `OnExit` helper with the lambda expression.

A short macro can help doing all that automatically:

``` cpp
#define COMBINE1(x, y) x##y
#define COMBINE(x, y) COMBINE1(x, y)
#define ON_EXIT const auto COMBINE(onexit, __LINE__) = OnExitHelper() + [&]()
```

The strange combination of `COMBINE` preprocessor calls creates a new symbol name which is concatenated from `onexit` and the line number where the macro is used.
This symbol name is then guaranteed to be unique within the function/procedure scope.
The new symbol will then be visible in the binary as `onexit123`, if it was instanciated at line 123 of the source file.

Additionally, the macro reduces the rest of the syntax to the absolute minimum, so the user does not even have to specialize the lambda capture mode etc.

## Conditional Execution

A version of this macro, which only executes in the success/error case, would be extremely useful in many situations.

Imagine the following code:

``` cpp
void move_file(FileHandle source, FileHandle destination)
{
    copy_file(source, destination);
    ON_SUCCESS { delete_file(source); }
    ON_FAILURE { delete_file(destination); }
}
```

... as opposed to:

``` cpp
void move_file(FilePath source, FilePath destination)
{
    try {
        copy_file(source, destination);
    } catch (...) {
        delete_file(destination);
        return;
    }
    delete_file(source);
}
```

The first version is much more elegant, because the code just expresses *what* needs to happen, and not *how* the error handling code shall look like.

I learned about an addition to the C++ standard which enables for such code at [CPPCON](http://cppcon.org) in 2015.
Andrei Alexandrescu presented this extremely useful idea ([This talk is available on Youtube](https://youtu.be/WjTrfoiB0MQ)).
