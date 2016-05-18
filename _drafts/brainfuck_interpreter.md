---
layout: post
title: Executing Brainfuck at Compile Time with C++ Templates
---

This article completes a series which aims to explain how to implement a **Brainfuck Interpreter**, which runs at **compile time**, because it is a template meta program.

> The code in this article depends largely on the code in [the article about type lists]({% post_url 2016-05-08-compile_time_type_lists %}), and [the article about character type list transformations]({% post_url 2016-05-14-converting_between_c_strings_and_type_lists %}), and [the article about implementing a turing tape in template language]({% post_url 2016-05-15-turing_tape_with_type_lists %}). 
> There is also [the article about template meta programming 101 things]({% post_url 2016-05-05-template_meta_programming_basics %}).

## Adapting the Turing Tape

{% highlight c++ linenos %}
template <class Tape>
struct null_to_0;

template <class LList, class RList>
struct null_to_0<tape<LList, null_t, RList>> {
    using type = tape<LList, char_t<0>, RList>;
};

template <class Tape> struct null_to_0 { using type = Tape; };

template <class Tape> using null_to_0_t = 
                               typename null_to_0<Tape>::type;
{% endhighlight %}

## The Brainfuck Machine State

{% highlight c++ linenos %}
template <typename Tape>
struct machine {
    using move_left  = machine<null_to_0_t<
                                     tt_move_left_t< Tape>>>;
    using move_right = machine<null_to_0_t<
                                     tt_move_right_t<Tape>>>;

    using get = tt_get_t<Tape>;
    template <char value>
    using set = machine<tt_set_t<Tape, char_t<value>>>;

    static const constexpr char value {get::value};

    using increment = machine<tt_set_t<Tape, char_t<value + 1>>>;
    using decrement = machine<tt_set_t<Tape, char_t<value - 1>>>;
};
{% endhighlight %}

{% highlight c++ %}
template <typename Machine>
using move_left_t = typename Machine::move_left;
template <typename Machine>
using move_right_t = typename Machine::move_right;

template <typename Machine>
using get_t = typename Machine::get;
template <typename Machine, char val>
using set_t = typename Machine::template set<val>;

template <typename Machine>
using increment_t = typename Machine::increment;
template <typename Machine>
using decrement_t = typename Machine::decrement;

using make_t = machine<tt_make_t<char_t<0>>>;
{% endhighlight %}

## The Brainfuck plus IO Bundle

{% highlight c++ linenos %}
template <class BFM, class Inlist, class OutList>
struct io_bfm {
    using output = OutList;
    using state  = BFM;
};
{% endhighlight %}

## Interpreting Brainfuck Code

{% highlight c++ linenos %}
template <class IOBFM, char InputChar>
struct interpret_step;

template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '.'> {
    using type = io_bfm<BFM, 
                       InList, 
                       append_t<OutList, get_t<BFM>>>;
};
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, ','> {
    using type = io_bfm<set_t<BFM, head_t<InList>::value>, 
                        tail_t<InList>, 
                        OutList>;
};
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '+'> {
    using type = io_bfm<increment_t<BFM>,
                        InList, 
                        OutList>;
};
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '-'> {
    using type = io_bfm<decrement_t<BFM>, 
                        InList, 
                        OutList>;
};
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '<'> {
    using type = io_bfm<move_left_t<BFM>, 
                        InList, 
                        OutList>;
};
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '>'> {
    using type = io_bfm<move_right_t<BFM>, 
                        InList, 
                        OutList>;
};
template <class IOBFM, char InputChar>
using interpret_step_t = 
          typename interpret_step<IOBFM, InputChar>::type;
{% endhighlight %}


{% highlight c++ linenos %}
template <class IOBFM, class ProgList>
struct run_tm;
template <class IOBFM, class RestProg>
struct run_tm<IOBFM, ::tl::tl<::char_t<'['>, RestProg>> {
    static const constexpr bool loop_terminated {
                 get_t<typename IOBFM::state>::value == 0};

    using blocks = find_brace<RestProg, null_t, 1>;
    using type = typename if_else_t<loop_terminated,
        run_tm<IOBFM, typename blocks::rest_prog>,
        run_tm<
            typename run_tm<IOBFM, 
                            typename blocks::brace_block
                      >::type,
            ::tl::tl<::char_t<'['>, RestProg>>
    >::type;
};
template <class IOBFM, char Command, class RestProg>
struct run_tm<IOBFM, ::tl::tl<::char_t<Command>, RestProg>> {
    using type = typename run_tm<
                      interpret_step_t<IOBFM, Command>, 
                      RestProg
                 >::type;
};
template <class IOBFM>
struct run_tm<IOBFM, ::tl::null_t> {
    using type = IOBFM;
};

template <class IOBFM, class ProgList>
using run_tm_t = typename run_tm<IOBFM, ProgList>::type;
{% endhighlight %}

{% highlight c++ linenos %}
template <class InList, class OutList, size_t Counter>
struct find_brace;

template <class InList, class OutList>
struct find_brace<tl<char_t<']'>, InList>, 
                  OutList, 
                  1> {
    using brace_block = OutList;
    using rest_prog   = InList;
};

template <class InList, class OutList, size_t N>
struct find_brace<tl<char_t<']'>, InList>, 
                  OutList, 
                  N>
    : public find_brace<InList, 
                       append_t<OutList, char_t<']'>>, 
                       N - 1>
{};

template <class InList, class OutList, size_t N>
struct find_brace<tl<char_t<'['>, InList>, 
                  OutList, 
                  N>
    : public find_brace<InList, 
                        append_t<OutList, char_t<'['>>, 
                        N + 1>
{};

template <char C, class InList, class OutList, size_t N>
struct find_brace<tl<char_t<C>, InList>, 
                  OutList, 
                  N>
    : public find_brace<InList, 
                        append_t<OutList, char_t<C>>,
                        N>
{};
{% endhighlight %}

