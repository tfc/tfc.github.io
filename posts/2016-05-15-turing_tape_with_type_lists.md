---
title: Implementing a Turing Tape for Use at Compile Time
tags: c++, metaprogramming
---

<!-- cSpell:disable -->

Turing Machines consist of a tape with memory cells, a tape reader like cassette drives and a program table.
Implementing the tape drive part with an array and a pointer is a trivial thing to do with imperative programming languages.
It becomes more interesting when learning purely functional programming, especially in the context of template meta programming in C++.
As a preparation for the next article, i will show how to implement a turing tape based on type lists, usable at compile time.

<!--more-->

> The code in this article depends largely on the code in [the article about type lists](/2016/05/08/compile_time_type_lists %}), and [the article about character type list transformations](/2016/05/14/converting_between_c_strings_and_type_lists).

The tape is implemented as a data structure containing two type lists and a cursor type.
This structure embodies the idea that, when looking at a turing tape, there is a *current* cell, which is represented by the cursor type.
Left and right of the current cell is the rest of the tape, which is represented by those two lists.

Easy enough, this is the template type signature of the turing tape:

``` cpp
template <class LList, class Cursor, class RList>
struct tape;
```

Just as described previously, it contains a list representing the left part of the tape, a list representing the right part of the tape, and the cursor is located just between them.
In theory, the turing tape is infinitely long.
Representing it with lists, it is very easy to make it virtually infinitely long, because it is possible to attach new cells to it on demand, as soon as it seems to end.

The operations which can be applied to a turing tape, are:

- **Get**: Read the value from the cell at the cursor
- **Set**: Assign a new value to the cell at the cursor
- **Shift Left**: Move the cursor to the *left* neighbor of the current one
- **Shift Right**: Move the cursor to the *right* neighbor of the current one

In imperative programming, the data structure containing the turing tape state would just be modified in trivial ways.
In purely functional programming, we would create a completely new data structure instance, which differs from the old one in so far that it contains the desired modification.

Implementing the `tape` template class has a simple base case, and three special cases:

- Case 1: The tape consists of non-empty left and right lists
- Case 2: The tape only consists of the cursor item (Left and right list are empty)
- Case 3: The left list is empty, the right one is non-empty
- Case 4: The right list is empty, the left one is non-empty

The most complicated part of the following code is the *pattern matching* part of the template type signature.

### Case 1: Non-empty Left/Right Lists

``` {.cpp .numberLines }
template <class LHead, class LTail,
          class Cursor,
          class RHead, class RTail>
struct tape<
           tl<LHead, LTail>, // Non-Empty Left List
           Cursor,
           tl<RHead, RTail>  // Non-Empty Right List
       > {
    using get = Cursor;

    template <class T>
    using set = tape<
                    tl<LHead, LTail>,
                    T,
                    tl<RHead, RTail>>;

    using move_left  = tape<
                           LTail,
                           LHead,
                           tl<Cursor, tl<RHead, RTail>>>;
    using move_right = tape<
                           tl<Cursor, tl<LHead, LTail>>,
                           RHead,
                           RTail>;
};
```
<br>

- **Lines 5-7** match only on turing tape instances, which do not consist of empty lists at the left or right.
An empty list is a `null_t`, and will not match on `tl<LHead, LTail>`.
After having successfully matched a non-empty list, the template variables `LHead` and `LTail` hold the head, and the rest (tail) of the left list.
Same applies to the right list with its respective template variables `RHead` and `RTail`.
- **Line 9** defines the ***get*** function. It just trivially returns the matched `Cursor` type.
- **Line 12** defines the ***set*** function. This one looks a little more complicated, because  it is a templated `using` clause within a template class, but of course it needs a type parameter,which shall be the new cursor type. That is `T`. It just constructs and returns a new tape instance, which consists of the same left and right list as before, but holds the new cursor value in the middle.
- **Line 17** implements the ***shift left***. When shifting to the left, the tip (head) of the left list moves to the cursor position, which makes the left list also shorter. At the same time, the right list grows, because the former cursor position cell becomes the new tip (head) of the right list. The newly constructed tape contains newly constructed lists following that rule.
- **Line 21** implements the ***shift right***, and works identically, but just in a mirrored sense.

### Case 2: The tape only consists of the cursor item (Left and right list are empty)

This case is very simple.
The **get** and **set** functions work just equal to the one before.

When moving the tape left or right, there are no list heads/tails in both directions.

``` {.cpp .numberLines }
template <class Cursor>
struct tape<
           null_t, // Empty Left List
           Cursor,
           null_t  // Empty Right List
        > {
    using get = Cursor;
    template <class T>
    using set = tape<null_t, T, null_t>;

    using move_left  = tape<
                           null_t,
                           null_t,
                           tl<Cursor, null_t>>;
    using move_right = tape<
                           tl<Cursor, null_t>,
                           null_t,
                           null_t>;
};
```

When shifting the tape to the *left*, the cursor becomes the tip.
It is then the only element in the previously empty right list.
There are no items coming from the left list, so it is still empty.
The cursor is just set to `null_t`, representing an empty cell.

When this list is later used with specific payload types, this situation needs to be fixed in the sense, that empty cells should be initialized to some *default type*.

### Case 3: The left list is empty, the right one is non-empty

I leave case 3 and 4 mostly uncommented.
They are kind of *hybrids* of case 1 and 2, because they match in cases where one list is empty, and the list on the other side is non-empty.
That means that shift left or shift right are actually shifting the respective non-empty list like case 1 does, but then create a new empty item of the other empty list, just like case 2 does.

``` {.cpp .numberLines }
template <class Cursor,
          class RHead, class RTail>
struct tape<
           null_t,          // Empty Left List
           Cursor,
           tl<RHead, RTail> // Non-Empty Right List
       > {
    using get = Cursor;
    template <class T>
    using set = tape<null_t, T, tl<RHead, RTail>>;

    using move_left  = tape<
                           null_t,
                           null_t,
                           tl<Cursor, tl<RHead, RTail>>>;
    using move_right = tape<
                           tl<Cursor, null_t>,
                           RHead,
                           RTail>;
};
```

### Case 4: The right list is empty, the left one is non-empty

Case 4 is just a mirrored version of case 3.

``` {.cpp .numberLines }
template <class LHead, class LTail,
          class Cursor>
struct tape<
           tl<LHead, LTail>, // Non-Empty Left List
           Cursor,
           null_t            // Empty Right List
       > {
    using get = Cursor;
    template <class T>
    using set = tape<
                    tl<LHead, LTail>,
                    T,
                    null_t>;

    using move_left  = tape<
                           LTail,
                           LHead,
                           tl<Cursor, null_t>>;
    using move_right = tape<
                           tl<Cursor, tl<LHead, LTail>>,
                           null_t,
                           null_t>;
};
```

## Adding Convenient `using` Clause Helpers

The `tape` class can already be easily accessed in order to perform all four defined actions on it.
However, this would also be followed by the typical clumsy `typename` keywords.

Therefore we define some `using` clause helpers:

``` cpp
template <class Tape>
using get_t = typename Tape::get;

template <class Tape, class T>
using set_t = typename Tape::template set<T>;

template <class Tape>
using move_left_t  = typename Tape::move_left;

template <class Tape>
using move_right_t = typename Tape::move_right;
```

Another useful helper is `make_t`, which creates a new, empty tape, which already contains a specific type at its cursor position:

``` cpp
template <class T>
using make_t = tape<null_t, T, null_t>;
```

Without those helpers, shifting and setting a newly created tape would look like this:

``` cpp
using foo_tape     = tape<null_t, Foo, null_t>;
using shifted_left = typename foo_tape::move_left;
using set_to_bar   = typename shifted_left::set<Bar>;

// Or in just one line:
using foobar_tape = typename tape<null_t, Foo, null_t>::move_left::set<Bar>;
```

With those helpers, it becomes more readable:

``` cpp
using foo_tape     = make_t<Foo>;
using shifted_left = move_left_t<foo_tape>;
using set_to_bar   = set_t<shifted_left, Bar>;

// Or in just one line:
using foobar_tape = set_t<move_left_t<make_t<Foo>>, Bar>;
```

## Summary

What we've got now is a `tape` structure, which can be instantiated, shifted around and inbetween its empty cells can be filled with values.
A turing machine or any other system for which it would be of use, would wrap around that type and add some more functionality.

When implementing this, being in the role of a novice template meta programmer, i found this to be a nice exercise for *pattern matching*.
