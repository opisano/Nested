module main;

import std.conv;
import std.stdio;
import std.exception;

import derelict.sdl2.sdl;

import console;

void main(string[] argv)
{
    DerelictSDL2.load();
    if (SDL_Init( SDL_INIT_VIDEO | SDL_INIT_JOYSTICK ) < 0)
    {
        string reason = to!(string)(SDL_GetError());
        writefln("Couldn't initialize SDL: %s", reason);
    }

    // create application window
    SDL_Window* window = SDL_CreateWindow("CPU Test",
                                          SDL_WINDOWPOS_CENTERED,
                                          SDL_WINDOWPOS_CENTERED,
                                          640, 480,
                                          SDL_WINDOW_SHOWN);
    enforce(window != null);
    scope (exit) { SDL_DestroyWindow(window); }

    // create application renderer
    SDL_Renderer* renderer = SDL_CreateRenderer(window,
                                                -1, 
                                                0);
    enforce(renderer != null);
    scope (exit) { SDL_DestroyRenderer(renderer); }

    // create screen texture in GPU
    SDL_Surface* screen = SDL_CreateRGBSurface(0, 256, 240, 32, 
                                               0x00FF0000,
                                               0x0000FF00,
                                               0x000000FF,
                                               0xFF000000);

    SDL_Texture* texture = SDL_CreateTexture(renderer, 
                                             SDL_PIXELFORMAT_ARGB8888,
                                             SDL_TEXTUREACCESS_STREAMING,
                                             256, 240);
    enforce(texture != null);
    scope (exit) { SDL_DestroyTexture(texture); }






    auto builder = new PalConsoleBuilder;
    auto console = builder.createConsole(screen);
    console.loadGame("nestest.nes");
    while (1)
    {
        auto start = SDL_GetTicks();
        console.tick();
        SDL_UpdateTexture(texture, null, (*screen).pixels, (*screen).pitch);
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, null, null);
        SDL_RenderPresent(renderer);

        auto end = SDL_GetTicks();

        SDL_Delay(17 - (end - start));
    }
}
