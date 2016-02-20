---
layout: post
title: Useful type traits with if_compiles semantics
---


## Inline HTML elements

HTML defines a long list of available inline tags, a complete list of which can be found on the [Mozilla Developer Network](https://developer.mozilla.org/en-US/docs/Web/HTML/Element).

- **To bold text**, use `<strong>`.
- *To italicize text*, use `<em>`.
- Abbreviations, like <abbr title="HyperText Markup Langage">HTML</abbr> should use `<abbr>`, with an optional `title` attribute for the full phrase.
- Citations, like <cite>&mdash; Mark otto</cite>, should use `<cite>`.
- <del>Deleted</del> text should use `<del>` and <ins>inserted</ins> text should use `<ins>`.
- Superscript <sup>text</sup> uses `<sup>` and subscript <sub>text</sub> uses `<sub>`.

### Code

Cum sociis natoque penatibus et magnis dis `code element` montes, nascetur ridiculus mus.

{% highlight c++ %}
#define DEFINE_IF_COMPILES(NAME, EXPR) \
    template <typename U1> \
    struct NAME \
    { \
        template <typename U> static U& makeU(); \
        using yes_t = char; \
        using no_t  = char[2]; \
        \
        template <typename T1> \
        static yes_t& f1(T1 &x1, char (*a)[sizeof( EXPR )] = nullptr); \
        template <typename T1> \
        static no_t&  f1(...); \
        \
        static constexpr const bool value { \
            sizeof(NAME::f1<U1>(NAME::makeU<U1>())) == sizeof(NAME::yes_t)}; \
    }

DEFINE_IF_COMPILES(is_dereferenceable, *x1);

static_assert(is_dereferenceable<int*                 >::value == true, "foo");
static_assert(is_dereferenceable<int                  >::value == false, "bar");
static_assert(is_dereferenceable<vector<int>::iterator>::value == true, "foo");
{% endhighlight %}
-----
<dl>
  <dt>HyperText Markup Language (HTML)</dt>
  <dd>The language used to describe and define the content of a Web page</dd>

  <dt>Cascading Style Sheets (CSS)</dt>
  <dd>Used to describe the appearance of Web content</dd>

  <dt>JavaScript (JS)</dt>
  <dd>The programming language used to build advanced Web sites and applications</dd>
</dl>

Integer posuere erat a ante venenatis dapibus posuere velit aliquet. Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Nullam quis risus eget urna mollis ornare vel eu leo.

-----
