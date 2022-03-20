---
layout: post
title: Filtering Unique Items from Heterogeneous Lists at Compile Time
---

This article is about how to filter unique items from heterogeneous lists on
the type level in Haskell.
This example, without further context, might look a bit esoteric by itself,
but i learned a lot writing it and wanted to share the experience.

<!--more-->

In the last years i've been programming more in Haskell than in C++.
I find Haskell is super fascinating because of its mighty type system.
C++ already makes it possible to lift a lot of computation from compile time to run time (using `constexpr` and template meta programming) with the positive effect of resulting in less code in your binaries.
Less code in your binaries is great, because this means a ["shift left"](https://en.wikipedia.org/wiki/Shift-left_testing) of bug potential on the time axis from run time to compile time.
Now Haskell makes this much more interesting because its type system is much more intelligent than the one of C++ or comparable languages.
There are many libraries that show off what's possible.
My current favorite example because i have been using it a lot is the [`servant`](https://docs.servant.dev) library.

I found learning C++ template meta programming very hard in the beginning because it's completely different than *normal* programming. But once you get there, it's really enlightening and helps in cleaner thinking about and designing of what your programs are actually supposed to do.
Trying to do the same things and even more in Haskell, i found the following books and blog articles extremely helpful:

- Book: [**"Thinking with Types"** by Sandy Maguire](https://leanpub.com/thinking-with-types)
- Book: [**"Haskell Design Patterns"** by Ryan Lemmer](https://www.packtpub.com/product/haskell-design-patterns/9781783988723)
- Blog: [**"Taming Heterogeneous Lists in Haskell"** by Hengchu Zhang](https://hengchu.github.io/posts/2018-05-09-type-lists-and-type-classes.lhs.html)

However, after getting some inspiration what fascinating things some libraries do at the type level, i wanted to give it a try myself and came up with some private hobby challenge that i wanted to try myself.
While trying to hack on the type level, i found the available books and blogs super helpful.
But as so often the case, books/articles often tend to explain the simple things simple, then switch to much more complicated examples, but there is quite some gap between the simple and the (maybe too) advanced examples.
I got lost there unfortunately and came up with a solution to a sub-problem of my hobby challenge that i wanted to share to fill up that gap.

This blog article shows how to:

- Define a heterogeneous list and print it (looks exactly as known from books/articles)
- How to reverse such lists
- How to filter out unique type items from them
  - both at type-level and run time because we need both

Let's start with some includes and GHC extensions that we need.
The full code of this article is [here](https://gist.github.com/tfc/a525ef630abe215d1ec1d3c50609a340).


```haskell
{-# LANGUAGE AllowAmbiguousTypes    #-}
{-# LANGUAGE DataKinds              #-}
{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs                  #-}
{-# LANGUAGE PolyKinds              #-}
{-# LANGUAGE RankNTypes             #-}
{-# LANGUAGE ScopedTypeVariables    #-}
{-# LANGUAGE TypeApplications       #-}
{-# LANGUAGE TypeFamilies           #-}
{-# LANGUAGE TypeOperators          #-}
{-# LANGUAGE UndecidableInstances   #-}

import           Data.Kind    (Type)
import           GHC.TypeLits (ErrorMessage (Text), TypeError)
```

## Heterogeneous Lists

First, we need a way to create a way to describe lists of items that have different types (without polymorphy).

So let's create the type `HList` (as in "**H**eterogeneous **List**") whose GADT constructors help us constructing a list at compile time:


```haskell
data HList :: [Type] -> Type where
  HNil :: HList '[]
  (:#) :: x -> HList xs -> HList (x ': xs)
infixr 5 :#
```

Creating such a hlist now looks like this:


```haskell
data A = A Int deriving Show
data B = B Int deriving Show
data C = C Int deriving Show

abc = A 1 :# B 2 :# C 3 :# HNil

:type abc
```


<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>abc :: HList '[A, B, C]</span>


Although other tutorials and books cover this topic already, let us also create at least the `Show` instance for our `HList` in order to be able to print not only their types but also their values:


```haskell
instance Show (HList '[]) where
  show HNil = "HNil"

instance (Show x, Show (HList xs))
  => Show (HList (x ': xs)) where
  show (x :# xs) = show x ++ " :# " ++ show xs
```

The implementation is much simpler than the following stuff, because the return type of `show` is just `String` and that is easy to assemble from our list construction.

Let's try it out:


```haskell
abc
```


    A 1 :# B 2 :# C 3 :# HNil


Fine. Off to the more complicated things now.

## Reversing HLists

All the examples on the internet first show how to write functions on hlists: First, implement a type class and then all the relevant instances for them. These are usually not too hard to understand and write, because the output type does not really depend on the inputs - just like our `Show` instance from before.

Having understood that, the next thing that i found hard to achieve was *reversing* a heterogeneous list.
The reason is, that the return type of a reverse function would completely depend on the input:

```haskell
aReverserFunction :: Hlist '[ A, B, C ] -> HList '[ C, B, A ]
```

But how to express that programmatically? Implementing the type class would be easy, but i would need to programmatically calculate the output type from the input type.
Without knowing the resulting return type in advance, the type class would be of no use.
Afterward, we can implement the type class that uses this calculated type.

A function on the *type level* that creates a new type from some input type can be implemented in terms of a *type family*:


```haskell
type family Reverse' (inputList :: [Type])
                     (accumulator :: [Type])
                     :: [Type]
                     where
  Reverse' '[] accumulator = accumulator
  Reverse' (i ': is) accumulator = Reverse' is (i ': accumulator)

type Reverse a = Reverse' a '[]
```

This function takes an input type list and accumulates the reverse of the list, item by item, on the accumulator argument.
As soon as the input list contains no items any longer, the accumulator is returned.

As it would be otherwise uncomfortable to provide the input list *and* the accumulator, let's call this type-level function `Reverse'` and define a type alias `Reverse` which just accepts the input list and hides the rest of the interface for us.

This works as expected:


```haskell
:kind! Reverse '[ A, B, C ]
```


<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>Reverse '[ A, B, C ] :: [*]
= '[C, B, A]</span>


The type class `Rev` will provide us a `rev'` function with just the same interface but at normal function level.
In order to hide this input-and-accumulator interface, we will later define function `rev` which hides this implementation detail from the user.


```haskell
class ReversedHList (inputList :: [Type])
                    (accumulator :: [Type])
                    (reversedList :: [Type])
                    where
  rev' :: HList inputList
       -> HList accumulator
       -> HList reversedList

instance ReversedHList '[] a a where
  rev' _ a = a

instance ReversedHList is (i ': as) rs
    => ReversedHList (i ': is) as rs where
    rev' (i :# is) as = rev' is (i :# as)
```

What's most interesting here is that `reversedList` is a type that remains completely unchanged over the instances that are called one after the other.
This is the final return type that needs to be calculated before, and we have not done that, yet.

Our `rev` function does both hide the accumulator from the user and calculate the result type using our previously implemented `Reverse` type-level function:


```haskell
rev :: forall inputList.
       ReversedHList inputList '[] (Reverse inputList)
    => HList inputList
    -> HList (Reverse inputList)
rev i = rev' @inputList @'[] @(Reverse inputList) i HNil
```

The strange `@inputList` notation is called [*type application*](https://ghc.gitlab.haskell.org/ghc/doc/users_guide/exts/type_applications.html) and makes it easier to see which instance of function `rev'` we are calling.
Often enough such hints are not needed (in this specific case the code will compile without), but they also make it easier to read the code due to its explicitness.

That the output type is `HList (Reverse inputList)` is the simpler part of this function.
But that i have to write down the `Rev inputList '[] (Reverse inputList)` class constraint is something that i didn't get for a long time.
If you leave that away, the compiler will give you the following feedback:

```
<interactive>:3:9: error:
    • No instance for (Rev inputList '[] (Reverse' inputList '[])) arising from a use of ‘rev'’
    • In the expression: rev' @inputList @'[] @(Reverse inputList) i HNil
      In an equation for ‘rev’: rev i = rev' @inputList @'[] @(Reverse inputList) i HNil
```

I understand this as "Just because you're using `rev'` does not mean that i can automatically constraint the user's input types to be instances of this class. Please write down this requirement explicitly."
Thinking about it a bit longer, it does help reading the rest of the code because it explains which type instance it will select first.

Afterall, the function works just as expected:


```haskell
:type rev abc

rev abc
```


<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>rev abc :: HList '[C, B, A]</span>



    C 3 :# B 2 :# A 1 :# HNil


If we had implemented the `Show` instance for our lists, we could also see that the transformation was not only done on the type level.

Now, let's look at the next challenge.

## Type-Level Helper Functions

In the end we are going to remove duplicate types from heterogeneous lists, but before we arrive there we need to implement some helper functions.

The first helper type-level function tells us if a list already contains some type:


```haskell
type family Contains (inputList :: [Type]) (inputType :: Type) :: Bool where
  -- head of the list equals the input type
  Contains (x ': _) x = 'True
  -- recursion terminator: list didn't contain it
  Contains '[] _ = 'False
  -- current head does not equal the input type, so recurse to the next one
  Contains (_ ': xs) x = Contains xs x
```


```haskell
:kind! Contains '[A, B, C] A

:kind! Contains '[B, C] A
```


<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>Contains '[A, B, C] A :: Bool
= 'True</span>



<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>Contains '[B, C] A :: Bool
= 'False</span>


This works great.

The next helper that we are going to need later is a type-level if function.
It accepts a bool value on the type-level, and two types of which one is returned back, depending on the boolean condition input:


```haskell
type family If (condition :: Bool) (thenCase :: k) (elseCase :: k) :: k where
  If 'True  a _ = a
  If 'False _ b = b
```


```haskell
:kind! If 'True  A B
:kind! If 'False A B
```


<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>If 'True A B :: *
= A</span>



<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>If 'False A B :: *
= B</span>


## Filtering Only Unique Items from a List

The type-level function that immediately puts to use our new `Contains` and `If` function shall recursively traverse through an input list and return an output list that only contains the unique types of the input list:


```haskell
type family Uniques (xs :: [Type]) :: [Type] where
  Uniques (x ': xs) = If (Contains xs x) (Uniques xs) (x ': Uniques xs)
  Uniques '[] = '[]
```


```haskell
:kind! Uniques '[A, B, A, C]
```


<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>Uniques '[A, B, A, C] :: [*]
= '[B, A, C]</span>


A helper that is going to be handy in the following is the type-level function `ContainsHead`:
It accepts two type lists as arguments and tests if the first list contains the head element of the second list.

We are later feeding this function into a type class parameter that then helps us selecting the right type class.
In the special case that the second list is *empty*, we return a comprehensible error message.


```haskell
type family ContainsHead (listToCheckAgainst :: [Type])
                         (listToCheck :: [Type])
                         :: Bool
                         where
  ContainsHead as (b ': bs) = Contains as b
  ContainsHead _ '[] =
      TypeError ('Text "ContainsHead can't take off the head of an empty list")
```


```haskell
:kind! ContainsHead '[ A, B, C ] '[ B, C ]
:kind! ContainsHead '[ A ] '[ B, C ]
:kind! ContainsHead '[ A, B, C ] '[ ]
```


<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>ContainsHead '[ A, B, C ] '[ B, C ] :: Bool
= 'True</span>



<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>ContainsHead '[ A ] '[ B, C ] :: Bool
= 'False</span>



<style>/* Styles used for the Hoogle display in the pager */
.hoogle-doc {
display: block;
padding-bottom: 1.3em;
padding-left: 0.4em;
}
.hoogle-code {
display: block;
font-family: monospace;
white-space: pre;
}
.hoogle-text {
display: block;
}
.hoogle-name {
color: green;
font-weight: bold;
}
.hoogle-head {
font-weight: bold;
}
.hoogle-sub {
display: block;
margin-left: 0.4em;
}
.hoogle-package {
font-weight: bold;
font-style: italic;
}
.hoogle-module {
font-weight: bold;
}
.hoogle-class {
font-weight: bold;
}
.get-type {
color: green;
font-weight: bold;
font-family: monospace;
display: block;
white-space: pre-wrap;
}
.show-type {
color: green;
font-weight: bold;
font-family: monospace;
margin-left: 1em;
}
.mono {
font-family: monospace;
display: block;
}
.err-msg {
color: red;
font-style: italic;
font-family: monospace;
white-space: pre;
display: block;
}
#unshowable {
color: red;
font-weight: bold;
}
.err-msg.in.collapse {
padding-top: 0.7em;
}
.highlight-code {
white-space: pre;
font-family: monospace;
}
.suggestion-warning {
font-weight: bold;
color: rgb(200, 130, 0);
}
.suggestion-error {
font-weight: bold;
color: red;
}
.suggestion-name {
font-weight: bold;
}
</style><span class='get-type'>ContainsHead '[ A, B, C ] '[ ] :: Bool
= (TypeError ...)</span>


Now we get to the part that turned out to look really complicated:
The class `UniqueHList` provides us a function `ul'` that has a similar accumulator based interface like the reverse function.
A given input list is consumed step by step, and if the current item is already in the accumulator list, we drop it.
Otherwise, we put it into the accumulator.
After fully consuming the input list, we can return the accumulator.
The type `uniqueList` can be forecasted using our `Uniques` type-level function. It doesn't change throughout all the instances ass they call each other and pass it from the first call to the last.

The most interesting addition to this interface is the `nextElementIsContainedAlready` boolean argument.
As the name suggests, one instance fills it out for the next instance so they can decide what to do with the current input list head item, as we will see in the following.


```haskell
class UniqueHList (inList :: [Type])
                  (accumulator :: [Type])
                  (uniqueList :: [Type])
                  (nextElementIsContainedAlready :: Bool)
                  where
  ulr' :: HList inList
       -> HList accumulator
       -> HList uniqueList
```

The recursion terminal instance is the one where the input list is empty.
In this case we simply return the accumulator.
It is not interesting what the value of the bool argument is in this special case.

I named the class function `ulr'` as in "**u**nique **l**ist **reversed**", because due to the accumulator interface of this function, the accumulator will contain all the items in reversed order when we consumed the input list.
We will turn it around later.


```haskell
instance UniqueHList '[] uniqueList uniqueList dontCare where
  ulr' _ x = x
```

In all of the following instances, i used some very much abbreviated type variable names:
`is` stands for **i**nput item**s**", `as` for "**a**ccumulator item**s**", and `us` for "**u**nique item**s**".

The `'False` value in the `nextElementIsContainedAlready` argument says that this instance is for the cases where the next input list item is not yet contained by the accumulator.
So by removing it from the input list and prepending it to the accumulator, we do the right thing.

The many type application `@` things here are a bit noisy, but this time the compiler needs them as a hint.
They basically replicate the class constraint that described what the next instance is.

`(ContainsHead (i ': as) is)` is the next bool value that is put into the next class instance:
The new state of our accumulator will be `i ': as` in that next instance, so we need to check if the head of the rest of the input list is already contained in that new accumulator.
That is practically the essence of the complicated-looking `UniqueHList` instance unfolding logic.


```haskell
instance UniqueHList is (i ': as) us (ContainsHead (i ': as) is)
    => UniqueHList (i ': is) as us 'False where
    ulr' (i :# is) as =
        ulr' @is @(i ': as) @us @(ContainsHead (i ': as) is) is (i :# as)
```

In the cases where the next item from the input list is already contained by the accumulator, we need to drop it and then call the next instance.


```haskell
instance UniqueHList is as us (ContainsHead as is)
    => UniqueHList (i ': is) as us 'True where
    ulr' (_ :# is) as =
        ulr' @is @as @us @(ContainsHead as is) is as
```

We can already call it for a quick test:


```haskell
ulr' @'[A, B, A, C] @'[] @(Uniques (Reverse '[A, B, A, C])) @'False (A 1 :# B 2 :# A 3 :# C 4 :# HNil) HNil
```


    C 4 :# B 2 :# A 1 :# HNil


It works, but what struck me was the fact that the output is the unique list of the reverse input list.
I am pretty sure that if i was smarter, i could construct the whole thing to work more intuitively.
After playing around with the implementation trying to make it nicer without nice results, i concluded that this may be a quest for another day.
I was already happy that it works at all, so let's continue describing the working state.

Building on the working example input, the function `ulr` hides all the type hints from the user and calls our class function with the right arguments:


```haskell
ulr :: forall inputList.
       UniqueHList inputList '[] (Uniques (Reverse inputList)) 'False
   => HList inputList
   -> HList (Uniques (Reverse inputList))
ulr x = ulr' @inputList @'[] @(Uniques (Reverse inputList)) @'False x HNil
```

As the user would not expect a reversed output list, let's concatenate our `rev` function with the new `ulr` function to provide the expected results.

The implementation is really simple but writing down the types turned out a bit ugly.
It is surely somehow possible to tell the compiler that `Reverse (Uniques (Reverse x))` is really the same as `Uniques x`, but at this time i don't know how to do it.


```haskell
ul :: forall inputList.
    ( ReversedHList (Uniques (Reverse inputList))
                    '[]
                    (Reverse (Uniques (Reverse inputList)))
    , UniqueHList inputList '[] (Uniques (Reverse inputList)) 'False
    )
    => HList inputList
    -> HList (Reverse (Uniques (Reverse inputList)))
ul = rev . ulr
```

## The Moment of Truth

That should be it. The moment of truth - does it work?


```haskell
abc
ul abc
```


    A 1 :# B 2 :# C 3 :# HNil

    A 1 :# B 2 :# C 3 :# HNil


It doesn't destroy a list that is already unique. Actually, it doesn't do anything on a unique list and that's good.

Let's roll out a more complicated case:


```haskell
ababca = A 1 :# B 2 :# A 3 :# B 4 :# C 5 :# A 6 :# HNil

ababca
ul ababca
```


    A 1 :# B 2 :# A 3 :# B 4 :# C 5 :# A 6 :# HNil

    A 1 :# B 2 :# C 5 :# HNil


Happiness.

## Summary

This is now a big bunch of special purpose code that reinvents multiple wheels, but it really helped my personal understanding, and i hope it also helps yours.
The next step would be to use libraries which do all of this better, so we don't need so much code.
There is for example [`HList`](https://hackage.haskell.org/package/HList) which is really elegant and is so much more comprehensible once we understand more type-level programming.

I've done a type-level programming in C++ before (have a look at the older articles in this blog) and i find it very interesting how similar it really is.
In haskell, it is more frustrating in the beginning because the kind system is complicated.
As soon as the basic mechanisms are understood, it is nice to see that Haskell's type system is much more intelligent than C++ templates and there's much more control over everything.
