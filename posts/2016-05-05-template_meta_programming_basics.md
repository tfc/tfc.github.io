---
title: Template Metaprogramming Basics
tags: c++, metaprogramming
---

<!-- cSpell:disable -->

C++ template meta programs are at first really hard to read.
This is because the template mechanism accidentally became turing complete, although it was invented to enable for type-agnostic programming of generic algorithms.
However, now the world knows that the C++ template  part of the language *is* turing complete, people started writing full programs in it, and it enhances the power and flexibility of libraries quite a lot.
This article aims to explain some very basic things one needs to know about the C++ template meta programming language, in order to be able to do things with it, or even understand foreign programs.

<!--more-->

## Getting Values Out of Types

C++ TMP programs work on types, not values.
In some cases, it is useful to work with values, and for that, they need to be wrapped into types.
This is very easy for any type which can be used as template parameters, just like integers, characters, etc.:

``` cpp
template <int n>
struct int_type
{
    static constexpr int value {n};
};
```

The `int_type` enables for bijective mappings between `int_type<N>` and integers `N`.
This way integers can be put where only types are accepted, without losing the actual value information, as it is fixed in the type name.

## Function Calling

In C++ TMP, **functions** are implemented by *misusing* structures or classes.
(There is no real difference between classes and structures - it is just convenient that everything in a struct is public by default)

This is done using a typical pattern:

- The function's **parameters** are just template parameters.
- The function's **return value** is an accessible member `using` clause. (In pre-C++11 TMP programs, these are usually `typedef`s)

The typical convention is, that a structure, which represents a TMP function, will provide a member type called `type`, which contains the result of the parameter mapping.

``` cpp
template <typename T>
struct to_pointer
{
    using type = T*;
};

using int_pointer = typename to_pointer<int>::type; // Result: int *
```

This example presents the `to_pointer` *function*, which takes any parameter type `T` and returns `T*`.
In the last line, it is used to transform `int` to an `int *` type.

The function is *applied* by writing `typename function_name<parameter>::type`.
`type` is just the convention that the function return type is provided by a `using` clause with that name, and `typename` is a necessary keyword which makes the compiler select a matching template and look into it.

## Function Call Using-Clause Helpers

Using `typename ...::type` quickly looks clumsy when applying TMP functions in a nested way.
Since C++11, it is possible to wrap that clumsy part of function application into `using` clauses:

``` cpp
template <typename param>
using function_t = typename function<param>::type;
```

The naming typically follows the convention, that if the function name is `foo`, the helper name is `foo_t`.

Example use:

``` cpp
// without using-clause helper
using result = typename function<FooParam>::type;

// with using-clause helper
using result = function_t<FooParam>;
```

## Pattern Matching

*Pattern matching* is a very important principle in purely functional programming, and so it is in C++ TMP programming.

In the following example it is used to provide a completely different implementation for a TMP function which takes integers, in the case the integer is a `10`.
It will return `false` in all cases, but `true` in case the integer is of the value `10`.

``` cpp
template <int n>
struct is_ten {
    static constexpr bool value {false};
};

template <>
struct is_ten<10> {
    static constexpr bool value {true};
};

bool result1 {is_ten<12>::value}; // false
bool result2 {is_ten<10>::value}; // true
```

It would have been possible to have only one implementation of `is_ten` which initializes its `value` field to `n == 10`, which would be a correct implementation, too.
This example uses pattern matching on this *problem* just for the sake of simplicity.

Pattern matching becomes extremely useful when used in more complicated cases, because it can be used to look *into* template types:

``` {.cpp .numberLines }
template <class vector_type>
struct is_pointer_vector {
    static constexpr bool value {false};
};

template <typename T>
struct is_pointer_vector<std::vector<T*>> {
    static constexpr bool value {true};
};

// Vector of plain ints: false
bool result1 {is_pointer_vector<std::vector<int >::value};

// Vector of int pointers: true
bool result2 {is_pointer_vector<std::vector<int*>::value};
```
<br>

- **Line 2** defines the generic matcher, which will always return `false`.
- **Line 7** defines the case which only matches on vectors with pointer payload types. The type being pointed to could be anything, but it has to be a pointer.

Pattern matching is very flexible.
It would have been possible to initialize the `value` field of the generic case depending on type traits accessing member type definitions of vector (Which could for example look like `is_pointer<vector_type::container_type>::value`), but that would not necessarily be more readable.
Often, this would even be slower, as i experienced that the compiler will be a lot quicker matching the right types instead of unrolling nested conditional branches.

## If-Else Branches

``` cpp
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
```

Especially when nesting a lot of `if_else_t` expressions, the code becomes quickly **less readable**.
Pattern matching can help out a lot here, being both easier to read in most cases.
Another noteworthy detail is, that the compiler will be **faster** matching patterns than unfolding a lot of nested `if_else_t`s.
