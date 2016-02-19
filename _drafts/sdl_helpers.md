
{% highlight c++ %}
#include <memory>
#include <SDL2/SDL.h>

static void SDL_DeleteResource(SDL_Window   *r) { SDL_DestroyWindow(r); }
static void SDL_DeleteResource(SDL_Renderer *r) { SDL_DestroyRenderer(r); }
static void SDL_DeleteResource(SDL_Texture  *r) { SDL_DestroyTexture(r); }
static void SDL_DeleteResource(SDL_Surface  *r) { SDL_FreeSurface(r); }

template <typename T>
std::shared_ptr<T> sdl_shared(T *t) {
    return std::shared_ptr<T>(t, [](T *t) { SDL_DeleteResource(t); });
}
{% endhighlight %}


{% highlight c++ %}
int main(){
    if (SDL_Init(SDL_INIT_VIDEO) != 0){
        std::cout << "SDL_Init Error: " << SDL_GetError() << std::endl;
        return 1;
    }

    ON_EXIT { SDL_Quit(); };

    auto win (sdl_shared(SDL_CreateWindow("Hello World!",
            SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
            width, height, SDL_WINDOW_SHOWN)));
    if (win == nullptr){
        std::cout << "SDL_CreateWindow Error: " << SDL_GetError() << std::endl;
        return 1;
    }

    auto ren (sdl_shared(SDL_CreateRenderer(win.get(), -1,
            SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)));
    if (ren == nullptr){
        std::cout << "SDL_CreateRenderer Error: " << SDL_GetError() << std::endl;
        return 1;
    }

    auto bmp(sdl_shared(SDL_LoadBMP("hello.bmp")));
    if (bmp == nullptr){
        std::cout << "SDL_LoadBMP Error: " << SDL_GetError() << std::endl;
        return 1;
    }

    auto tex (sdl_shared(SDL_CreateTextureFromSurface(ren.get(), bmp.get())));
    bmp.reset();
    if (tex == nullptr) {
        std::cout << "SDL_CreateTextureFromSurface Error: "
                  << SDL_GetError() << std::endl;
        return 1;
    }

    // ...
}
{% endhighlight %}

