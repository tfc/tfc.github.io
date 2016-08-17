---
layout: post
title: Simple Iterators for Numeric Ranges
---

There are different possibilities to generate numeric ranges from x to y.
The most obvious way to for example fill a vector with numbers is a C-style loop, another way is `std::iota`.
In this article i present a simple iterator implementation which represents a numeric range, and how to use it.
In other words: This article is a simple iterator tutorial.

# The Classic Way

In order to fill a vector with numbers, you can write the following:

{% highlight c++ %}
std::vector<int> v;
v.resize(10);

for (int i {0}; i < 10; ++i) {
    v[i] = i;
}
{% endhighlight %}

Instead of calling `resize`, you could also do `v.push_back(i)`, but that would do multiple heap-reallocations of the backing store.
This is pointless if you know how many items you will put into the vector.

# Iota

The `<numeric>` include contains the standard algorithm `std::iota`.
That algorithm can fill any iterable range with increasing numbers:

{% highlight c++ %}
std::vector<int> v;
v.resize(10);

std::iota(std::begin(v), std::end(v), 0);
{% endhighlight %}

It takes the start value as its third parameter.
The algorithm will go through the iterable range, and assign this value to the elements, while incrementing it between every assignment.

# Numeric Iterator
Another handy way of generating rising numbers is having an iterator, which counts for you:

{% highlight c++ %}
for (int i : numeric_range(10)) {
    std::cout << i << std::endl; // Just print
}
{% endhighlight %}

{% highlight c++ %}
std::vector<int> v;
v.resize(10);

const auto range (numeric_range(10));

std::copy(std::begin(range), std::end(range), std::begin(v));
{% endhighlight %}

If resizing the vector inbetween is ok, it can be used the following way:

{% highlight c++ %}
std::vector<int> v;
const auto range (numeric_range(10));

std::copy(std::begin(range), std::end(range), std::back_inserter(v));
{% endhighlight %}

...the cool thing here is that this could also be an `std::transform` call which does something interesting with the numbers before filling the vector with something derived from them.

In order to get support for this, we need an ***iterable*** class, which provides `begin()` and `end()` functions.
These functions shall return an ***iterator*** class.

So, in the world of iterators, the distinction between `iterable` and `iterator` is important:
The ***iterable*** represents the range which is abstracted from. That can be an `std::vector`, `std::list`, etc.
But it can also be a plain array, or just a memory range which is only known at runtime (Which is then demarked by its begin and end addresses).
The ***iterator*** class represents a logical pointer to an item within that iterable range.
Iterators can be plain C/C++ pointers. Usual pointers are incrementable, they can be dereferenced in order to get at their pointed-to-value, and they can be compared with each other.

Any iterator, which is not a plain C-style pointer, is a class which implements these operations itself.
Being implemented like this, they *imitate* pointers.

> There are also categories of iterators: Input iterators, output iterators, forward iterators, bidirectional iterators, and random access iterators. This article does not really cover all of this, but there is a short *iterator tag* introduction towards the end of the article.

What do iterables and iterators need to implement at least, in order to work as assumed?

Let's have a look at to what the compiler will expand a code line like 

`for (auto i : range_expression) { /* loop body */ }`:

{% highlight c++ %}
{
    auto &&range (range_expression);
    auto begin   (std::begin(range));
    auto end     (std::end(range));
    for (; begin != end; ++begin) {
        auto i (*begin);
        /* loop body */
    }
}
{% endhighlight %}

From what we can see here, iterables and iterators need to provide different functions/operators:

Iterables:

 - `begin()` function (`std::begin(x)` calls `x.begin()` on iterables, but by specialization, can also deal with arrays)
 - `end()` function

 Iterators:

  - `operator!=` For comparing iterators in the loop conditional
  - `operator*` By dereferencing the pointed-at value is revealed
  - `operator++` (pre increment) for advancing the iterator to the next item

So let's first implement the iterator:

{% highlight c++ %}
class iterator
{
    int current;

public:
    iterator(int current_)
        : current{current_}
    {}

    int operator*() const { return current; }

    iterator& operator++() {
        ++current;
        return *this;
    }

    bool operator!=(const iterator &o) const {
        return current != o.current;
    }
};
{% endhighlight %}

That whole iterator is just built around the integer variable `current`.
The increment operator just increments the integer, and the dereference operator plainly returns its value.
The comparison operator for the unequal case compares the `current` value of two iterators.

Now let us have a look at the iterable class, which defines the actual numeric range, and provides the right iterators: The *begin* iterator which can be incremented until it reaches the *end* iterator:

{% highlight c++ %}
class numeric_range
{
    int num_begin;
    int num_end;

public:
    explicit numeric_range(int end, int begin = 0)
        : num_begin{begin}, num_end{end}
    {}

    iterator begin() const { return iterator{num_begin}; }
    iterator end()   const { return iterator{num_end};   }
};
{% endhighlight %}

The class `numeric_range` can now be instantiated, and then work as a provider for iterators.
All code which works with this class, will basically get instances from `begin()` and `end()`.
The iterator which was obtained from the `begin()` function is the one which is doing the work: It will be dereferenced in order to get at the rising numeric values, and it will be incremented for every step.
Whatever algorithm it is using it, it will stop as soon as the iterator is equal to the iterator which was obtained from the `end()` function.

Note, that the `end` iterator will carry the value `10` if you initialize the `numeric_range` class with the parameter `10`, but this is one value past the *actual* last one.
It will iterate from `0` till `9`, then abort.

I also added the possibility to define the beginning: A numeric range initialized with `numeric_range{10, 5}` will iterate from `5` till `9`.

That's nearly it.
The `numeric_range` class is now a nice, slick data structure (it's just two integers large), which can be created to represent a range, and be passed around.
It could very easily be extended by a template parameter to represent different types of numeric values.
And furthermore, one could add a parameter `step_size` to control how far it is incremented every step.

One important detail is, that wherever it is used with `std::copy`, or `std::back_inserter`, it would not compile, so i cheated a little bit by not noting that until now.
The STL algorithms assume, that every iterator has an *iterator tag*.
An iterator tag is a `typedef`/`using` clause which provides information about the nature of the iterator.
Iterators of lists for example are no *random access* iterators.
They need to be incremented step by step, instead of bein able to jump e.g. 5 positions at once, as it would be possible for vectors, for example.

In order to calm down the compiler when using our `numeric_range` iterators with STL algorithms, we can make our `iterator` class *inherit* from an STL iterator helper:

{% highlight c++ %}
class iterator
    : public std::iterator<std::bidirectional_iterator_tag, int>
{
    /* ... */
};
{% endhighlight %}

This little helper class does not add any run time code to our class.
It merely adds all the type aliases which STL algorithms are looking for to characterize iterators.
Our iterator is not really a *bidirectional* operator at this point.
For this, it would also have to implement the prefix decrement operator (which is quickly done, however).
At least for the example code this is not a problem - the compiler would have complained otherwise.

# Summary

Iterators are a great way to provide iterability over custom data structures, without putting the burden of having to know how this data structure works on the iterating code.
This way, iterators are **the** way to establish a perfect *separation of concerns*: **Iterating** a data structure and **processing** the items of whatever is iterated.

The interface of iterables and iterators is considerably simple.
Implementing your own iterators involves some boiler plate code.
However, iterators are only implemented *once* for every data structure.

After applying a lot of testing on your own iterators, you profit from a lot more bug safety when combining them with the elegant standard algorithms.

There's also a lot of *automatic* optimization potential when using STL standard algorithms, as those provide multiple specializations with different performance for different kinds of iterators (Not covered in this article).
