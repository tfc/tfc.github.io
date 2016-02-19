---
layout: post
title: TypeLists
---

{% highlight c++ %}
struct NullType {};

template <class T, class U>
struct TypeList
{
    using Head = T;
    using Tail = U;
};



template <class T, class ... REST>
struct MakeTypeList
{
    using Result = TypeList<T, typename MakeTypeList<REST...>::Result>;
};

template <class T>
struct MakeTypeList<T>
{
    using Result = TypeList<T, NullType>;
};



template <class TList>
struct Length;

template <>
struct Length<NullType>
{
    static constexpr size_t value {0};
};

template <class T, class U>
struct Length<TypeList<T, U>>
{
    static constexpr size_t value {1 + Length<U>::value};
};



template <class TList, size_t i>
struct TypeAt;

template <class Head, class Tail>
struct TypeAt<TypeList<Head, Tail>, 0>
{
    using Result = Head;
};

template <class Head, class Tail, size_t i>
struct TypeAt<TypeList<Head, Tail>, i>
{
    using Result = typename TypeAt<Tail, i - 1>::Result;
};



template <class TList, class T>
struct IndexOf;

template <class T>
struct IndexOf<NullType, T>
{
    static constexpr int value {-1};
};

template <class T, class Tail>
struct IndexOf<TypeList<T, Tail>, T>
{
    static constexpr int value {0};
};

template <class Head, class Tail, class T>
struct IndexOf<TypeList<Head, Tail>, T>
{
private:
    static constexpr int tmp {IndexOf<Tail, T>::value};
public:
    static constexpr int value {tmp == -1 ? -1 : 1 + tmp};
};



template <class TList, class T>
struct TypeListContains
{
    static constexpr bool result {IndexOf<TList, T>::value != -1};
};



template <class TList, class T>
struct Append;

template <>
struct Append<NullType, NullType>
{
    using Result = NullType;
};

template <class T>
struct Append<NullType, T>
{
    using Result = typename MakeTypeList<T>::Result;
};

template <class Head, class Tail>
struct Append<NullType, TypeList<Head, Tail>>
{
    using Result = TypeList<Head, Tail>;
};

template <class Head, class Tail, class T>
struct Append<TypeList<Head, Tail>, T>
{
    using Result = TypeList<Head, typename Append<Tail, T>::Result>;
};

{% endhighlight %}

