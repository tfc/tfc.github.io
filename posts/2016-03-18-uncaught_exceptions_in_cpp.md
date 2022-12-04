---
layout: post
title: Uncaught Exceptions in C++
tags: c++
---

What does actually happen, if an exception is thrown somewhere in the middle of a C++ program, but there is no try-catch clause which handles it?
The program gets terminated.
That is fine in general, but what happens to all objects which need to be properly destructed?

<!--more-->

Let's try it out:

``` cpp
#include <iostream>
#include <string>

class Foo
{
    const std::string str;
public:
    Foo(const std::string &str_) : str{str_} {}
    ~Foo() { std::cout << str << " Foo's dtor called.\n"; }
};

Foo gfoo {"global"};
static Foo sgfoo {"static global"};

int main(int argc, char **argv)
{
    Foo lfoo {"local stack"};

    if (argc < 2) {
        throw int(123);
    }

    return 0;
}
```

This program instanciates three `Foo` objects: A global one, a static global one, and a local stack instance.
`Foo`'s destructor just emits a message which tells which one of the three instances was just destructed.

(I wrapped the `throw` clause into a conditional which the compiler cannot optimize away, as it cannot predict with how many parameters the executable will be called.)

In the ideal case, the compiler should emit code which unrolls the stack as soon as the exception is thrown, destructs all objects which are in flight and then terminates the program:

``` bash
$ clangg++ -o main main.cpp -std=c++11 && ./main bla
local stack 1 Foo's dtor called.
static global Foo's dtor called.
global Foo's dtor called.

$ ./main
terminate called after throwing an instance of 'int'
Aborted (core dumped)
```

*Ooops*, unfortunately, this is not the case:
If those `Foo` objects held any unflushed buffers, they'd be gone now!

Wrapping the exception into a `try`-`catch` clause fixes this behaviour.

``` cpp
#include <iostream>
#include <string>

class Foo
{
    const std::string str;
public:
    Foo(const std::string &str_) : str{str_} {}
    ~Foo() { std::cout << str << " Foo's dtor called.\n"; }
};

Foo gfoo {"global"};
static Foo sgfoo {"static global"};

int main()
{
    Foo lfoo {"local stack 1"};
    try {
        Foo lfoo2 {"local stack 2"};
        throw int(123);
    } catch (int) {
        std::cout << "Caught Exception.\n";
    }
    return 0;
}
```

The output looks much better now.
*All* objects are properly destructed:

``` bash
$ clang++ -o main main.cpp -std=c++11 && ./main
local stack 2 Foo's dtor called.
Caught Exception.
local stack 1 Foo's dtor called.
static global Foo's dtor called.
global Foo's dtor called.
```

The C++11 standard says the following in section `15.3.9`:

> If no matching handler is found, the function std::terminate() is called; whether or not the stack is unwound before this call to std::terminate() is implementation-defined (15.5.1).

"Whether or not the stack is unwound" is the crunch point here: It is not unwound in our case.

This becomes especially important In C++14, where it is possible to throw exceptions from within `constexpr` functions.
This can be used as an approach which provides `assert` behaviour at compile time *and* at run time (whereas `static_assert` does not help at run time).
