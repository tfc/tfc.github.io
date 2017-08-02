---
layout: post
title: Static Polymorphy in C++
---

In order to use *polymorphy*, virtual functions are the way to go in C++.
They are nice and easy to use.
However, polymorphy is not always needed at actual runtime.
If it is only used to separate generic from specific functionality in order to have a common interface and avoid code duplication, the cost of having indirection introduced by *vtables* might not be desired.
This article shows how to use the CRTP in order to get the compile time advantages of polymorphy, without using virtual methods.

<!--more-->

## The example

A very typical example for polymorphy are objects which represent animals, where every animal is expected to make a typical animal sound.
Different kinds of animals like cats and dogs would then inherit the animal interface from the abstract class `Animal`:

{% highlight c++ %}
class Animal
{
public:
    void make_sound() const
    {
        flux_compensator_sound_machine  << this->get_sound() << "!";
    }

    virtual Sound get_sound() const = 0;
};

class Dog : public Animal
{
public:
    virtual Sound get_sound() const override
    { 
        return {"Woof"};
    }
};

class Cat : public Animal
{
public:
    virtual Sound get_sound() const override
    { 
        return {"Meow"};
    }
};
{% endhighlight %}

So the `Animal` class does all the generic work, without knowing anything about specific animal sounds, and asks its subclass for exactly that information.

If the code which uses that later is not calling `make_sound()` on pointers or references of type `Animal`, but instead directly on `Dog` and `Cat` types, then it is completely unnecessary to do that using virtual functions.

Instead, *CRTP* can be used, which stands for ***C*uriously *R*ecurring *T*emplate *P*attern**.

{% highlight c++ %}
template <typename T>
class Animal
{
    const T& thisT() { return *static_cast<const T*>(this); }

public:
    void make_sound() const
    {
        flux_compensator_sound_machine  << thisT().get_sound() << "!";
    }

    // No virtual declared here. However, this class just assumes that T
    // contains a function with signature "Sound T::get_sound() const"
};

class Dog : public Animal<Dog> // Note the template parameter
{
public:
    Sound get_sound() const
    { 
        return {"Woof"};
    }
};

class Cat : public Animal<Cat>
{
public:
    Sound get_sound() const override
    { 
        return {"Meow"};
    }
};
{% endhighlight %}

The casting part within class `Animal` is the interesting detail here (Which happens in `thisT()`).
So class `Animal` still implements the generic part of making an animal noise, but then does not call a virtual function on itself any longer, but it calls a function which itself does not declare at all.
Instead of calling a virtual function which the inheriting class `T` (or `Cat` and `Dog`) is forced to implement, it just *assumes* that `T` implements a normal function with signature `Sound T::get_sound() const`.
If `T` does not provide that, the compiler would error out as soon as it tries to compile code which calls `make_sound()`.

If `make_sound()` where static functions, then it would not even be necessary to cast the `this` pointer, as it would be possible to directly call `T::make_sound()` (Which would also be the cleaner software design in this case, as producing a dog/cat sound does not actually involve a particular instance - but this is just example code after all).

Class `Animal` does not implement any `get_sound` function, so the compiler will not find that without casting.
By static casting `this` to `T*` (Which is safe, as the compiler would refuse to `static_cast` if those types were not related by inheritance), the function `get_sound` becomes visible to the compiler and it will happily digest the code.

Another cool detail is, that nothing constraints `get_sound` to return an actual `Sound` type.
If `flux_compensator_sound_machine`'s stream operator accepts it, it can be any type.
Realizing that with virtual functions could also be done, but as the type `Sound` is fixed, this would be a little bit more complicated.

## PROs and CONs

### Dynamic Polymorphy

PRO:

- Easy, type safe syntax
- It is possible to decide the right function call at **run time**

CON:

- As soon as there is something `virtual` in a class/struct, the compiler will add a `vtable` pointer to every instance. This is undesired in some scenarios, because the **structure size will grow** by 8 or 4 bytes on 64bit or 32bit architectures.
- Calling a virtual function will add the indirection of looking up the `vtable` in memory, and then calling the right function via a pointer in that table. This are **two pointer lookups**. This is indeed relatively slow, if those two pointers are not in the processor's cache. (Although i do not claim virtual functions to be generally slow)


### Static Polymorphy

PRO:

- **No runtime overhead**
- The structure size **does not grow**
- The specialized implementations of the inheriting class **do not need to exactly adhere to exactly the same function signature**

CON:

- **No run time selection** of the right function implementation
- Code size grows, as the compiler sees `Animal<Cat>` and `Animal<Dog>` as **completely different types**.
