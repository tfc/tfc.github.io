---
title: Transformations between User Input/Output and Type Lists
tags: c++, meta-programming
---

<!-- cSpell:disable -->

Type lists are an important way to represent ordered and unordered sets of types at compile time.
These types can be real structure- or class types bundling runtime algorithms etc., but they can also convey actual data at compile time.
In order to apply certain compile time processing to data, this data needs to be transformed from and to other representations, which can be provided by the programmer and consumed by run time programs.
This article shows how to transform back and forth between strings and character type lists.

<!--more-->

## Wrapping characters into Type Lists

At first, a type is needed which can carry one actual character, without having to instantiate it.
This is the requirement for all value-carrying types in order to be able to use them at compile time.
Using that type, it is possible to compose character type lists, which carry whole strings.

``` cpp
template <char val>
struct char_t {
    static const constexpr char value {val};
};
```

`char_t`'s only template parameter is an actual character.
To carry the character 'a', one just instanciates it like this: `char_t<'a'>`.
The character can now be accessed via the `value` member of the structure type, both at compile- and at run time:

``` cpp
// Define the character 'a' carrying type
using my_char = char_t<'a'>;

// Accessing my_char's payload character at compile time
using next_char = char_t<my_char::value + 1>;

int f()
{
    // Accessing it at run time
    std::cout << my_char::value << '\n';
}
```

This type is now fundamental to character type lists.

## Converting from Strings to Type Lists

Using type lists, these can now easily be chained together, using the `make_t` helper from the previous article.
(Link to [the article which explains how to create type lists](/2016/05/08/compile_time_type_lists))

``` cpp
using my_abc_string = make_t<char_t<'a'>, char_t<'b'>, char_t<'c'>>;
```

Although `make_t`'s purpose is to make type list creation less clumsy, this does not look optimal.

``` {.cpp .numberLines }
template <char c, char ... chars>
struct char_tl;

template <char c, char ... chars>
struct char_tl {
    using type = tl::tl<
                    char_t<c>,
                    typename char_tl<chars...>::type
                 >;
};

template <char c>
struct char_tl<c> {
    using type = tl::tl<char_t<c>, tl::null_t>;
};

template <char ... chars>
using char_tl_t = typename char_tl<chars...>::type;
```
<br>

- **line 2** defines the general type signature of the conversion function `char_tl` which accepts a variadic character list
- **line 5** describes the recursion which is applied in order to *unroll* the variadic type list into a type list. It *wraps* each individual character into a `char_t` type. This new `char_t` type is then again wrapped as the head element into a new type list, and its tail is the next recursion step.
- **line 11** defines the recursion abort step by just wrapping the last character into a type list which is terminated just right afterwards.
- **line 16** is a convenient helper type alias.

Character type lists can now be instantiated like this:

``` cpp
using my_abc_string = char_tl_t<'a', 'b', 'c'>;
```

This is already a significant improvement over what we had before.
Pretty nice, but the ***real** optimum* would be a transformation from an actual C-string in the form `"abc"` to a type list.

Of course, that is also possible:

``` {.cpp .numberLines }
template <class Str, size_t Pos, char C>
struct string_list;

template <class Str, size_t Pos, char C>
struct string_list {
    using next_piece = typename string_list<
                            Str,
                            Pos + 1,
                            Str::str()[Pos + 1]
                        >::type;
    using type = tl::tl<char_t<C>, next_piece>;
};

template <class Str, size_t Pos>
struct string_list<Str, Pos, '\0'> {
    using type = tl::null_t;
};

template <class Str>
using string_list_t = typename string_list<
                          Str,
                          0,
                          Str::str()[0]
                      >::type;
```
<br>

 - **line 2** Declares our function which takes a string provider, a position index, and the character at the current position. The user will later only provide the string provider. The position index as well as the character are for internal use. `string_list_t` adds them automatically (line 20).

Before continuing with the following lines of code: **What** is a *string provider?*

A string, or a string pointer, cannot just be used as template parameters directly.
Therefore a type carrying a string as payload and provides static access to it is needed:

``` cpp
struct my_string_provider {
   static constexpr const char * str() {
       return "foo bar string";
   }
};
```

This type can now be used as a template parameter by template classes, and the template code can access its static string member.
Because of this additional, but necessary, indirection it is called a *string provider*.

 - **line 5** defines the recursion which advances through the string step by step, while appending each character to the result type list. This is basically the same as in the example where we used variadic character type lists, but some more mechanics are needed to iterate the string provider.
 - **line 15** defines the recursion abort step. As soon as we trip on the zero character which terminates the string, we also terminate the list.
 - **line 20** is the easy-to-use wrapper which is meant to be used by the user. It takes a single string provider parameter and extracts any other needed parameter from it.

``` cpp
struct abc_string_provider {
   static constexpr const char * str() {
       return "abc";
   }
};

using my_abc_string = string_list_t<abc_string_provider>;
```

This is as easy as it gets.
Having to define a string provider around every simple string is still a lot of scaffolding, but this is still the only reasonable way to convert long C-strings into type lists.

## Converting from Type Lists to C-Strings

Imagine a type list with character payload as the result after the execution of some meta programming algorithm.

In some cases the wanted output form is a C-string.
This is the exact reverse operation from what we just implemented before.

The generic idea is to convert a type list to a variadic character template parameter list.
That variadic list can be used to initialize a character array, which can then be provided to the user:

``` {.cpp .numberLines }
template <typename typelist, char ... chars>
struct tl_to_vl;

template <char c, typename restlist, char ... chars>
struct tl_to_vl<tl::tl<char_t<c>, restlist>, chars...>
    : public tl_to_vl<restlist, chars..., c>
{ };

template <char ... chars>
struct tl_to_vl<tl::null_t, chars...> {
    static const char * const str() {
        static constexpr char ret[] {chars..., '\0'};
        return ret;
    }
}
```
<br>

 - **line 2** defines the general function signature: It takes a character type list as first parameter, and then a variadic list of characters.
 - **line 5** defines the recursion: The idea is to let the type list shrink stepwise, while the character, which is taken from it, is appended to the variadic character list.
 - **line 10** is the recursion abort step. At this point, the type list is empty and the variadic character list contains the whole string. Having the whole string in the `chars...` template variable, we can define the static function `str()` which defines a static character array and returns it.

This code example is different than the others before, because it relies on inheritance.
It would have been possible to implement the others with inheritance, too, or implement this one defining local `type` type variables etc., but i found this form to be the shortest and most useful one, while still being nicely readable.

By instanciating `tl_to_vl<some_type_list>`, a chain of inheriting classes is unrolled, and the last base class, which is the recursion abort type from line 10, defines the static `str()` function.
Because every member of a `struct` is public by default, the actually instantiated *outer* type `tl_to_vl<some_type_list>` also provides this function, which is directly callable.

Example of how to print a type list on the terminal, after converting it into a C-String:

``` cpp
struct abc_string_provider {
   static constexpr const char * str() {
       return "abc";
   }
};

using my_abc_string = string_list_t<abc_string_provider>;

using string_provider = tl_to_vl<my_abc_string>;

int f() {
    puts(string_provider::str());
}
```

When compiling code like this, the assembly code will still result in a function call of `str()`, which returns a pointer to the C-string, and then a call of `puts`.

Compiling the code *without* any optimization (clang++ [clang-703.0.29]):

``` asm
_main:
pushq   %rbp
movq    %rsp, %rbp
subq    $0x10, %rsp
movl    $0x0, -0x4(%rbp)

# The following line contains the function call string_provider::str()
callq   __ZN13tl_to_varlistIN2tl6null_tEJLc72ELc101ELc108ELc108ELc111ELc32ELc87ELc111ELc114ELc108ELc100ELc33ELc10ELc13EEE3strEv ## tl_to_varlist<tl::null_t, (char)72, (char)101, (char)108, (char)108, (char)111, (char)32, (char)87, (char)111, (char)114, (char)108, (char)100, (char)33, (char)10, (char)13>::str()
movq    %rax, %rdi

# This is the call of the puts() procedure
callq   0x100000f7e     ## symbol stub for: _puts
xorl    %ecx, %ecx
movl    %eax, -0x8(%rbp)
movl    %ecx, %eax
addq    $0x10, %rsp
popq    %rbp
retq
```

Compiling the code *with* `-O1` or `-O2` optimization (clang++):

``` asm
_main:
pushq %rbp
movq  %rsp, %rbp
movq  0x85(%rip), %rdi   ## literal pool symbol address: __ZZN13tl_to_varlistIN2tl6null_tEJLc72ELc101ELc108ELc108ELc111ELc32ELc87ELc111ELc114ELc108ELc100ELc33ELc10ELc13EEE3strEvE6string
callq 0x100000f84        ## symbol stub for: _puts
xorl  %eax, %eax
popq  %rbp
retq
```

The disassembly shows that the string is just read out of the binary, where it is available without any processing.
It is pretty nice to see that there is *no trace* of any meta programming code in the binary.
Apart from those strange and long symbol names, everything looks as if the string was hard coded into the binary by hand to its resulting form.

The next article will deal with template meta programs which transform character type lists in order to do useful things with them.
