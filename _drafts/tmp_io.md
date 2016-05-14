---
layout: post
title: Transformations between User Input/Output and Type Lists
---

Type lists are an important way to represent ordered and unordered sets of types at compile time.
These types can be real structure or class types representing encapsulated algorithms etc., but they can also convoy actual data.
In order to apply certain compile time processing to data, this data needs to be transformed from and to representations which are useful for the programmer.
This article shows how to transform hence and forth between strings and character type lists.

At first, a type is needed which contains one actual character.
Using that type, it is possible to compose type lists, which carry whole strings.

{% highlight c++ %}
template <char val> 
struct char_t { 
    static const constexpr char value {val};
};
{% endhighlight %}

`char_t`'s only template parameter is an actual character. 
To carry the character 'a', one just instanciates it like this: `char_t<'a'>`.
The character can now be accessed via the `value` member of the structure type, both at compile- and at run time:

{% highlight c++ %}
// Define the character 'a' carrying type
using my_char = char_t<'a'>;

// Accessing my_char's payload character at compile time
using next_char = char_t<my_char::value + 1>;

int f()
{
    // Accessing it at run time
    std::cout << my_char::value << std::endl;
}
{% endhighlight %}

Using type lists, these can now easily be chained together, using the `make_t` helper from the previous article:

{% highlight c++ %}
using my_abc_string = make_t<char_t<'a'>, char_t<'b'>, char_t<'c'>>;
{% endhighlight %}

Although `make_t`'s purpose is to make type list creation less clumsy, this does not look optimal.

{% highlight c++ linenos %}
template <char c, char ... chars>
struct char_tl;

template <char c, char ... chars>
struct char_tl {
    using type = tl::tl<char_t<c>, 
                        typename char_tl<chars...>::type>;
};

template <char c>
struct char_tl<c> {
    using type = tl::tl<char_t<c>, tl::null_t>;
};

template <char ... chars>
using char_tl_t = typename char_tl<chars...>::type;
{% endhighlight %}

- **line 2** defines the general type signature of a variadic type list template type
- **line 5** describes the recursion which is applied in order to *unroll* the variadic type list into a type list. It *wraps* each individual character into a `char_t` type. This new `char_t` type is then again wrapped as the head element in a new type list, and its tail is the next recursion step.
- **line 11** Defines the recursion aborting step by just wrapping the last character into a type list which is terminated just right afterwards.
- **line 16** is a convenient helper type alias.

Character type lists can now be instantiated like this:

{% highlight c++ %}
using my_abc_string = char_tl_t<'a', 'b', 'c'>;
{% endhighlight %}

This is already a significant improvement over what we had before.
Pretty nice, but the ***real** optimum* would be a transformation from an actual C-string in the form `"abc"` to a type list.

Of course, that is also possible:

{% highlight c++ linenos %}
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
{% endhighlight %}

 - **line 2** Declares our function which takes a string provider, a position index, and the character at the current position. The user will later only provide the string provider, and the position index as well as the character are internally used and provided parameters.

Before continuing with the following lines of code: **What** is a *string provider?*

A string, or a string pointer cannot just be used as template parameters directly.
Therefore a type is needed which carries a string as payload and provides static access to it:

{% highlight c++ %}
struct my_string_provider {
   static constexpr const char * str() {
       return "foo bar string";
   }
};
{% endhighlight %}

Unfortunately, strings must be wrapped into a structure like this, in order to process them in a template meta program.

 - **line 5** defines the recursion which advances through the string step by step, while appending earch character to the result type list. This is basically the same like in the example where we used variadic character type lists, but some more mechanics are needed to process the string provider.
 - **line 15** defines the recursion abort step. As soon as we trip on the zero character which terminates the string, we also terminate the list.
 - **line 20** is the easy-to-use wrapper which is meant to be used by the user. It takes a single string provider parameter and extracts any other needed parameter from it.

{% highlight c++ %}
struct abc_string_provider {
   static constexpr const char * str() {
       return "abc";
   }
};

using my_abc_string = string_list_t<abc_string_provider>;
{% endhighlight %}

This is as easy as it gets.
Having to define a string provider around every simple string is still a lot of scaffolding, but this is still the only reasonable way to convert long C-strings into type lists.
