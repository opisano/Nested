/*------------------------------------------------------------------------------
    Copyright© 2010-2013 Olivier Pisano

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

import derelict.sdl.sdl;


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
final class Display
{
    SDL_Surface* display;
    
public:
    this(int factor)
    in
    {
        assert (factor >= 1 && factor <= 4);
    }
    body
    {
        const int w = SCREEN_WIDTH * factor;
        const int h = SCREEN_HEIGHT * factor;


        display = SDL_SetVideoMode(w, h, 32, SDL_SWSURFACE);
        if (display == null)
        {
            throw new GraphicsException("Cannot initialize video");
        }
        
        SDL_WM_SetCaption("NESted", null);
    }
    
    
    
    void cleanup()
    {
        SDL_FreeSurface(display);
    }
}