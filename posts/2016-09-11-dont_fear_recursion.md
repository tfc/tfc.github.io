---
title: Do Not Fear Recursion
tags: c++
---

<!-- cSpell:disable -->

There are a lot of algorithms which can be implemented using *recursive* or *iterative* style.
Actually, **everything** can be implemented in both styles.
For a lot of algorithms, the recursive version is simpler to read, write, and understand.
But nevertheless, programmers know, that recursive functions burden a lot of memory consumption, because there is usually a `call` instruction per recursive call, which puts another call frame on the stack.
Interestingly, this is not true for some special cases.

<!--more-->

The idea to write this article came into my mind when I thought about a discussion which I listened to many years ago.
At that time I worked at a company as a freelancer, before I started studying at university.
The whole discussion was very open, but I felt a bit disturbed when a colleague said, that C/C++ is very limited in their optimization potential.
One example for that point was, that languages like *Scala* can eliminate the stack growth in some recursion cases.
I was very unexperienced, so I didn't know better.
Not too much later, I learned at university, that this special kind of recursion is called [**tail recursion**](https://en.wikipedia.org/wiki/Tail_call).
I was pretty happy when I realized that the optimization potential which that brings, is not a question of the language, but more a question of the compiler implementation.

As of today, this topic came to my attention multiple times.
Since C++11, it is possible to let the compiler execute *normal* functions (instead of template meta code) at compile time, and get a guarantee that the result will be embedded in the binary, reducing execution time.
Such functions are called `constexpr` functions.
However, those functions had to be implemented recursively, as it is not possible to define variables and loops in `constexpr` functions in C++11.
(This is fixed and allowed in C++14)
At this occasion (and because of template meta-programming and learning Haskell) I got some more practice in thinking recursion aware.

## Tail Recursion

Some algorithms are very short and pretty, when implemented recursively.
However, because of the fear that they would be inefficient, coders often just think how to implement them iteratively.
Iterative versions do not increase the stack size, so they feel better.

Alternatively, by thinking of a **tail** recursive version, both simplicity of recursion, and performance of iterative style can be combined.

First: What *is* tail recursion?

Tail recursion occurs, when the result of a recursive function call completely depends on the same function call, just with other parameters.

Example:

``` cpp
int f(int a, int b)
{
    // Some nonsense-algorithm which shows tail recursion
    if (a == 0) {
        return b;
    }
    return f(a * b, b - 1);
}
```

In this case, only the parameters need to be refreshed with the values the next recursion call shall get.
Then, instead of `call`ing the function (which jumps to the function beginning again, but also adds the return address on the stack), it can just be `jmp`ed at, which completely preserves the stack.
(At this point I am talking about the *assembler* instructions `call` and `jmp`, which work similarly for most processor architectures, but may have slightly different names.)

An example case in which this would not work:

``` cpp
int f(int a, int b)
{
    if (a == 0) {
        return b;
    }
    return 1 + f(a * b, b - 1);
}
```

In this case, the `1 + ` part needs to be executed for *every* recursive call, which happens **after** the recursive call.
And for that, real function calls instead of tail jumps are assembled by the compiler.
That can be fixed, however:

``` cpp
int f(int a, int b, int sum = 0)
{
    if (a == 0) {
        return b + sum;
    }
    return f(a * b, b - 1, sum + 1);
}
```

This way, we pushed the information of that "post-adding 1" into the parameter variables and transformed the nonoptimal recursion into a tail recursion.
(At this point, this algorithm does not look nicer than an iterative implementation using a loop. However, other algorithms do.)

That was just a cheap example.
There are actually nice and very generic rules in literature, which describe how to transform between the different coding styles. (See also the Wikipedia article about tail recursion)

## GCD Example

In order to proof the point of tail recursion, and to motivate people to use more recursion for tidy, but still fast code, I chose the [GCD (*Greatest Common Divisor*)](https://en.wikipedia.org/wiki/Greatest_common_divisor) algorithm, and the two typical different implementations of it:

The recursive version, which looks very similar to a math formula (at least in terms of C syntax):
``` cpp
unsigned gcd_rec(unsigned a, unsigned b)
{
    return b ? gcd_rec(b, a % b) : a;
}
```

... and the iterative version, which would have a better performance, if the compiler did not know about tail recursion:

``` cpp
unsigned gcd_itr(unsigned a, unsigned b)
{
    while (b) {
        unsigned tmp {b};
        b = a % b;
        a = tmp;
    }
    return a;
}
```

In my opinion, the recursive version looks much cleaner.
What I particularly dislike when regarding the iterative version, is the fact that it is telling the compiler how exactly to temporarily save the value of `b`, in order to refresh `a` with it after the modulo operation.
This is as primitive as "Well, do `a % b`, but I want `b` saved **here** and then written back **there**", which is something which has nothing to do with the *actual* problem (calculating a GCD).

## Comparing compiler output

Putting those two functions into a `.cpp` file and compiling it with `clang++ -c main.cpp -O2` reveals something interesting:

First, having a look at the recursive version shows, that it does indeed not contain any `call` instructions because it is implemented using solely jumps (conditional `je` and `jne` instructions).
This shows, that this recursive version of the GCD algorithm can never lead to steep stack growth.

``` asm
0000000000000000 <_Z7gcd_recjj>:
   0:	89 f2                	mov    %esi,%edx
   2:	89 f8                	mov    %edi,%eax
   4:	85 d2                	test   %edx,%edx
   6:	74 17                	je     1f <_Z7gcd_recjj+0x1f>
   8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
   f:	00
  10:	89 d1                	mov    %edx,%ecx
  12:	31 d2                	xor    %edx,%edx
  14:	f7 f1                	div    %ecx
  16:	85 d2                	test   %edx,%edx
  18:	89 c8                	mov    %ecx,%eax
  1a:	75 f4                	jne    10 <_Z7gcd_recjj+0x10>
  1c:	89 c8                	mov    %ecx,%eax
  1e:	c3                   	retq
  1f:	c3                   	retq
```

However, looking at the iterative version shows, that both versions are completely **identical**.
This is pretty cool, because this way we can profit from the performance of iterative code, although our C++ code is a slick and tidy recursive implementation!

``` asm
0000000000000020 <_Z7gcd_itrjj>:
  20:	89 f2                	mov    %esi,%edx
  22:	89 f8                	mov    %edi,%eax
  24:	85 d2                	test   %edx,%edx
  26:	74 17                	je     3f <_Z7gcd_itrjj+0x1f>
  28:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
  2f:	00
  30:	89 d1                	mov    %edx,%ecx
  32:	31 d2                	xor    %edx,%edx
  34:	f7 f1                	div    %ecx
  36:	85 d2                	test   %edx,%edx
  38:	89 c8                	mov    %ecx,%eax
  3a:	75 f4                	jne    30 <_Z7gcd_itrjj+0x10>
  3c:	89 c8                	mov    %ecx,%eax
  3e:	c3                   	retq
  3f:	c3                   	retq


```

## Summary

The GCD algorithm is a very short example for the behaviour of telling the compiler much more than needed to solve the actual problem, because imperative programming is all about telling the computer *what* to do, and *how* to do it.
On the level of writing assembler code, it is pretty normal that the question "*what* data?" is pretty much the same as "which memory *address*/register and size?", because there is no abstraction from the hardware implementation nature (a *von Neumann* machine with untyped memory).

When using languages like C++, a lot of abstraction can be gained with *no cost*, which is a favorable thing.
*Tail recursion* is a nice step towards such simplifying abstractions, and can be used for free, which is pretty much worth knowing about it.
