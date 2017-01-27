---
layout: post
title: A reinterpret_cast Trap
---

Sometimes, casting is just inevitable.
And then there's even not much science behind it, at least it seems so.
Once some address is provided in a variable of the right size, a typed pointer can be casted out of it, and then the object can be accessed via its members and methods as usual.
In some situations it is really easy to get the casting wrong, leading to interesting bugs.
This article describes an example situation and a proper fix.

Imagine we have a base class `C`, which inherits from `B`, which inherits from `A`.
They all have one `int` member (4 Bytes each):

{% highlight c++ %}
struct A     { int a; };
struct B : A { int b; };
struct C : B { int c; };
{% endhighlight %}

Assuming that we have an instance of class `C` somewhere in memory at address `X`, we know that its member `a` which it inherited from struct `A` lies at exactly the same offset.
Member `b` is located at `X + 4`, and `c` is located at `X + 8`.

If we are just interested in one of those specific members, we could simply calculate the offset, and then `reinterpret_cast`, just like this:

{% highlight c++ %}
// Print c, assuming x is the address of an instance of struct C:
std::cout << *reinterpret_cast<int*>(x + 8) << std::endl; 
{% endhighlight %}

Let's assume we have some code, which *relies* on getting addresses of `struct A` typed addresses in integral form:

{% highlight c++ %}
struct A {
    int a {0xa};
};

struct B : A {
    int b {0xb};
};

// Simple inheritance: A -> B1 -> C
struct C : B {
    int c {0xc};
};

void print_a_from_address(std::uintptr_t addr)
{
    const A *a {reinterpret_cast<const A*>(addr)};
    std::cout << std::hex << a->a << std::endl;
}

int main()
{
    C c;
 
    print_a_from_address(reinterpret_cast<std::uintptr_t>(&c));

    return 0;
}
{% endhighlight %}

That's no good style, but this program works. 
The structures have standard definitions which initialize members `a`, `b`, and `c` to values `0xa`, `0xb`, and `0xc`.

The program will print `a` at run time, which is what we expect.

The inheritance chain wraps every inheriting member's variables past the structure members in memory from which it is inheriting. So the memory layout of `c` looks like:

|Relative offset|Value|Structure Type Origin|
|0x0|0xa|A|
|0x4|0xb|B|
|0x8|0xc|C|

(Every table row represents an integer in memory)

This program stops to work so nicely when changing the inheritance chain a bit:

{% highlight c++ %}
struct A     { int a {0xa}; };
struct B : A { int b {0xb}; };

struct Foo {
    int f {0xf};
};

// Multiple inheritance: (Foo), (A, B) -> C
struct C : Foo, B {
    int c {0xc};
};

void print_a_from_address(std::uintptr_t addr)
{
    const A *a {reinterpret_cast<const A*>(addr)};
    std::cout << std::hex << a->a << std::endl;
}

int main()
{
    C c;
 
    print_a_from_address(reinterpret_cast<std::uintptr_t>(&c));

    return 0;
}
{% endhighlight %}

This program version will print `f`, and not `a`.
This is, because we disturbed the memory layout by letting `C` first inherit from `Foo`, then from `B` (which still inherits from `A`).

|Relative offset|Value|Structure Type Origin|
|0x0|0xf|Foo|
|0x4|0xa|A|
|0x8|0xb|B|
|0xc|0xc|C|

`reinterpret_cast` is just not the right tool for this, if we just assume that inheriting from `A` somehow shall do the magic.
Before showing how to do it right, i first present another failing example:

{% highlight c++ %}
/* Unchanged definition of struct A and B... */

struct C : B {
    int c {0xd};

    virtual void f() {};
};

int main()
{
    C c;
 
    print_a_from_address(reinterpret_cast<std::uintptr_t>(&c));

    return 0;
}
{% endhighlight %}

In this case, the program *might* print `a`, but in many cases it will print *something*.

The only difference is, that we added a virtual function in struct `C`.
This leads to this object containing another *pointer*.
It points to a **vtable**.
(That vtable itself is globally accessible at runtime and contains pointers to all virtual functions which that class contains.
This is roughly how C++ implements polymorphy.)
The vtable pointer can be located *somewhere* in the object.
In the clang and GCC case, it is located at the beginning of the object, where we assumed the `a` member.
And that is why it does not work.

## Casting done right

{% highlight c++ %}
int main()
{
    C1 c1; // normal C B A inheritance
    C2 c2; // Foo C B A inheritance
    C3 c3; // virtual function added in class C

    print_a_from_address(reinterpret_cast<std::uintptr_t>(static_cast<const A*>(&c1)));
    print_a_from_address(reinterpret_cast<std::uintptr_t>(static_cast<const A*>(&c2)));
    print_a_from_address(reinterpret_cast<std::uintptr_t>(static_cast<const A*>(&c3)));
}
{% endhighlight %}

I renamed the 3 variants of struct `C` to `C1`, `C2`, and `C3`.
This program will now correctly print `a` in all these cases.

What is different here (But same in all cases!), is that the address of the objects are first `static_cast`ed to `const A*`, and **then** `reinterpret_cast`ed to `std::uintptr_t`.

`static_cast` applies some magic to the pointer: As it knows from what to what we are casting (from type `C` to `A`), it can *modify* the actual pointer address.
And it must do that, because if we want an `A`-typed pointer from the `C2` object (which first inherits from `Foo`, and then from `B`), then we must add 4 bytes to the address, in order to have an actual `A` pointer. (Because the `A` part lies 4 bytes behind the `Foo` part)

In the `C3` case (which adds a virtual function), the pointer must be fixed in the sense that the `A` part of the object lies behind (or in front of? That is compiler dependend, but `static_cast` will always get it right!) the vtable.
So in this case, clang's `static_cast` will add 8 bytes offset to the pointer, to make it an actual `A` typed pointer. (It's 8 bytes, because a pointer is 8 bytes large on 64bit systems which we assume here)

Another nice feature is, that `static_cast` will refuse to compile, if the object is by no means related to type `A`.
`reinterpret_cast` just ignores this and gives us no safety.

However, it was not possible to completely avoid `reinterpret_cast`, because of the *type erasing* cast from `A*` to `std::uintptr_t`, which `static_cast` would refuse to do. 
Although we could have used a union which overlays an `A` pointer with a `std::uintptr_t`.

## Summary

Only use `reinterpret_cast` when you are *1000000%* sure what type you have in front of you.
And even if you could do the math of pointer offset correction yourself - don't.

When casting, you should always first consider to `static_cast` to the type you need first.
This will *fail* if you got the types wrong - this is useful in situations where you deal with templates or `auto` types)
Do the `reinterpret_cast` only if it is really inevitable, and even then double check its correctness.

`reinterpret_cast`-`static_cast` *chains* will not make your code prettier.
As Stroustrup states in his original C++ books, the C++ style casts are *intentionally ugly*, because they are also potentionally **dangerous**.

*EDIT on 2017-01-27: Changed the type from `uint64_t` to `std::uintptr_t`, as a comment on [reddit.com/r/cpp](https://www.reddit.com/r/cpp/comments/5pju7q/a_reinterpret_cast_trap/) suggested. Thanks for the input!*
