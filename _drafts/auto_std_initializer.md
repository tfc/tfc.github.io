---
layout: post
title: Don't Mix auto and Curly Braces
---

The `auto` variable type is pretty neat, when initializing variables from functions or factories, because one does not have to retype type of the variable again.
However, there are some pitfalls, as this article shows.

# First Things First: `auto`

`auto` is an *automatic* variable type, which can deduce of what type a variable shall be.

Example:
{% highlight c++ %}
std::shared_ptr<Object> shared_object = std::make_shared<Object>();

std::vector<int>::iterator it = int_vector.begin();

// Much better to read, and less typing:
auto shared_obj = std::make_shared<Object>();

auto it = int_vector.begin();
{% endhighlight %}

Often, new variables are just initialized from the return value of some function, and that function already suggests, what type it is returning.
In such cases, there's not much sense in having to express exactly that type again, especially because the compiler can deduce it.

For some types, it is even not *possible*, to express the type: Lambdas:

{% highlight c++ %}
// The following one is easy: int (*)(int),
// because a closure not capturing anything
// is simply an oldschool function.
auto func = [] (int a) { return 2 * a; }

int x = 123;
// The type of this closure cannot be expressed,
// so we can't do anything else than use auto as its type
auto func2 = [x] (int a) { return a + x; }
{% endhighlight %}

It is possible that some people will now ask: "Wait, isn't the latter closure just an `std::function<int(int)>`?"

No. It isn't.
It is possible to write

{% highlight c++ %}
int x = 123;
std::function<int(int)> func2 = [x] (int a) { return a + x; }
{% endhighlight %}

but this line contains some non-obvious magic: The class `std::function<...>` can save closures, but it is a polymorphic class which is _not_ identical to the closures which it can hold.
Our example line of code actually uses the implicit conversion constructor of `std::function`, which creates a completely new object from the closure.
This can have performance implications, because calling this closure will then involve a virtual function table lookup.
Furthermore, the memory backing of `std::function` will even be on the *heap*, if the closure is larger than a specific threshold.

However, this misunderstanding will most probably not lead to misbehaviour of programs, although it could be considered a little pitfall.

# Pitfalls

One very typical pitfall can come from `std::vector<bool>`.
When initializing an auto variable from a vector item, this looks like

{% highlight c++ %}
auto item = some_vector[123];
// do something with "item"
{% endhighlight %}

This is completely fine. But another pretty similar line of code will silently lead to undefined behaviour, leaving the compiler no chance to warn about this:

{% highlight c++ %}
// Assuming std::vector<bool> is the returned type
auto tenth_bit = get_temporary_bit_vector()[9];

if (tenth_bit) {
    // do something 
}
{% endhighlight %}

The function `get_temporary_bit_vector()` returns some vector, filled with bits.
The lifetime of this vector is reduced to this line.
This looks fine, because we just need it to access the bit at index `9`, and initialize our variable with it.
The inexperienced programmer will assume, that the `auto` type is deduced to `bool`, and the variable will then have a value of `true` or `false`.

When running this code, one might experience pretty random (undefined) behaviour.
Why is that? Because the type of `tenth_bit` is not `bool` at all!
How can we check that?
There is a nice little trick using templates:

{% highlight c++ %}
template <typename T> class debug_t; // No _definition_ here
{% endhighlight %}

using this class, we can provoke a compiler error by trying to instanciate an object of type `debug_t` with some type as its template parameter.
The compiler will not like that, error-out and print what it doesn't like, as usual.
We can put this error to use:

{% highlight c++ %}
auto tenth_bit = get_temporary_bit_vector()[9];

debug_t<decltype(tenth_bit)> d;
{% endhighlight %}

Compiling this yields the following information:

{% highlight bash %}
[tfc@jongebook example_std_vector_temp_fail] $ clang++ -o main main.cpp -std=c++11
main.cpp:15:28: error: implicit instantiation of undefined template
      'debug_t<const std::_Bit_reference>'
    debug_t<decltype(tmp)> d;
                           ^
main.cpp:9:29: note: template is declared here
template <typename T> class debug_t;
                            ^
1 error generated.
{% endhighlight %}

Ok, so the type is `std::_Bit_reference`.
That object is a *proxy object*, which contains either a pointer or a reference to the `bool` value, which we wanted to obtain.
This object mimics a `bool` *reference* for us, as it is not possible to hold a pointer to an individual bit on most processor architectures. (It is only possible to address bytes, words, etc. on the typical processor architectures)
Unfortunately, the actual array which the temporary `std::vector<bool>` copy contained, is gone, and so the reference or pointer from within the proxy object is *dangling*.
Debugging this would have been painful, because the boolean value would appear to have crazily flipping values, or the program would just crash.

This is by no means an error of the `auto` keyword or automatic type deduction in general, as this would also have happened, if we wrote the type of the variable ourselves.
But in that case, the error would have been more obvious.

# Curly Braces

As of C++11, the following lines are (*nearly*! Details following) equivalent:

{% highlight c++ %}
SomeClass x = 123;
SomeClass y  (123);
SomeClass z  {123};
{% endhighlight %}

All these lines assume, that `SomeClass` has a constructor which accepts an integer, and construct objects with just that constructor.
The last line, which uses curly braces `{}`, is only possible with the C++11 standard and newer.
The `{}` operator will select an exactly matching constructor.
If there are any constructors which are "*similar*", but only match after some type conversion, that operator will refuse compiling.
The line `int x {123.0};` for example will not compile, while `int x (123.0)` does compile.

I like initializing objects this way, in contrast to using `=`, because this makes initializing objects very explicit.
When reading code where objects are never initialized with `=`, the assignment only occurs on lines where objects are **re**assigned.

However, there is another pitfall which one should always have in mind when using the curly braces `{}`:

Since curly braces were also introduced to construct container objects like vectors and lists with ranges of values, the following is now possible with C++11:

{% highlight c++ %}
std::vector<int> vector {1, 2, 3, 4, 5};

// Vector contains 5 items from the beginning on.
{% endhighlight %}

> When i said earlier that those 3 example lines are *nearly* equivalent, i meant that they are indeed not equivalent, if the type `SomeClass` has an `std::initializer_list` constructor. (Like `std::vector` has)
> In such cases, the `std::initializer_list` constructor would be chosen, even if there is a constructor `SomeClass(int)`, which would be a better match.
> The curly braces `{}` are very greedily choosing `std::initializer_list` constructors, if there is one.
> They would even implicitly convert types just to match the existing `std::initializer_list` constructor.
> I don't really like this. In my opinion, initializer list constructors should look different from other constructors to avoid this pitfall.
> More on this in the next section.

This is all fine and nice, until someone starts using curly braces in combination with `auto`:

# Curly Braces and `auto`

`auto` and curly braces do not mix well, because curly braces are a two-fold feature:
They do not only embody an *exact-constructor-match-or-refuse* operator, but also a greedy *form-an-initializer-list* operator.
That means, that this operator will forcefully create an `std::initializer_list<T>` object from whatever it is fed with, if the object which it shall construct, contains any constructor which accepts such an initializer list type.

If the type of the object which shall be constructed is not defined, yet, because the programmer wrote `auto` as its type, then the compiler will for sure select `std::initializer_list<T>` as its type, and that is seldomly what the programmer had in mind.

{% highlight c++ %}
auto some_character_string {"This is some character string"};

std::cout << some_character_string << std::endl;
{% endhighlight %}

Compiling this with GCC (`version 6.1.1 20160621 (Red Hat 6.1.1-3)`) and Clang (`version 3.8.0 (tags/RELEASE_380/final)`) works great, and imposes no problems.
The following output with the `debug_t` type printing trick shows that the type is correctly deduced to `const char * const`:

{% highlight bash %}

[tfc@jongebook example_std_vector_temp_fail] $ clang++ -o main main.cpp -std=c++11
main.cpp:17:28: error: implicit instantiation of undefined template 'debug_t<const char *const>'
    debug_t<decltype(some_character_string)> d;
                           ^
main.cpp:9:29: note: template is declared here
template <typename T> class debug_t;
                            ^
1 error generated.

[tfc@jongebook example_std_vector_temp_fail] $ g++ -o main main.cpp -std=c++11
main.cpp: In function ‘int main()’:
main.cpp:17:28: error: aggregate ‘debug_t<const char* const> d’ has incomplete type and cannot be defined
     debug_t<decltype(some_character_string)> d;
{% endhighlight %}

So what's the problem?
Some compilers, like MinGW (*TODO: Boot Windows and provide mingw-g++ compiler version number, and provide compiler error msg*), will correctly deduce the type `std::initializer_list<const char *const>`, which is not what we wanted in this case.

So this mostly works, which is why some programmers get used to this style, but some compilers will complain.
This is something which will change with the C++17 standard.
Until then, `auto` is better used with parentheses `()` or `=` for initialization:

{% highlight c++ %}
auto x = 123;  // x is an int
auto y  (123); // y is an int
auto z  {123}; // z is an std::initializer_list<int> on some compilers
{% endhighlight %}

I got into this situation multiple times, because i had the habit of initializing `auto` variables with curly braces, and developed an application with the Qt framework on Linux/OS X, but then compiled on Windows, where the MinGW compiler complained.

Some static analysis tools do also complain (Synopsis Coverity, which uses the EDG C++ compiler frontend).
