---
layout: post
title: Type List Performance
---

Soon, after writing my first meta programs with C++ templates, i realized, that certain programming patterns lead to sky rocketing compile times.
I came up with rules of thumb like "*Prefer pattern matching over if_else_t*", and "*Prefer nested type lists over variadic type lists*".
But i did not how much faster which pattern is, i just knew about tendencies.
Finally, i sat down to write some compile time benchmarks, and this blog posts presents the results.


# Creating Lists

## Metashell
![Metashell: Compile time benchmark measuring creation time of integer sequence recursive vs. variadic type lists](/assets/compile_time_type_list_creation_benchmark_metashell.png)

## Compilers
![GCC/Clang: Compile time benchmark measuring creation time of integer sequence recursive vs. variadic type lists](/assets/compile_time_type_list_creation_benchmark_compilers.png)

# Filtering Lists

![bla](/assets/compile_time_type_list_filter_benchmark.png)
![bla](/assets/compile_time_type_list_filter_benchmark_recursive_only.png)
