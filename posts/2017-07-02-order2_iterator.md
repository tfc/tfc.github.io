---
layout: post
title: Iterators are also part of the C++ zero cost abstractions
---

This article picks up an example operating system kernel code snippet that is written in C++, but looks like "C with classes".
I think it is a great idea to implement Embedded projects/kernels in C++ instead of C and it's nice to see that the number of embedded system developers that use C++ is rising.
Unfortunately, I see stagnation in terms of modern programming in embedded/kernel projects in the industry.
After diving through the context i demonstrate how to implement a nice iterator as a zero cost abstraction that helps tidy up the code.

<!--more-->

## The real life story

> This context dive is rather long.
> If you dont care about the actual logic behind the code, just jump to the next section.

As an intern at Intel Labs in 2012, I had my first contact with microkernel operating systems that were implemented in C++.
This article concentrates on a recurring code pattern that I have seen very often in the following years also in other companies.
I have the opinion that such code should be written *once* as a little library helper.

Let's jump right into it:
Most operating systems allow processes to share memory.
Memory is then usually shared by one process that tells the operating system kernel to map a specific memory range into the address space of another process, possibly at some different address than where it is visible for the original process.

In those [microkernel operating system](https://en.wikipedia.org/wiki/Microkernel) environments I have been working on, memory ranges were described in a very specific way:
The beginning of a chunk is described by its *page number* in the virtual memory space.
The size of a chunk is described by its *order*.

> Both these characteristics are then part of a *capability range descriptor* and are used by some microkernel operating systems to describe ranges of memory, I/O ports, kernel objects, etc.
> Capabilities are a [security concept](https://en.wikipedia.org/wiki/Capability-based_security) i would like to ignore as much as possible for now, because the scope of this article is the maths behind capability range descriptors.

Example:
A memory range that is 4 memory pages large and begins at address `0x123000` is described by `(0x123, 2)`.
We get from `0x123000` to `0x123`, because pages are 4096 bytes (0x1000 in hex) large. That means that we need to divide a virtual address pointer value by `0x1000` and get a virtual page number.
From 4 pages we get to the order value `2`, because $$4 = 2^2$$, so the order is 2.

Ok, that is simple. It stops being simple as soon as one describes real-life memory ranges.
Such a `(base, order)` tuple is also called a *capability range descriptor*, and must follow the following rules:

1. Every memory capability's size must be a power of 2. (By storing only the order, this rule is implicitly followed by design.)
2. Every capability's base must be evenly divisible by its size.

That means if we want to describe the memory range `[0x100, 0x107)` (the notation `[a, b)` means that the range goes from `a` to `b`, but does not contain `b`. Like it is the case for begin/end iterator pairs) following those rules, we would break it into multiple capability range descriptors:

- `(0x100, 2)`, $$2^2 = 4$$ pages
- `(0x104, 1)`, $$2^1 = 2$$ pages
- `(0x106, 0)`, $$2^0 = 1$$ pages

Let's get towards actual code:
Mapping such an example range to another process's address space would then look like the following code, which maps its own range `[0x100, 0x107)` to `[0x200, 0x207)` in the namespace of the other process using a structure `map_helper`:

{% highlight c++ %}
map_helper.source_base = 0x100;

map_helper.push_back(0x200, 2); // 2^2 pages = 4 pages
map_helper.push_back(0x204, 1); // 2^1 pages = 2 page
map_helper.push_back(0x206, 0); // 2^0 pages = 1 page
                                //       sum = 7 pages

map_helper.delegate(target_address_space);
{% endhighlight %}

The `map_helper.delegate(...)` call results in a system call to the kernel which does the actual memory mapping.
In order to not result in one system call per mapping, `map_helper` accepts a whole batch of mappings that are sent to the kernel in one run.

> This looks very complicated but it is necessary to keep the microkernel *micro*.
> When the kernel gets mapping requests preformatted like this, the kernel code that applies the mapping contains much less complicated logic.
> An operating system kernel with a reduced amount of complicated logic is a good thing to have because then it is easier to prove that it is *correct*.

Ok, that is nearly everything about expressing memory mappings with the logic of capability range descriptors.
There is one last quirk.

Imagine we want to map the range `[0x0, 0x10)`, which can be expressed as `(0x0, 4)` (`0x10 = 16`, and $$16 = 2^4$$), to the range `[0x1, 0x11)` in the other process's address space.
That should be easy since they only have an offset of 1 page to each other.
What is visible at address `0x1000` in the first process, will be visible at address `0x2000` in the other.
Actually, it is not that easy, because the capability range descriptor `(0x0, 4)` can not simply be described as `(0x1, 4)` in the other process's address space.
It violates rule number 2 because `0x1` is not evenly divisible by `0x10`!

Frustratingly, this means that we need to break down the whole descriptor `(0x0, 4)` into 16 descriptors with order `0` because only such small ones have mappings that comply with the two rules in **both** address spaces.

This was already a worst-case example.
Another less bad example is the following one:
If we want to map `[0x0, 0x10)` to `[0x8, 0x18)` in the other process, we could do that with the two descriptors `(0, 3)` and `(8, 3)`, because both offsets `0x0` and `0x8` are evenly divisible by 8.
That allows for larger chunks.

A generic function that maps *any* page range to another process's address space could finally look like the following:

{% highlight c++ %}
void map(word_t base1, word_t base2, word_t size, foo_t target_address_space)
{
    map_helper.source_base = base1;

    constexpr word_t max_bit {1ull << (8 * sizeof(max_bit) - 1)};

    while (size) {
        // take smaller order of both bases, as both must be divisible by it.
        const word_t min_order {order_min(base1 | base2 | max_bit)};
        // take largest possible order from actual size of unmapped rest
        const word_t max_order {order_max(size)};
        // choose smaller of both
        const word_t order     {min(min_order, max_order)};

        map_helper.push_back(base2, order);

        if (map_helper.full()) {
            map_helper.delegate(target_address_space);
            map_helper.reset();
            map_helper.source_base = base1;
        }

        const word_t step {1ull << order};

        base1 += step;
        base2 += step;
        size  -= step;
    }

    map_helper.delegate(target_address_space);
}
{% endhighlight %}

As a newcomer to such a project, you will soon understand the maths behind it.
You will see it everywhere, because the same technique is used for sharing memory, I/O ports, and descriptors for kernel objects like threads, semaphores, etc. between processes.

After you have seen repeatedly exactly the same calculation with different *payload* code between it, you might get sick of it.
Everywhere in the code base where this pattern is repeated, you have to follow the calculations thoroughly in order to see if it is **really** the same formula.
If it is, you may wonder why no one writes some kind of library for it instead of duplicating the formula in code again and again.
And if it is *not* the same formula - is that because it is wrong or is there an actual idea behind that?
It is plainly annoying to write and read this from the ground on all the time.

## Library thoughts

Ok, let's assume that this piece of math will be recurring very often and we want to provide a nice abstraction for it.
This would have multiple advantages:

- Reduced code duplication.
- Correctness: The library can be tested meticulously, and all user code will automatically profit from that. No one could ever do wrong descriptor calculations any longer if he/she just used the library.
- Readability: User code will not be polluted by the same calculations again and again. Users do not even need to be able to implement the maths themselves.

One possibility is to write a function `map_generic` that accepts a callback function that would get already calculated chunks as parameters and that would then do the payload magic:

{% highlight c++ %}
template <typename F>
void map_generic(word_t base1, word_t base2, word_t size, F f)
{
    constexpr word_t max_bit {1ull << (8 * sizeof(max_bit) - 1)};

    while (size) {
        // take smallest order of both bases, as both must be divisible by it.
        const word_t min_order {order_min(base1 | base2 | max_bit)};
        // take largest possible order from actual size of unmapped rest
        const word_t max_order {order_max(size)};
        // choose smallest of both
        const word_t order     {min(min_order, max_order)};

        f(base1, base2, order);

        const word_t step {1ull << order};

        base1 += step;
        base2 += step;
        size  -= step;
    }
}

void map(word_t base1, word_t base2, word_t size, foo_t target_address_space)
{
    map_helper.source_base = base1;

    map_generic(base1, base2, size, 
        [&map_helper](word_t b1, word_t b2, word_t order) {
            map_helper.push_back(b2, order);

            if (map_helper.full()) {
                map_helper.delegate(target_address_space);
                map_helper.reset();
                map_helper.source_base = b1;
            }
        });

    map_helper.delegate(target_address_space);
}
{% endhighlight %}

What we have is now the pure math of capability range composition of generic ranges in `map_generic` and actual memory mapping code in `map`.
This is already much better but leaves us without control *how many* chunks we actually want to consume at a time.
As soon as we start `map_generic`, it will shoot all the sub-ranges at our callback function.
At this point, it is hard to stop.
And if we were able to stop it (for example by returning `true` from the callback whenever it shall continue and returning `false` if it shall stop), it would be hard to resume from where we stopped it.
It's just hardly composable coding style.

## The iterator library

After all, this is C++.
Can't we have some really nice and composable things here?
Of course, we can.
How about iterators?
We could define an iterable range class which we can feed with our memory geometry.
When such a range is iterated over, it emits the sub-ranges.


So let's implement this in terms of an iterator.
If you don't know yet how to implement iterators, you might want to have a look at [my other article where i explain how to implement your own iterator]({% post_url 2016-09-04-algorithms_in_iterators %}).

{% highlight c++ linenos %}
#include <cstdint>   // uintptr_t
#include <algorithm> // min/max
#include <tuple>

using word_t = uintptr_t;

static word_t current_order(word_t base, word_t rest) {
    const word_t max_bit   {1ull << (8 * sizeof(max_bit) - 1)};
    const word_t min_order {order_min(base | max_bit)};
    const word_t max_order {order_max(rest)};
    return std::min(min_order, max_order);
}

// This class is iterable range and iterator at the same time
struct order_range
{
    word_t base1;
    word_t base2;
    word_t size;

    // operator-Xs fulfill the iterator interface
    std::tuple<word_t, word_t, word_t> operator*() const {
        return {base1, base2,
                current_order(base1 | base2, size)};
    }

    order_range& operator++() {
        auto step (1ull << current_order(base1 | base2, size));
        base1 += step;
        base2 += step;
        size  -= step;
        return *this;
    }

    class it_sentinel {};

    bool operator!=(it_sentinel) const { return size; }

    // begin/end functions fulfill the iterable range interface
    order_range begin() const { return *this; }
    it_sentinel end()   const { return {}; }
};
{% endhighlight %}

This looks a bit bloaty at first, but this is a one-time implementation after all.
When we compare it with the initial `for`-loop version, we realize that all the calculations are in the function `current_order` and `operator++`.
All the other code is just data storage and retrieval, as well as iterator interface compliance.

It might also at first look strange that the `begin()` function returns a copy of the `order_range` instance. 
The trick is that this class is at the same time a range and an iterator.

One nice perk of C++17 is, that the *end* iterator does not need to be of the same type as normal iterators any longer.
This allows for a simpler abort condition (which is: `size == 0`).

With this tiny order 2 range iterator *"library"*, we can now do the following.
(Let's move away from the memory mapping examples to simple `printf` examples because we will compare them in [Godbolt](https://gcc.godbolt.org) later)

{% highlight c++ %}
void print_range(word_t base1, word_t base2, word_t size)
{
    for (const auto &[b1, b2, order] : order_range{base1, base2, size}) {
        printf("%4zx -> %4zx, order %2zu\n", b1, b2, order);
    }
}
{% endhighlight %}

This code just contains *pure payload*.
There is no trace of the mathematical obfuscation left.

Another differentiating feature from the callback function variant is that we can combine this iterator with STL data structures and algorithms!

## Comparing the resulting assembly

What is the price of this abstraction? 
Let us see how the non-iterator-version of the same code would look like, and then compare it in the Godbolt assembly output view.

{% highlight c++ %}
void print_range(word_t base1, word_t base2, word_t size)
{
    constexpr word_t max_bit {1ull << (8 * sizeof(max_bit) - 1)};

    while (size) {
        const word_t min_order {order_min(base1 | base2 | max_bit)};
        const word_t max_order {order_max(size)};
        const word_t order     {std::min(min_order, max_order)};

        printf("%4zx -> %4zx, order %2zu\n", base1, base2, order);

        const word_t step {1ull << order};

        base1 += step;
        base2 += step;
        size  -= step;
    }
}
{% endhighlight %}

Interestingly, `clang++` sees exactly what we did there and emits exactly **the same assembly** in **both** cases.
That means that this iterator is a real **zero cost** abstraction!

{% highlight asm %}
print_range(unsigned long, unsigned long, unsigned long): 
        push    r15
        push    r14
        push    r13
        push    r12
        push    rbx
        mov     r14, rdx
        mov     r15, rsi
        mov     r12, rdi
        test    r14, r14
        je      .LBB0_3
        movabs  r13, -9223372036854775808
.LBB0_2: # =>This Inner Loop Header: Depth=1
        mov     rax, r12
        or      rax, r15
        or      rax, r13
        bsf     rbx, rax
        bsr     rax, r14
        cmp     rax, rbx
        cmovb   rbx, rax
        mov     edi, .L.str
        xor     eax, eax
        mov     rsi, r12
        mov     rdx, r15
        mov     rcx, rbx
        call    printf
        mov     eax, 1
        mov     ecx, ebx
        shl     rax, cl
        add     r12, rax
        add     r15, rax
        sub     r14, rax
        jne     .LBB0_2
.LBB0_3:
        pop     rbx
        pop     r12
        pop     r13
        pop     r14
        pop     r15
        ret
.L.str:
        .asciz  "%4zx -> %4zx, order %2zu\n"
{% endhighlight %}

[See the whole example in gcc.godbolt.org.](https://godbolt.org/g/hn3yix)

When comparing the assembly of both variants with GCC, the result is a little bit disappointing at first:
The `for`-loop version is 62 lines of assembly vs. 48 lines of assembly for the iterator version. 
When looking at how many lines of assembly are the actual loop part, it is still 25 lines for **both** implementations!

## Summary

Hardcore low-level/kernel hackers often claim that it's disadvantageous to use abstractions like iterators and generic algorithms.
Their code needs to be very small and fast because especially on hot paths, interrupt service routines, and other occasions, the kernel surely must not be bloaty and slow.

Unfortunately, one extreme kind of low-level hackers that keep their code tight and short just out of plain responsibility, are the ones that use the same reasons as an excuse for writing code that contains a lot of duplicates, is complex, hard to read (but surely makes you feel smart while being written), and difficult to test.

Code should be separated into composable libraric parts that serve isolated concerns.
C++ allows combining the goals of reusable software, testable libraries, and logical decoupling with high performance and low binary size.

It is usually worth a try to implement a nice abstraction that turns out to be free with regard to assembly size and performance.

## Related 

I really enjoyed reading [Krister Waldfridsson's article](https://kristerw.blogspot.de/2017/06/a-look-at-range-v3-code-generation.html) where he primarily analyzes runtime performance of a piece of range-v3 code.
What's interesting about that article is that he also shows an innocently looking code snippet with a raw `for`-loop that is slower than equivalent code that uses an STL algorithm, because the STL algorithm helps the compiler optimizing the code.

Another thing that is worth a look and which fits the same topic:
Jason Turner gave a [great talk about using C++17 on tiny computers](https://www.youtube.com/watch?v=zBkNBP00wJE). 
He demonstrates how modern C++ programming patterns that help writing better code do **not** lead to bloaty or slow code by compiling and showing the assembly in a Godbolt view.
It actually runs on a real Commodore in the end.


