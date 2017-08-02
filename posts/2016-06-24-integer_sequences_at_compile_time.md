---
layout: post
title: Generating Integer Sequences at Compile Time
---

In some situations, it can be useful ot generate sequences of numbers at compile time.
This article shows how to generate integer sequences with C++ templates, and gives an example how to use it.

<!--more-->

## Compile Time Integer Sequences

We are going to build integer sequences, which will look like the following:

`sequence<0, 1, 2, 3, 4, 5, 6, 7, 8, 9>`

``` {.cpp .numberLines }
// This is the type which holds sequences
template <int ... Ns> struct sequence {};

// First define the template signature
template <int ... Ns> struct seq_gen;

// Recursion case
template <int I, int ... Ns>
struct seq_gen<I, Ns...>
{
    // Take front most number of sequence,
    // decrement it, and prepend it twice.
    // First I - 1 goes into the counter,
    // Second I - 1 goes into the sequence.
    using type = typename seq_gen<
        I - 1, I - 1, Ns...>::type;
};

// Recursion abort
template <int ... Ns>
struct seq_gen<0, Ns...>
{
    using type = sequence<Ns...>;
};

template <int N>
using sequence_t = typename seq_gen<N>::type;
```

`sequence_t`'s purpose is solely carrying number sequences.
Note that it is an empty class which is actually *defined* (because it has an empty `{}` definition body).
This is important, because in some use cases it is going to be instantiated.

`seq_gen` is used to recursively generate the integer sequence.

`sequence_t` is the `using` clause which represents the interface for the end user. Writing `sequence_t<10>` evaluates to the initial example with the numeric range going from 0 to 9.

## Usage Example: Unpacking Tuples for Function Calls

Imagine a function which takes a specific set of parameters with specific types:

`void f(double, float, int)`

...and an `std::tuple` ([Link to C++ Documentation about the tuple class](http://www.cplusplus.com/reference/tuple/)), which carries exactly the same types:

`std::tuple<double, float, int> tup`.

In order to call `f` with the values in `tup`, one can write the following code:

`f(std::get<0>(tup), std::get<1>(tup), std::get<2>(tup))`

This is not too nice to read, and it is error prone, because it's possible to use wrong indices. 
Such mistakes would even compile, if the type at the wrong index is the same, as the type at the right index.

It would be nicer to have a function wrapper which has semantics like "*Use this function and this tuple. Then automatically take all the tuple values out of the tuple, in order call the function with them.*":

`unpack_and_call(f, tup);`

This is indeed possible since C++11.
Let's have a look how to implement that:

``` {.cpp .numberLines }
#include <iostream>
#include <tuple>

using std::tuple;

static void func(double d, float f, int i)
{
    std::cout << d << ", " 
              << f << ", " 
              << i << std::endl;    
}

// The following code passes all parameters by 
// value, for the sake of simplicity 

template <typename F, typename TUP, 
          int ... INDICES>
static void tuple_call(F f, TUP tup, 
                       sequence<INDICES...>)
{
    f(std::get<INDICES>(tup) ...);   
}

template <typename F, typename ... Ts>
static void tuple_call(F f, tuple<Ts...> tup)
{
    tuple_call_(f, tup, 
                sequence_t<sizeof...(Ts)>{});
}

int main()
{
    func(1.0, 2.0, 3); 

    tuple<double, float, int> tup {1.0, 2.0, 3};
    unpack_and_call(func, tup); // same effect
}
```

`func` is the example function with its own specific signature.
It has no knowledge about tuples at all.
It could even be a legacy C function.

`tuple_call` is the helper function which automatically unwraps all values from a tuple in order to feed them directly into the function `func`.
It works in two steps:

1. Using *pattern matching*, the type list of the tuple is extracted into the template parameter pack `Ts`.
2. Using `sizeof...(tup)`, the number of parameters is determined, and an integer sequence type is created from this.
3. The helper function `tuple_call_` accepts this sequence type as a parameter, which carries a sequence of rising integer values. These are used as indices to the tuple values. Note that the instantiated sequence object is not actually used - it's only its type we are interested in.
4. The most important part comes here: `std::get<INDICES>(tup) ...` applies exactly the per-parameter tuple unpacking we formerly had to do by hand. `Do_something(TMPL PARAM PACK) ...` expresses "*Apply Do_something to each of the items of the parameter pack*". That's the magic.
