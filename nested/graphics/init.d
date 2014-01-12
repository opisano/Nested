/*------------------------------------------------------------------------------
    Copyright© 2010-2014 Olivier Pisano

    This file is part of Nested.

    Nested is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Nested is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Nested.  If not, see <http://www.gnu.org/licenses/>.
------------------------------------------------------------------------------*/

module graphics.init;

import std.exception;

import derelict.sdl2.sdl;

import common;



enum SCREEN_WIDTH  = 256;
enum SCREEN_HEIGHT = 240;

class GraphicsException : Exception
{
public:
    this(string s)
    {
        super(s);
    }
}

/**
 * Display of the application
 */
final class Display : IDisposable
{
    SDL_Window* window;
    SDL_Renderer* renderer;
    
public:
    this()
    {
        // Create our application window and renderer
        window = SDL_CreateWindow("Nested",
                                    SDL_WINDOWPOS_UNDEFINED,
                                    SDL_WINDOWPOS_UNDEFINED,
                                    640, 480,
                                    0);
        enforce(window !is null, "SDL_CreateWindow failed");
        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
        enforce(renderer !is null, "SDL_CreateRenderer failed");
        SDL_ShowWindow(window);

    }

    void dispose()
    {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
    }
}