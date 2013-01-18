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