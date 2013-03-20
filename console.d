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
import file.ines;
import memory;
import ppu;

import derelict.sdl.sdl;

final class Console
{
    /// Our console CPU
    CPU cpu;

    /// Our console graphic chip
    PPU ppu;

    /// Our console controller 
    ControllerState ctrlState;
    Joystick joystick;

    /// The screen the console is plugged to
    SDL_Surface* display;

    void initJoystick()
    {
        if (Joystick.getJoystickCount() > 0)
        {
            SDL_JoystickEventState(SDL_ENABLE);
            joystick = new Joystick(0, &ctrlState);
        }
    }

public:
    this(SDL_Surface* disp)
    {
        ppu = new PPU();
        cpu = new CPU(ppu);
        display = disp;
        initJoystick();
    }

    void cleanup()
    {
        if (joystick)
            joystick.cleanup();
    }

    void tick()
    {
        cpu.clock(display);
    }

    void loadGame(string filename)
    {
        auto rom = file.ines.loadFile(filename);

        const(ubyte)[] first, second;

        switch (rom.prg.length)
        {
            case 16_384:
                first = rom.prg[0..16_384];
                second = null;
                break;
            case 32_768:
                first = rom.prg[0..16_384];
                second = rom.prg[16_384..$];
                break;
            default:
                throw new Exception("ROM too big");
        }
        cpu.getMemoryMap().loadPrgRom(first, second);
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