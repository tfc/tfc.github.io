---
layout: post
title: A Nice Way to Manage SDL Resource Lifetime
tags: c++
---

I happen to use the SDL library when i need to display graphics on the screen, but want to do it simpler than with OpenGL.
SDL is easy to use and portable, but it is a C-style library.
Because of that C nature, the library does not really help the user to write elegant, modern code.
Acquiring and Releasing SDL resources often ends up in ugly old school resource management.
It is not hard to fix that, and this article shows how useful `shared_ptr` from the STL is in such cases.
The approach is easily extendable to other kinds of resources, too.

<!--more-->

## Typical C-Style SDL Code

``` cpp
#include <SDL2/SDL.h>

int main() {
    if (SDL_Init(SDL_INIT_VIDEO) != 0){
        return 1;
    }

    SDL_Window *win {SDL_CreateWindow("Window Title",
            SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
            width, height, SDL_WINDOW_SHOWN)};
    if (win == nullptr){
        SDL_Quit();
        return 1;
    }

    SDL_Renderer *ren {SDL_CreateRenderer(win, -1,
            SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)};
    if (ren == nullptr){
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    SDL_Surface *bmp {SDL_LoadBMP("some_bitmap.bmp")};
    if (bmp == nullptr){
        SDL_DestroyRenderer(ren);
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    SDL_Texture *tex {SDL_CreateTextureFromSurface(ren, bmp)};
    if (tex == nullptr) {
        SDL_FreeSurface(bmp);
        SDL_DestroyRenderer(ren);
        SDL_DestroyWindow(win);
        SDL_Quit();
        return 1;
    }

    // ...

    SDL_DestroyTexture(tex);
    SDL_FreeSurface(bmp);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
}
```

This code contains a list of resource release code which is also quite error prone to write/maintain.

## Using `shared_ptr` to Automate Resource Handling

`shared_ptr` from the STL is a useful helper class, which wraps a pointer to some resource payload.
As soon as a shared pointer is released, it automatically calls `delete` on the payload instance being pointed to.

The resources which SDL gives us, cannot be release using `delete`, as the SDL provides specific functions for every resource type.
In order to be able to use `shared_ptr`'s automatic resource management capability, it needs to be customized to call *different* code than the default `delete` call.

This is indeed possible:
`shared_ptr`'s constructor takes a second, optional parameter, which can be a lambda expression.
This lambda expression will then be called (with the payload pointer as its only parameter) by the shared pointer class instead of its default `delete` call.

The following code provides a function `sdl_shared`, which takes a pointer to an SDL resource, and wraps it into a `shared_ptr` instance which automatically calls the right SDL specific release function at its end of life cycle:

``` cpp
#include <memory> // shared_ptr
#include <SDL2/SDL.h>

static void SDL_DelRes(SDL_Window   *r) { SDL_DestroyWindow(r);   }
static void SDL_DelRes(SDL_Renderer *r) { SDL_DestroyRenderer(r); }
static void SDL_DelRes(SDL_Texture  *r) { SDL_DestroyTexture(r);  }
static void SDL_DelRes(SDL_Surface  *r) { SDL_FreeSurface(r);     }

template <typename T>
std::shared_ptr<T> sdl_shared(T *t) {
    return std::shared_ptr<T>(t, [](T *t) { SDL_DelRes(t); });
}
```

`sdl_shared` is a template function which deduces the pointer type from the input parameter.
This helper function can be wrapped around any SDL resource allocating function, as long as one `SDL_DelRes` overload is defined for the specific SDL resource type.

Using this helper, the resource management can be implemented much cleaner:

``` cpp
int main() {
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        return 1;
    }

    ON_EXIT { SDL_Quit(); };

    auto win (sdl_shared(SDL_CreateWindow("Hello World!",
            SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
            width, height, SDL_WINDOW_SHOWN)));
    if (win == nullptr) return 1;

    auto ren (sdl_shared(SDL_CreateRenderer(win.get(), -1,
            SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)));
    if (ren == nullptr) return 1;

    auto bmp(sdl_shared(SDL_LoadBMP("hello.bmp")));
    if (bmp == nullptr) return 1;

    auto tex (sdl_shared(SDL_CreateTextureFromSurface(
                                    ren.get(), bmp.get())));
    if (tex == nullptr) return 1;

    // ...
}
```

*Also have a look at the other article, which [describes the `ON_EXIT` macro](/2016/02/21/on_exit_macro)*.

All resources are automatically released, and the programmer does not need to define which resource is to be released in which case and what order.
