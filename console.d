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

module console;

import cpu;
import controller;
import memory;
import ppu;

import derelict.sdl.sdl;

final class Console
{
    CPU cpu;
    PPU ppu;

    ControllerState ctrlState;
    Joystick joystick;

    void initJoystick()
    {
        if (Joystick.getJoystickCount() > 0)
        {
            SDL_JoystickEventState(SDL_ENABLE);
            joystick = new Joystick(0, &ctrlState);
        }
    }

public:
    this()
    {
        ppu = new PPU();
        cpu = new CPU(ppu);
        initJoystick();
    }

    void cleanup()
    {
        if (joystick)
            joystick.cleanup();
    }

    void tick()
    {
        cpu.clock();
    }

    void handleJoystickAxisEvent(const ref SDL_Event event)
    {
        if (joystick)
            joystick.handleAxisEvent(event);
    }

    void handleJoystickButtonDownEvent(const ref SDL_Event event)
    {
        if (joystick)
            joystick.handleButtonDownEvent(event);
    }

    void handleJoystickButtonUpEvent(const ref SDL_Event event)
    {
        if (joystick)
            joystick.handleButtonUpEvent(event);
    }
}