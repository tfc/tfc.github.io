---
layout: post
title: Wrapping Algorithms into Iterators
---

Sometimes there is the requirement to generate a range of numbers from some algorithm.
Be it a simple range of increasing numbers, or only odd numbers, or only primes, or whatever.
Some calculations can be optimized by *memorizing* some values for the calculation of the next number, just as this applies for **fibonacci numbers**.
This article shows how to wrap such calculations into **iterators** in order to have performant, and nicely encapsulated algorithms.

<!--more-->

# Fibonacci Numbers

The fibonacci number sequence is widely known.
Generating those numbers is often used as a typical example for recursions, but at least in standard imperative programming languages, the iterative version is more performant:

``` cpp
size_t fib(size_t n)
{
    size_t a {0};
    size_t b {1};

    for (size_t i {0}; i < n; ++i) {
        const size_t old_b {b};
        b += a;
        a  = old_b;
    }

    return b;
}
```

This way it is easy to generate any fibonacci number.
But if all fibonacci numbers up to a certain limit need to be generated for some purpose, this implementation is not too handy any longer.
When counting fibonacci number `N`, and then `N+1`, the content of the variables `a` and `b` could be reused, because the next fibonacci number is just the sum of the last two fibonacci numbers.

In this sense, it would be useful to have a class, which manages some *fibonacci state* in order to be able to quickly calculate just the next number.

A lot of people would just implement a class `fibonacci_number` which has some `next()` method and a `current()` method and use that.
This is fine, but i propose to go a step further by realizing that this is how ***iterators*** work.
By implementing this functionality in terms of iterators, it can be used in combination with the STL, boosting up the code readability.

# Iterators

What do we need in order to implement the simplest possible iterator?

Let us have a look at what the C++ compiler asks for if we want to iterate over a container class:

``` cpp
for (const auto &item : vector) {
    /* loop body */
}
```

This kind of loop declaration exists since C++11.
The compiler will expand this to the following equivalent code:

``` cpp
{
    auto it  (std::begin(vector));
    auto end (std::end(vector));

    for (; it != end; ++it) {
        const auto &item (*it);
        /* loop body */
    }
}
```

Looking at the expanded loop, it is pretty obvious what needs to be implemented.
First, we need to distinguish between two kinds of objects: `vector` is the **iterable range**, and `it` is the **iterator**.

The **iterable range** needs to implement a `begin()` and an `end()` function.
These functions return iterator objects.

> Note that this code sample does not call `vector.begin()` and `vector.end()`, but `std::begin(vector)` and `std::end(vector)`.
> Those STL functions do actually call `vector.begin()` and `end()`, but they are more generic, i.e. they also work on raw arrays and automatically do the right thing in order to obtain begin/end iterators.

The **iterator** class needs to implement the following:

- operator `*`, which works like dereferencing a pointer (pointers are also valid iterators!)
- operator `++` (prefix), which increments the iterator to the next item
- operator `!=`, which is necessary in order to check if the loop shall terminate because `it` reached the same position as `end` denotes.

In order to implement any kind of algorithm-generated range, we would first implement an iterator which basically hides variables and the algorithm itself in the `operator++` implementation.
An iterable class would then just provide a begin and end iterator as needed, in order to enable for C++11 style `for` loops.

``` cpp
class iterator
{
    // ... state variables ...

public:
    // Constructor

    iterator& operator++() { /* increment */ return *this; }

    T operator*() const { /* return some value or reference */ }

    bool operator!= const (const iterator& o) { /* compare states */ }
}
```

The simplest iterator ever would be a counting iterator: It would just wrap an integer variable, increment it in `operator++` and return the integer in `operator*`.
`operator!=` would then just compare this number with the number of another iterator.

But now let us continue with the fibonacci iterator.

# Fibonacci Iterator

``` cpp
class fibit
{
    size_t i {0};
    size_t a {0};
    size_t b {1};

public:
    constexpr fibit() = default;

    constexpr fibit(size_t b_, size_t a_, size_t i_)
        : i{i_}, a{a_}, b{b_}
    {}

    size_t operator*() const { return b; }

    constexpr fibit& operator++() {
        const size_t old_b {b};
        b += a;
        a  = old_b;
        ++i;
        return *this;
    }

    bool operator!=(const fibit &o) const { return i != o.i; }
};
```

Using this iterator, it is already possible to iterate over fibonacci numbers:

``` cpp
fibit it;

// As the comparison operator only compares the "i" variable,
// define an iterator with everything zeroed, but "i" set
// to 20, in order to have an iteration terminator
const fibit end {0, 0, 20};

while (it != end) {
    std::cout << *it << '\n';
    ++it;
}

// Or do it the elegant STL way: (include <iterator> first)
std::copy(it, end, std::ostream_iterator<size_t>{std::cout,"\n"});
```

In order to do it the nice C++11 way, we need an iterable class:

``` cpp
class fib_range
{
    fibit  begin_it;
    size_t end_n;

public:
    constexpr fib_range(size_t end_n_, size_t begin_n = 0)
        : begin_it{fibit_at(begin_n)}, end_n{end_n_}
    {}

    fibit begin() const { return begin_it; }
    fibit end()   const { return {0, 0, end_n}; }
};
```

We can now write...

``` cpp
for (const size_t num : fib_range(10)) {
    std::cout << num << '\n';
}
```

... which will print the first 10 fibonacci numbers.

What does the function `fibit_at` do?
This function is a `constexpr` function, which advances a fibonacci iterator at *compile time* if possible, in order to push the iterator towards the fibonacci number which the user wants:

``` cpp
constexpr fibit fibit_at(size_t n)
{
    fibit it;
    for (size_t i {0}; i < n; ++i) {
        ++it;
    }
    return it;
}
```

This function enables us to for example iterate from the 100th fibonacci number to the 105th, without having to calculate the first 100 fibonacci numbers at run time, because we can make the compiler prepare everything at compile time.

> When using C++17, `fibit_at` is useless, as it can be substituted by `std::next(fibit{}, n)`, because in the C++17 STL `std::next` is a `constexpr` function.

In order to guarantee, that the 100th fibonacci number is already calculated, when the compiler writes the binary program to disk, we can just put the range into a `constexpr` variable:

``` cpp
constexpr const fib_range hundred_to_hundredfive {105, 100};

for (size_t num : hundred_to_hundredfive) {
    // Do whatever
}
```

# Combine the Fibonacci Iterator with STL algorithms

Imagine we need a vector with the first 1000 fibonacci numbers.
Having the fibonacci algorithm already wrapped into a handy iterator class, we can now use it with any STL algorithm from namespace `std`:

``` cpp
std::vector<size_t> fib_nums;
fib_nums.resize(1000);

constexpr const fib_range first1000 {1000};
std::copy(std::begin(first1000), std::end(first1000), std::begin(fib_nums));
```

This is pretty neat and useful.
However, with the current example code provided as is, this will not compile (yet), because we did not provide an iterator tag.
Providing it is simple: Just make `fibit` publicly inherit from `std::iterator<std::forward_iterator_tag, size_t>`.

`std::iterator` as a base class for our `fibit` class will only add some typedefs which help STL algorithms identify which kind of iterator this is.
For certain iterator types in certain situations, the STL algorithms have different implementations which contain performance optimizations (Which is elegantly hidden from the user!).

The `std::forward_iterator` tag states, that this is an iterator which can just be advanced step by step, and that it only advances forward, not backward.

# Summary

A lot of algorithms which generate numeric ranges, can be implemented in terms of iterators, which is a natural fit.
C++ provides nice syntax sugar for iterators, which makes them a natural interface for abstractions.

In combination with STL algorithms and any STL compatible data structures, they promote for easy to read, easy to test, easy to maintain, and performant code.

This article described a kind of iterator, which is not a plain pointer to *data*.
It is an algorithm implementation in the sense, that the *increment* step does actually calculate something more complex than just a new internal pointer position to some next item.
Interestingly, this way one can instantiate some kind of *iterable* object, which defines a range, which involves a lot of computation - but that computation is not executed until someone actually asks for the result (And the code which asks for the result does not even need to know what kind of algorithm it is implicitly executing, as this is all hidden behind a simple iterator interface).
This kind of programming style goes towards [lazy evaluation](https://en.wikipedia.org/wiki/Lazy_evaluation), which is a powerful and elegant principle known from purely functional programming languages.

