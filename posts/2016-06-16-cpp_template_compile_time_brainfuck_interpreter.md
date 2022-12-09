---
title: Executing Brainfuck at Compile Time with C++ Templates
tags: c++, meta-programming
---

<!-- cSpell:disable -->

This article completes a series which aims at explaining how to implement a Brainfuck Interpreter as a template meta-program which runs at compile time.

<!--more-->

> The code in this article depends largely on the code in [the article about type lists](/2016/05/08/compile_time_type_lists), [the article about character type list transformations](/2016/05/14/converting_between_c_strings_and_type_lists), and [the article about implementing a Turing tape](/2016/05/15/turing_tape_with_type_lists).
> There is also [the article about template meta-programming 101 things](/2016/05/05/template_meta_programming_basics).

## First Things First: What is Brainfuck?

Brainfuck is a fun programming language and was created in 1993 by Urban Müller. [Wikipedia Link](https://en.wikipedia.org/wiki/Brainfuck)

Brainfuck programs are composed of only 8 operators and assume to operate on a *Brainfuck Machine*.
A Brainfuck machine looks like a Turing machine: It has a cursor which sits on a tape consisting of infinitely many memory cells.

|Operator|Meaning|
|:------:|---------------------------------------------------------|
|`+`|Increment the value of the memory cell at tape cursor position|
|`-`|Increment the value of the memory cell at tape cursor position|
|`<`|Move the tape cursor one cell further to the left|
|`>`|Move the tape cursor one cell further to the right|
|`.`|Print the value at tape cursor position|
|`,`|Read a value, and assign it to the memory cell at tape cursor position|
|`[`|Beginning of a loop. Execute it, if the tape cursor value is not 0. Skip the whole loop, if it is 0.|
|`]`|End of a loop. Move program cursor to beginning of the loop.|

Any other character in a brainfuck program is ignored (spaces can be used for nicer to read indentation etc.)

### Examples:

#### Simple Print Loop

The following program reads a value from the user input, then prints and decrements it in a loop:

`,[.-]`

*Output*: (Assuming the user enters the character `z`)

```
zyxwvutsrqponmlkjihgfedcba`_^]\[ZYXWVUTSRQPONMLKJIHGFEDCBA@?>=<;:9876543210/.-,+*)('&%$#"!
```

#### Hello World

The following program reads a value from the user, then prints and decrements it in a loop:

```
++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.+++.
```

*Output*:

```
Hello World!
```

## Implementation in C++ Template Meta Language

Ok, let us implement that.
We will start with adapting the [Turing Tape](/2016/05/15/turing_tape_with_type_lists) from the previous article in order to represent the state of a Brainfuck Machine.

## Adapting the Turing Tape

The state of a Turing machine is based on the Turing tape it works on.
We have implemented such a tape before, but need to add a little adaption:

When the tape is switched left or right, and a new cell is created which we did not read/write before, a new empty one is created.
How an *empty* cell looks like, is not really defined, as it just contains a `null_t` type.
There is no proper rule to which value a *formerly untouched* brainfuck cell shall be initialized.
I decided to initialize such cells to the value `0`.

``` {.cpp .numberLines }
template <class Tape>
struct null_to_0;

template <class LList, class RList>
struct null_to_0<tape<LList, null_t, RList>> {
    using type = tape<LList, char_t<0>, RList>;
};

template <class Tape> struct null_to_0 { using type = Tape; };

template <class Tape> using null_to_0_t =
                               typename null_to_0<Tape>::type;
```

Instead of subclassing the Turing tape or similar, we will just use the function `null_to_0_t`, which transforms empty cell elements to `0` elements, and leaves others untouched.
Whenever the list is altered for moving, this function is applied to it, and then this is set as the new list state.

## The Brainfuck Machine State

A Turing machine tape is enough to represent the state of the whole brainfuck machine.
We define a type `machine`, which carries a tape state as template parameter, and provides functions to read and alter the state.
This way the user does not need to know about any implementation details:

``` {.cpp .numberLines }
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

    using increment = set<value + 1>;
    using decrement = set<value - 1>;
};
```
<br>

| Function Name | What It Does |
|:-------------:|----------------------------------------------|
`move_left` / `move_right` | Moves the tape one step to the left/right, and returns a new `machine` type with the altered state. If it reaches the end of the tape while moving, it appends a new cell. This new cell is then initialized to `0`.
`get` | Returns the type at cursor position.
`set<value>` | Returns a new `machine` type with altered tape state. The tape is altered in that way, that it contains the new character `value` at cursor position.
`increment` / `decrement` | Increments/decrements the value at cursor position and returns a new `machine` which contains this change.

The following code only adds a wrapper for every single function we just defined. This is to make the user code shorter:

``` cpp
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
```

Note the additional helper `make_t`, which just returns a fresh initialized brainfuck machine.

## The Brainfuck Machine plus IO Bundle

By now, we have a specialized Turing tape, or let's say *Brainfuck Machine Tape*, which can in principle perform the operations `+`, `-`, `<`, `>`, `.`, and `,`.
The functions providing these operations, return a new Brainfuck Machine Tape.
This is enough to represent a single naked Brainfuck Machine.

However, we still have to feed it with commands by hand.
Some example lines show how to do that:

``` cpp
using empty_bfm    = make_t;

using a_bfm        = set_t<empty_bfm, 'a'>;

using b_bfm        = increment_t<a_bfm>;

using shifted_left = move_left_t<b_bfm>;

using bc_bfm       = set_t<shifted_left, 'c'>;

// Or in just one line:
using bc_bfm_state = set_t<move_left_t<increment_t<set_t<make_t, 'a'> > >, 'c'>;
```

What we want it to do: It shall automatically interpret a brainfuck script.

In order to implement that, we will couple a brainfuck machine together with input and output.

The input is a type list, which contains all characters which the user *will* enter.
Usually, brainfuck interpreters ask for input values, when they step on a `,` operator, but as soon as the C++ compiler is running, we cannot ask for input any longer.
Therefore the user character input must be defined as an input list *before* the compiler is started.

The output is also a type list.
Before executing the brainfuck program, it is empty.
After executing the program it is hopefully filled with meaningful output.

Operators can change any sub state in the state tuple `(BFM state, input, output)`.
We will push around this bundle throughout the whole brainfuck program and alter it step by step.
The output list will grow, while the program is executed (assuming it outputs something).
The input list will shrink, as characters are consumed (assuming it reads from input), one-by-one.

``` cpp
template <class BFM, class Inlist, class OutList>
struct io_bfm {
    using output = OutList;
    using state  = BFM;
};
```

Being a purely functional programming novice, i found the fact that the state is never a structure member, but a template parameter, most unusual.
Our I/O brainfuck machine bundle is represented by the tuple `(machine state, input program, output list)`, and these all are template parameters.
The member type `using` clauses of struct `io_bfm` are just comfortable *getters* to the machine state and the output.

This is now the main vehicle for representing the state of the brainfuck machine and the remaining brainfuck program, as well with its output.
The following code, which does the bulk of program interpretation, will stepwise renew this state by altering it in the right manner.

## Interpreting Brainfuck Code, the Simple Part

At first, we will implement a function which accepts an `io_bfm` state as its first parameter, and one brainfuck command.
Its result is the new state of the brainfuck machine, which results from applying that command.
Mapping brainfuck command character mnemonics to brainfuck machine state manipulating commands is simple for most commands:

| BF Command | Returns new `io_bfm` state with... |
|:----------:|--------------------------------------------|
`.`| ...no changes, but the new output list has the current cursor value appended to its end.
`,`| ...the current cell set to the first input character, the input list with the first character chopped off, and an unaltered output list.
`+`| ...the current cursor value incremented by one.
`-`| ...the current cursor value decremented by one.
`<`| ...the tape moved to the left.
`>`| ...the tape moved to the right.

This is the simple part.
The `[` and `]` commands which define loop structures are missing.
We will get at those just after the other command implementations:

``` {.cpp .numberLines }
template <class IOBFM, char InputChar>
struct interpret_step;

// '.' command
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '.'> {
    using type = io_bfm<BFM,
                       InList,
                       append_t<OutList, get_t<BFM>>>;
};

// ',' command
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, ','> {
    using type = io_bfm<set_t<BFM, head_t<InList>::value>,
                        tail_t<InList>,
                        OutList>;
};

// '+' command
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '+'> {
    using type = io_bfm<increment_t<BFM>,
                        InList,
                        OutList>;
};

// '-' command
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '-'> {
    using type = io_bfm<decrement_t<BFM>,
                        InList,
                        OutList>;
};

// '<' command
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '<'> {
    using type = io_bfm<move_left_t<BFM>,
                        InList,
                        OutList>;
};

// '>' command
template <class BFM, class InList, class OutList>
struct interpret_step<io_bfm<BFM, InList, OutList>, '>'> {
    using type = io_bfm<move_right_t<BFM>,
                        InList,
                        OutList>;
};
template <class IOBFM, char InputChar>
using interpret_step_t =
          typename interpret_step<IOBFM, InputChar>::type;
```

In this lengthy list of ugly definitions you will find no if-else control structures.
The function call flow is completely controlled by *pattern matching*.
It would have been possible to work with `if_else_t` functions, but pattern matching is great for cases like this one.
Every operator has its own function body, which nicely separates its semantics.

For each brainfuck command, there is one `struct interpret_step<io_bfm<BFM, InList, OutList>, XXX>` definition, where `XXX` is the command.
Each command then returns, what the table before just described.

## Interpreting Brainfuck Code, the Complicated Part (Loops)

Unfortunately, loops are not as simple as the other commands, because they do not lead to simple state changes.
Whenever the BFM trips on a `[` command, it will...

 1. Check if the value at cursor position is equal to 0.
 2. If it is **equal** to 0, then **advance** the whole program list to the *closing* `]` bracket.
 3. If it is **not equal** to 0, then execute the part of the program which ends with the closing `]` bracket, then rewind back the tape to the opening `[` bracket, and go to ***1.***

 In this description, the term '*the closing `]` bracket*'

 is already a high-level description of another problem:

 > Given the position of an opening `[` bracket in a BF program, find the matching closing `]` bracket.

### Implementing a Find-The-Closing-Bracket Function

Well, seems as if we need to do some homework first: Implement that *matching bracket finder*.

The general problem is that a brainfuck loop can contain multiple nested loops.

Examples:

- `+++[>+++[.-]<]`
- `+++[>+++[>+++[.-]<]<]`

Obviously, one cannot just choose the next closing `]` bracket, because that would be the closing bracket of a completely different loop.
Therefore we have to **count**, how many loop we have seen beginning (by counting `[` commands).

Solution:

Whenever we see an opening `[` bracket, we *increment* a bracket counter, and whenever we see a closing `]` bracket, we *decrement* it again.
Assuming we start at value `1`, because the first opening bracket denotes the beginning of the first loop.
The next closing `]` bracket we see, while the counter is back at value `1`, is then the right loop end.

``` bash
......[......[......[.....]....].....]......
      1      2      3     2    1     X

position X: Do not increment, but abort search. We found it.
```

Let's have a look at the C++ TMP implementation:

``` {.cpp .numberLines }
// Find the closing brace, assuming we have seen an opening
// one already.
//
// InList:  The BF Program list, one element _behind_ the
//          opening [ bracket.
// OutList: A list which will grow with discovering all
//          inside-loop characters. Should be empty on
//          the initial call.
//          inside-bracket loop part)
// Counter: the bracket counter, which should be 1 on
//          the initial call
template <class InList, class OutList, size_t Counter>
struct find_brace;

// Match: counter is 1, command is ']'
// This is the final closing bracket.
template <class InList, class OutList>
struct find_brace<tl<char_t<']'>, InList>,
                  OutList,
                  1> {
    // We're done. The user can now choose...

    // ...the inner-loop program part
    using brace_block = OutList;

    // ...the rest of the program behind the loop
    using rest_prog   = InList;
};

// Match: counter is != 1, command is ']'
template <class InList, class OutList, size_t N>
struct find_brace<tl<char_t<']'>, InList>,
                  OutList,
                  N>
    // Add character to outlist, decrement counter
    : public find_brace<InList,
                       append_t<OutList, char_t<']'>>,
                       N - 1>
{};

// Match: counter is != 1, command is '['
template <class InList, class OutList, size_t N>
struct find_brace<tl<char_t<'['>, InList>,
                  OutList,
                  N>
    // Add character to outlist, increment counter
    : public find_brace<InList,
                        append_t<OutList, char_t<'['>>,
                        N + 1>
{};

// Match: Any yet unmatched case
template <char C, class InList, class OutList, size_t N>
struct find_brace<tl<char_t<C>, InList>,
                  OutList,
                  N>
    // Add character to outlist
    : public find_brace<InList,
                        append_t<OutList, char_t<C>>,
                        N>
{};
```

Reading this function implementation it becomes apparent, that each implementation does not *return* some type, apart from the final case.
They do rather *inherit* from the next matching function structure.
I chose to do it this way, because this is a comfortable way to forward the altered `(in list, out list, counter)` states.
As the final case contains *two* return values (the inner-loop program part, and the rest of the program after the loop), these are reached back as public members of the initially called structure.

So if `A` inherits from `B`, and `B` inherits from `C`, and `C` defines some member type definitions, these are also available in `A`.
That is what is useful in this specific case, too.

### Back to the Loop Command Implementation

Ok, after having done the homework, we can finally implement the loop control code, maybe the most complicated part of this whole compile time brainfuck story.

The following code consists of two blocks:

1. The block which matches the *base* case (Line 336): one of the `+`, `-`, `.`, `,`, `<`, `>` commands. This is easy to handle, because we already implemented all that. For these cases, this block is just a wrapper which will apply all the BF program commands to the BFM, until the program runs empty.
2. The large, ugly block (Line 366), which is invoked whenever the current program's head character is an opening bracket `[`.

The second block is so complicated, because it contains the loop execution decision:

> If the cursor value is nonzero, execute the loop body, and then look at the beginning of the loop again, doing this decision again.
> If the cursor value is zero, skip the whole loop, and continue with the rest of the program.

In order to do that decision, the interpreter will:

1. Load the cursor value and set a variable `loop_terminated` to true, if this value is zero.
2. if `loop_terminated` is true, then `run_tm` is called again on the rest of the program which begins behind the loop.
3. if `loop_terminated` is false, then it will...
    - Take the IOBFM state, and run it on the loop body, as if it was the whole program.
    - Together with this state which resulted from a single loop operation, it is put on the same loop again

Armored with that workflow in your mind, have a look at the implementation:

``` {.cpp .numberLines }
// Execute a brainfuck machine, defined by its IO/BFM state
//
// IOBFM:    The initial I/O and BF machine pair.
// ProgList: The brainfuck program
template <class IOBFM, class ProgList>
struct run_tm;

// Matches: '[', Next BF command is the beginning of a loop
template <class IOBFM, class RestProg>
struct run_tm<IOBFM, ::tl::tl<::char_t<'['>, RestProg>> {
    // If the value at cursor position is zero: skip the loop
    static const constexpr bool loop_terminated {
                 get_t<typename IOBFM::state>::value == 0};

    // "blocks" gives us loop body and rest of the program
    // after the loop.
    using blocks = find_brace<RestProg, null_t, 1>;

    // If the loop is already terminated...
    using type = typename if_else_t<loop_terminated,
        // ...then run the rest of the program,
        //    which begins after the closing ']'
        run_tm<IOBFM, typename blocks::rest_prog>,

        // ...else, execute the BFM on the loop body,
        //    as if it was the whole program...
        run_tm<
            typename run_tm<IOBFM,
                            typename blocks::brace_block
                      >::type,
            // ...and then confront it with the
            //    same loop again.
            ::tl::tl<::char_t<'['>, RestProg>>
    >::type;
};

// Matches: Base case.
// Any of the 6 _simple_ brainfuck commands.
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
```

## Play

Wow, we have everything together.
We can now execute brainfuck programs at compile time, and produce binaries, which already contain the program's output, and no trace of brainfuck itself.

Let's throw all the code into a .cpp file and write a `main()` function, which will print our compile time results.

``` cpp
// The program input is provided by a string provider.
// The type list transformation article explains, how these work.
struct program_str {
    static constexpr const char * str() {
        // "Hello World" Brainfuck implementation from wikipedia
        return "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++."
               ".+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.+++.";
    }
};

int main()
{
    // Input is uninteresting for this program.
    using input_list = tl_null_t;

    // Transform the program string provider into a type list
    using prog       = string_list_t<program_str>;

    // Compose an initialized IOBFM from an empty BFM, and the empty input
    using BFM = bfm::io_bfm<bfm::make_t, input_list, tl::null_t>;

    // The BFM's machine output is obtained by _running_ the IOBFM
    // together with the brainfuck program in the run_tm function.
    using output = bfm::run_tm_t<BFM, prog>::output;

    // Comment this out, to get ugly compile error messages, which
    // contain the whole program output.
    //debug_t<output> t;

    // Generate a normal C string back from the output character typelist,
    // and finally print it.
    puts(tl_to_varlist<output>::str());

    return 0;
};
```

Using the compile time BFM is not as ugly as writing it.
To play with it yourself, and to completely understand it, i suggest looking at the real code.
I created [a github repository which contains the whole compile time brainfuck interpreter](https://github.com/tfc/cpp_template_meta_brainfuck_interpreter).

The code in the repository does encapsulate input string and program string into preprocessor define macros.
This way it is possible to feed different sets of input and BF programs via the command line.
In the end, it looks like this:

``` bash
Jacek.Galowicz ~/src/tmp_brainfuck $ g++ -o main main.cpp -std=c++14 -DPROGRAM_STR='"++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.+++."'
Jacek.Galowicz ~/src/tmp_brainfuck $ ./main
Hello World!
```

Printing at compile time looks like this:

``` bash
Jacek.Galowicz ~/src/tmp_brainfuck $ g++ -o main main.cpp -std=c++14 -DPROGRAM_STR='"++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.+++."'

main.cpp:31:51: error: implicit instantiation of undefined template
'debug_t<char_tl<'H', 'e', 'l', 'l', 'o', ' ', 'W', 'o', 'r', 'l', 'd', '!', '\n', '\x0D'> >'
    debug_t<typename tl_to_varlist<output>::list> t;
                                                  ^
main.cpp:6:29: note: template is declared here
template <typename T> class debug_t;
                            ^
1 error generated.
Makefile:3: recipe for target 'default' failed
make: *** [default] Error 1
```

## Summary

Implementing a Brainfuck Interpreter which works at compile time, is more a toy than actually a useful program.
But it combines several template meta-programming techniques, and therefore i regard it as a great *learning vehicle*.
And this is a nice insight into the Turing completeness of the C++ template language.
