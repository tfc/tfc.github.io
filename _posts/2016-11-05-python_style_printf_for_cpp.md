---
layout: post
title: Python Style printf for C++ with pprintpp
---

The C++ STL comes with *stream* style character output, which is an alternative to the classic `printf` like format function collection of the C library.
For different reasons, some C++ programmers still stick to `printf` like formatting.
This article demonstrates the `pprintpp` [(open source, and available on Github)](https://github.com/tfc/pprintpp) library, which tries to make `printf` use comfortable and safe while avoiding any runtime overhead.

## C++ Streams vs. `printf`

So, I am presenting a `printf` frontend library which tries to enhance it.
But what is wrong with `printf`?
Let's compare it with C++ stream style printing in different situations:

### Round 1: Inconvenience

Consider the following simple program:

{% highlight c++ %}
#include <cstdio>

int main()
{
    printf("%u, %x, %0.8f, %0.8lf, %s\n", 123u, 0x123u, 1.0f, 2.0, "Hello World"); 
}
{% endhighlight %}

It's simply no fun to tell `printf` of which type all variables are.
The compiler *knows* the types already, so why must the programmer type the type names *again*?

C++ streams fix this, as the `operator<<` is properly overloaded for any type, which selects the right formatting method automatically.
Let's have a look how to get exactly the same output with C++ streams:

{% highlight c++ %}
#include <cstdio>
#include <iostream>

int main()
{
    printf("%u, %x, %0.8f, %0.8lf, %s\n", 123u, 0x123u, 1.0f, 2.0, "Hello World"); 

    std::cout << 123u << ", "
              << std::hex << 0x123u << ", "
              << std::fixed << std::setprecision(6) << 1.0f << ", "
              << 2.0 << ", "
              << "Hello World" << std::endl

}
{% endhighlight %}

All type safety aside, at this point most likely everyone will agree that this is, from a readability and comfort perspective, *no* improvement over to `printf`.

> Although I must say that I do not format floating point numbers every day and had to guess here and there while being too lazy to look at the documentation. 
> In order to see if the `printf` format works as I hoped, I had to run the program.
> At the same time, the C++ iostream format just did not compile when I did it wrong!

### Round 2: Type Pitfalls

When compiling the following program on a 64-bit machine, everything is fine:

{% highlight c++ %}
printf("%ld\n", static_cast<uint64_t>(123)); 
{% endhighlight %}

Compiling it on a 32-bit machine, the compiler quickly comes up with errors like:

{% highlight bash %}
error: format '%ld' expects argument of type 'long int', but argument 2 has type 'uint64_t {aka long long unsigned int}' [-Werror=format=]
{% endhighlight %}

So on 32bit systems, one should better have used `%lld`.
This feels needlessly complicated because in both cases, the compiler knows the \*@!#\* type, but nevertheless the programmer has to deal with this now.

There is a portable solution: `PRIu64`.
The header file <cinttypes> brings a lot of PRI macros.
Using this here looks like the following:

{% highlight c++ %}
printf("%" PRIu64 "\n", static_cast<uint64_t>(123)); 
{% endhighlight %}

All the `printf` fans who laughed at the ugliness of C++ streams, now again look a *little bit* like fools.

### Round 3: Repetition

There are certain types which are a data composition of multiple values.
A very typical example are *vectors* of data, e.g. geometric vectors:

{% highlight c++ %}
struct vec3d {
    double x;
    double y;
    double z;
};
{% endhighlight %}

When printing some game state or similar, one usually wants to see vectors formatted like `(1.000, 2.000, 0.000)`.

Okay, easy:

{% highlight c++ %}
printf("(%0.3lf, %0.3lf, %0.3lf)\n", v.x, v.y, v.z);
{% endhighlight %}

What if there are a lot of vectors?

{% highlight c++ %}
printf("(%0.3lf, %0.3lf, %0.3lf), "
       "(%0.3lf, %0.3lf, %0.3lf), "
       "(%0.3lf, %0.3lf, %0.3lf)\n", 
       v1.x, v1.y, v1.z,
       v2.x, v2.y, v2.z,
       v2.x, v3.y, v3.z);
{% endhighlight %}

Okay, it starts to get very repetitive.

> And we have a bug: I mistyped the `x` value of the third vector.
> Would you have seen it in a code review?

C++ iostream users would just overload `operator<<` for `std::ostream` **once** and be done with this forever:

{% highlight c++ %}
std::ostream& operator<<(std::ostream &os, const vec3d &v) {
    return os << "(" 
              << std::setprecision(4) 
              << v.x << ", " << v.y << ", " << v.z 
              << ")";
}
{% endhighlight %}

Printing multiple vectors now looks like this:

{% highlight c++ %}
std::cout << v1 << ", " << v2 << ", " << v3 << std::endl;
{% endhighlight %}
      
`printf` users may start defining helpful macros:

{% highlight c++ %}
#define PRIvec3d       "(%0.3lf, %0.3lf, %0.3lf)"
#define UNPACKvec3d(v) (v).x, (v).y, (v).z
{% endhighlight %}

...and print their vectors like this:

{% highlight c++ %}
printf(PRIvec3d ", " PRIvec3d ", " PRIvec3d "\n", 
       UNPACKvec3d(v1), UNPACKvec3d(v2), UNPACKvec3d(v3));
{% endhighlight %}

In my opinion, C++ streams clearly win at this point.

## Being Stuck with `printf`. For Reasons.

Situations exist, where developers really can't use stream printing.
The reasons for those situations might be technical, but there are also social reasons:
What are you going to do if you work in a team with `printf` dinosaurs, who **just like it**, and then it becomes a project convention to use `printf`?
Right, nothing.

I found myself in such a situation.
And I made format string mistakes all the time, which led me to think about how to *fix* `printf` by removing a whole class of bug sources.
Bjarne Stroustrupi's C++ book proposes a type safe `printf` (Section 28.6.1), which is implemented using variadic templates.
My team did not find this solution acceptable because it generates *custom code* for every `printf` invocation.

## The Idea

When using `printf`, the programmer asks himself "What is the type of the variable I am going to print?", and as soon as that question is answered, the next question is "What is the right `%` format string for this type?".
The compiler can easily answer these questions.
The next thing is: How to make the compiler do that, without generating additional runtime code?

In the past, I wrote about [type lists which can be used as compile-time data structures for metaprograms]({% post_url 2016-05-08-compile_time_type_lists %}).
And building on top of that, I wrote about [transforming string literals to type lists, doing something with them and transforming back to string literals]({% post_url 2016-05-14-converting_between_c_strings_and_type_lists %}).
Understanding the ideas from those articles is crucial for understanding the code of this library.

After a lot of inspiring discussions with my colleagues, we iterated towards the idea of having a compile time function, which takes a simplified format string, and a list of the types of the parameters the user provided.
The syntax of the simplified format string was inspired by Python style printing.
In Python, you can do the following:

{% highlight python %}
python shell >>> "some {} with some var {}".format("string", 123)
'some string with some var 123'
{% endhighlight %}

Being inspired from that, I hoped to be able to come up with something like...

{% highlight c++ %}
printf(metaprog_result("some {} with some var {}", 
                       typelist<const char *, int>), 
       "string", 123);
{% endhighlight %}

...which collapses to the following during compile time:

{% highlight c++ %}
printf("some %s with some var %d", "string", 123);
{% endhighlight %}

With this design, it is also possible to use the meta-program as a frontend for not only `printf`, but also `sprintf`, `fprintf`, etc.

### First Step: Defining an `autoformat` Macro

The first problem is, that the parameters `"string", 123` need to be both present in the `printf` function call as parameters, and at the same time, a type list `<const char*, int>` needs to be extracted out of them.
The only way I was able to come up with was a preprocessor macro:

{% highlight c++ %}
#define AUTOFORMAT(fmtstr, ...) \
    ({ \
        using paramtypes = create_typelist_from_params(__VA_ARGS__)); \
        return_preprocessed_format_str(fmtstr, paramtypes); \
    })

#define pprintf(fmtstr, ...) \
    printf(AUTOFORMAT(fmtstr, __VA_ARGS__), __VA_ARGS)
{% endhighlight %}

This way it is possible to extract a type list with all the parameter types, feed it into a metaprogram which preprocesses and transforms the simplified format string, and then puts a `printf` compatible result into `printf`.
And that would then happen without adding any portion of additional runtime code.

Unfortunately, in C++ (even including C++17) there is currently no other way to do this without C preprocessor macros.

### Second Step: Obtaining the Type List

What we have: `"some string", 123`.
What we want: `const char*, int`.

In the `AUTOFORMAT` macro, the parameters, separated by commas, are available via `__VA_ARGS__`.
These can be put into a template function call, which deduces the types:

{% highlight c++ %}
template <typename ... Ts>
make_t<Ts...> tie_types(Ts...);
{% endhighlight %}

This function does not even need to be defined because it is only used in a `decltype` environment.
No runtime code will lever call it.
Within the `pprintf` macro, it can now be used the following way:

{% highlight c++ %}
using paramtypes = decltype(tie_types(__VA_ARGS__));
{% endhighlight %}

`paramtypes` is now a type list.
`make_t<const char*, int>` evaluates to `tl<const char*, tl<int, null_t>>` (Read more about how this in particular works in the [type list article]({% post_url 2016-05-08-compile_time_type_lists %})).

### Third Step: Transforming the Simplified Format String

Having the simplified format string with `{}` braces, and the list of types the user provided as `printf` arguments, this can be fed to some algorithm which constructs a `printf` compatible format string.

The following statement will run the metaprogram function `autoformat_t`, which results in a struct with a static member function `str()`, which returns the `printf` compatible result string:

{% highlight c++ %}
autoformat_t<strprov, paramtypes>::str();
{% endhighlight %}

What `autoformat_t` does, is basically:

 1. Iterate through the simplified format string.
 2. For every opening `{` brace, find the closing `}` brace.
 3. For every pair of braces, take the right argument type from the type list.
 4. Map from `type` to `%foo` format string (There is a lookup table of those), and substitute the braces by the format string piece.

The brace match search algorithm looks really similar to the [function of the compile-time brainfuck interpreter, which searches for matching `[]` pairs]({% post_url 2016-06-16-cpp_template_compile_time_brainfuck_interpreter %}).

### Detail Features

Just looking for `{}` braces and substituting them by format string pieces is not enough.
There are different cases and use cases which must be handled:

#### Printing Strings

When a programmer writes `pprintf("Buffer address: {}\n", some_char_buffer);`, it is **not** wise to substitute the `{}` with `%s`.
As the example already suggests, the parameter is of type `char*`, but it is not a null terminated string.

Different implementation strategies can be applied:

 1. Let the user cast the parameter to `void*`, then `autoformat_t` will substitute the braces with `%p` to print the address of the buffer.
 2. Let the user additionally type `{s}` between the braces, so `autoformat_t` knows that the user **really** wants to print it as a string.

I chose method *2*.
Printing a string now looks like this:

{% highlight c++ %}
pprintf("Some string: {s}", "Hello World");
{% endhighlight %}

#### Formatting Integers as Hex Numbers

When a programmer writes `pprintf("Some hex number: {}", 0x123);`, there must be some possibility to express "I want this integer printed as hex number instead of a decimal number".

I chose to let the user provide this information between the braces by writing `{x}`.
This way any integer of any size will be printed correctly as `%x`, or `%lx`, or `%llx`.

**Example**: `pprintf("{x}", 0x123);` results in `printf("%x", 0x123);`

#### Adding Additional Format Info

What if the user wants to print a `double` variable, but also needs to specify the precision?

In that case, `autoformat_t` will just take anything which is not an `x` or `s` (as used as a special specifier for string or hex number formatting) and put it between the `%` and the `f` or `lf` for doubles.
This works for any type.

This strategy is applied to all types.
This way it is possible to tamper with the indentation, precision, etc. whatever `printf` supports for which type.

**Example**: `pprintf("{0.3}", 1.23);` results in `printf("%0.3lf", 1.23);`

#### Printing Actual `{}` Braces

If the user wants to print actual `{}` braces, it must be possible to mask them somehow.

If `autoformat_t` runs over an opening brace but finds it masked with `\`, it will ignore it.
The closing brace is ignored already because the closing brace search function is not called.

However, there are actually 2 backslashes needed because `\` alone does not result in an actual "\" string part.
The backslash must be masked itself, so only `\\{` will result in the `autoformat_t` function seeing a `\{`.

**Example**: `pprintf("var in braces: \\{ {} }", 123);` results in `printf("var in braces: { %d }", 123);`
#### Catching Brace Mismatches

The meta-program refuses to compile if...

- it does not find a closing brace for an opening one.
- it finds nested braces `{ {} }`, in which case it looks probable that the user wanted to mask the outer pair.
- it finds more `{}` placeholders than parameters provided by the user.
- it finds less `{}` placeholders than parameters provided by the user.


### The Type-to-Format-String Lookup Table

All types are cleaned from any `const` etc. noise, and then fed into the `type2fmt` function:

{% highlight c++ %}
template <typename T> struct type2fmt;

// Integral types
template <> struct type2fmt<char>                { using type = char_tl_t<'c'>; };
template <> struct type2fmt<short>               { using type = char_tl_t<'d'>; };
template <> struct type2fmt<int>                 { using type = char_tl_t<'d'>; };
template <> struct type2fmt<long int>            { using type = char_tl_t<'l', 'd'>; };
template <> struct type2fmt<long long int>       { using type = char_tl_t<'l', 'l', 'd'>; };
template <> struct type2fmt<unsigned char>       { using type = char_tl_t<'u'>; };
template <> struct type2fmt<unsigned short>      { using type = char_tl_t<'u'>; };
template <> struct type2fmt<unsigned>            { using type = char_tl_t<'u'>; };
template <> struct type2fmt<unsigned long>       { using type = char_tl_t<'l', 'u'>; };
template <> struct type2fmt<unsigned long long>  { using type = char_tl_t<'l', 'l', 'u'>; };

// Floating point
template <> struct type2fmt<float>  { using type = char_tl_t<'f'>; };
template <> struct type2fmt<double> { using type = char_tl_t<'l', 'f'>; };

// Pointers
template <> struct type2fmt<std::nullptr_t> { using type = char_tl_t<'p'>; };
template <typename T> struct type2fmt<T*>   { using type = char_tl_t<'p'>; };
{% endhighlight %}

`type2fmt` will then return a character type list, which can be used to compose the right format string for `printf`.

Note that the 32bit/64bit safety comes from here.
For 64bit systems, `uint64_t` is an `unsigned long`, while it is an `unsigned long long` on 32bit systems.
When the user writes `pprintf("Some 64bit unsigned: {}", uint64_t(123));`, the compiler will go through all the typedef aliases, and boil the type down to `unsigned long`, or `unsigned long long`, depending on what platform the code is compiled for.
Because of this, `type2fmt` will automatically translate the `uint64_t` to the right format string: `%lu` or `%llu`.
No `PRIu64` necessary.

## No Runtime Overhead

What's with the "no runtime overhead" and "no additional runtime code" promise?

Compiling the program...

{% highlight c++ %}
#include <cstdio>
#include <pprintpp.hpp>

int main()
{
    pprintf("{} hello {s}! {}\n", 1, "world", 2);
}
{% endhighlight %}

...leads to the following `main` function in the binary:

{% highlight bash %}
bash $ objdump -d example
...
0000000000400450 <main>:
  400450:       48 83 ec 08             sub    $0x8,%rsp
  400454:       41 b8 02 00 00 00       mov    $0x2,%r8d
  40045a:       b9 04 06 40 00          mov    $0x400604,%ecx # <-- "world"
  40045f:       ba 01 00 00 00          mov    $0x1,%edx
  400464:       be 10 06 40 00          mov    $0x400610,%esi # <-- "%d hello world %s!..."
  400469:       bf 01 00 00 00          mov    $0x1,%edi
  40046e:       31 c0                   xor    %eax,%eax
  400470:       e8 bb ff ff ff          callq  400430 <__printf_chk@plt>
  400475:       31 c0                   xor    %eax,%eax
  400477:       48 83 c4 08             add    $0x8,%rsp
  40047b:       c3                      retq
...
{% endhighlight %}

Excerpt of the data section where the strings which are loaded reside:

{% highlight bash %}
bash $ objdump -s -j .rodata example
...
Contents of section .rodata:
 400600 01000200 776f726c 64000000 00000000  ....world.......
 400610 25642068 656c6c6f 20257321 2025640a  %d hello %s! %d.
 400620 00                                   .
{% endhighlight %}

The string looks exactly as if one had written `printf("%d hello %s! %d\n", /* ... */);`.

Having exactly that string embedded in the binary does **not** rely on optimization.
It *may* happen, that the `str()` function which statically returns this string, is still called in an unoptimized binary. 
But this function does *nothing* else than returning this string, which is already composed in the binary.

## Limitations

The `autoformat_t` meta-program does only substitute generic placeholders with the right `%` format strings, which are compatible with `printf`.

It does **not** extend `printf` with more formatting capabilities.
This way it is also not possible to print custom types because it is not possible to put some custom `%` format string into `printf`, which the original `printf` implementation does not know.

Of course, it is possible to extend the type knowledge of the `type2fmt` meta function, in order to feed custom implementations of `printf` like functions with additional type format strings.

There are libraries like [libfmt](https://github.com/fmtlib/fmt) out there, which provide rich formatting capabilities.
However, all such libraries add additional runtime overhead to the resulting program.

## Compilation Performance

Heavy template meta-programs tend to be slow.
I invested a lot of time in measuring different type list implementations, in order to make this `printf` frontend *fast*.

In another blog article, I [measured the performance of type lists]({% post_url 2016-06-25-cpp_template_type_list_performance %}) using variadic template parameters, and recursive type lists.
This library builds on the faster list implementation.

The resulting compile time overhead is *rarely* in measurable timing regions, which makes it useful for real life projects.

## Summary

I wrapped the code into a repository called `pprintpp` and published it on GitHub under the MIT license.
([Link to the repository](https://github.com/tfc/pprintpp))

This library is in production use for some time now and helped get rid of a lot of typos and variable-type accidents while being very comfortable at the same time.

I'd be happy to hear that it is useful to others outside of my projects, too!
