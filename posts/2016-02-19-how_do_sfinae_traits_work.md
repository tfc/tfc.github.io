---
layout: post
title: How Does the Typical SFINAE Type Trait Work?
---

C++ type traits can be implemented using an interesting technique which uses the *SFINAE* principle.
This article explains what SFINAE means, how it works and how it can be used to implement useful type traits.

<!--more-->

> If you are not familiar with *type traits*, have a look at the article which [describes how type traits work](/2016/02/18/what_is_a_type_trait).

## What Does SFINAE Stand for?

*SFINAE* is an abbreviation for ***S**ubstitution **F**ailure **I**s **N**ot **A**n **E**rror*, and describes a principle a C++ compiler adheres to while it substitutes template types by the type which it deduced from the program's context.

``` cpp
// Little type deduction example:
template <typename T> f(T x) { /* do something with x */ }

// ...
int a {123};
f<int>(a); // The user already specified T. No deduction necessary.
f(a);      // Here, the compiler needs to deduce T from the type of "a"
// The next example will be more complex to point out SFINAE mechanics
```

The SFINAE principle works as follows:
If the compiler detects an error while it tries to substitute a type during template type deduction, it will not emit a compilation error. 
Instead, it will stop considering the symbol it is currently looking at as a match, and try the next symbol, which looks like a suitable candidate.
Of course, the compiler will error-out if there are no suitable candidates left.

## Simplest Example

The in my opinion simplest example to demonstrate how this behaviour can be used, is one which i found on [cppreference.com](http://en.cppreference.com/w/cpp/language/sfinae):

``` cpp
template<int I>
void f(char(*)[I % 2 == 0] = nullptr) {
    // this overload is selected when I is even
}
template<int I>
void f(char(*)[I % 2 == 1] = nullptr) {
    // this overload is selected  when I is odd
}
```

Both functions have the same signature, when they are selected: `void f(char (*)[1])` (They take a pointer to a character array of length 1, and return nothing).
Although the signature is not fixed, as it depends on a variable template parameter, no other signatures can be generated from this. 
We will immediately see, why.

The parameter is not meant to be actually provided by the user, which is why it is initialized to `nullptr` in the default case.
This value is completely uninteresting, which is also why the parameter is not even named.

Code which will actually use the function, will look like `f<NUM>();`, where `NUM` is any integer.
When the compiler attempts to deduce which of those two implementations is the right one (They both initially appear as candidates), it will look at the first one, and try to deduce the parameter's type, as it is not specified, yet.
The expression `I % 2 == 0` is depending on the template parameter `I`, and as soon as that is defined by the user, the size of the array can be calculated.

If `NUM` is an even number, this expression will evaluate to `0 == 0`, which evaluates further to `true`.
In context of an array size description, this boolean value is cast to `int`, which evaluates the whole parameter type to `char(*)[1]`.
The function's signature is now completely deduced, the compiler happily chooses it, and generates the code.
No SFINAE magic here, yet.

But what happens, if `NUM` is an uneven number, like for example 3?
In that case, `3 % 2 == 0` evaluates to `1 == 0`, hence to `false`, and after being cast to int, it is `0`.
Arrays with size of `0` are not valid in C++ (There is a GNU C++ extension which allows them), hence the compiler might throw an error now.
But following the SFINAE principle, it will just disregard this function implementation, as it cannot deduce a valid signature for it, and look at the next candidate.
The next candidate's parameter array type size will evaluate to `1`, which is fine, and the compiler will select it.

This is a crazy method to select code paths, as it does that in quite a roundabout way.
And this is still the simplest example.

## The More Complex, But Also More Useful Example

The following type trait is able to tell, if a type `T` is dereferenceable.

Pointers to any type are dereferenceable, iterators are dereferenceable, and types as `std::shared_ptr<T>`, but also `std::optional<T>` are dereferenceable, although they may not have anything else in common.
If the dereferenceability is the only thing some functionality must know about the type in use, this is the right type trait for that job:

``` cpp
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

    static constexpr bool value {
        sizeof(f<U1>(makeU<U1>())) == sizeof(yes_t)};
};
```

Let's have a look at the peripheral details first, which are necessary, but do not contain the interesting mechanism, yet.

The static function `makeU()` is a little helper to create an rvalue reference of type `U`.
This way, a function can be called using `f(makeU<X>())`, which would put an `X` reference into `f`.
At first it appears that just writing `f(X{})` would do the same job, but what if there is no default constructor, or if the default constructor is protected/private?
We will use this helper function only in a context where the compiler needs to deduce all types, but it will not actually be called and executed, hence needs no definition.

The types `yes_t` and `no_t` are created as helper types. 
They are distinguishable from each other using `sizeof`, because `no_t` is twice as large as `yes_t` (indepentent from what size `char` has on the architecture in use).

And now have a look at both implementations of the static function `f`:
The second version is the simpler one - it just takes any kind and number of parameters, and returns `no_t`.
The first version only takes a `T1&` reference as its first parameter, and a strange character array pointer, initialized to `nullptr` as a default value.

If we write `f<FooType>( makeU<FooType>() )`, the first parameter has exactly the type which the first implementation of `f` expects, which makes it look like a valid candidate.
But the type deduction and substitution is not done at this point, yet, because there is still the type of the optional second parameter.
The size of the character array type must still be deduced.
A strange expression defines its size: `sizeof(*x)`. Of course, `x` is the first parameter, and this expression tries to dereference it.
If `x` is of some pointer-, iterator-, or any other dereferenceable type, then the expression `*x` is perfectly valid and evaluates to something `sizeof` can tell the size of.
As soon as that happened, the function signature is complete, and the implementation candidate is chosen by the compiler.
In that case, the return value is `yes_t`.

If the parameter `x` was of some type which is not dereferenceable, like `int` for example, then the compiler will not be able to evaluate the expression inside of `sizeof`, and there will be no array size.
If there is no array size, then it is impossible to deduce the signature of the whole function, which is an error in general.
Since the compiler follows the SFINAE principle, it will waive this candidate and choose the other, which matches any set of parameters.
In this case, the return type is `no_t`.
That is already the whole magic of this complicated trait structure.

The static constexpr member variable `value` lines it all up and provides the actual functionality to the user:
It lets the compiler select one of the two `f` function implementations.
If the template parameter of the structure (`U1`) is dereferenceable, then the first implementation is chosen, which lets the left `sizeof` expression in the initialization of `value` evaluate to `sizeof(yes_t)`.
The comparison will then evaluate to `true`, and then `is_dereferenceable<FooType>::value` tells us that our type `FooType` is dereferenceable.

Usage:

``` cpp
static_assert(is_dereferenceable<int >::value == false, "");
static_assert(is_dereferenceable<int*>::value == true,  "");
```

That was (just as the simpler SFINAE type trait before) an awfully awkward way to answer the fundamential question "Is T dereferenceable?", but it is perfectly simple to use in the end.

Combined with the `enable_if` type trait for example (which i will explain in another blog post), this can be used to show/hide functions for specific types, based on their characteristics.
