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

module controller;

import derelict.sdl.sdl;
import std.conv;
import std.stdio;

/* state indices */

enum A      = 0;
enum B      = 1;
enum SELECT = 2;
enum START  = 3;
enum UP     = 4;
enum DOWN   = 5;
enum LEFT   = 6;
enum RIGHT  = 7;

/**
 * The state of a NES controller, as seen from the CPU
 */
struct ControllerState
{   
    /** Controller registers */
    ubyte[8] states;
    
    /** Index of current register */
    ubyte  index;
    
    void write(ubyte value)
    {
        index = value;
    }
    
    /** Reads current register */
    ubyte read()
    {
        if (index >= 8)
            index = 0;
        
        return states[index++];
    }
    
    void onAPressed()
    {
        states[A] = 0xFF;
    }
    
    void onAReleased()
    {
        states[A] = 0;
    }
    
    void onBPressed()
    {
        states[B] = 0xFF;
    }
    
    void onBReleased()
    {
        states[B] = 0;
    }
    
    void onSelectPressed()
    {
        states[SELECT] = 0xFF;
    }
    
    void onSelectReleased()
    {
        
        states[SELECT] = 0;
    }
    
    void onStartPressed()
    {
        states[START] = 0xFF;
    }
    
    void onStartReleased()
    {
        states[START] = 0;
    }
    
    void onUpPressed()
    {
        states[UP] = 0xFF;
    }
    
    void onUpReleased()
    {
        states[UP] = 0;
    }
    
    void onDownPressed()
    {
        states[DOWN] = 0xFF;
    }
    
    void onDownReleased()
    {
        states[DOWN] = 0;
    }
    
    void onLeftPressed()
    {
        states[LEFT] = 0xFF;
    }
    
    void onLeftReleased()
    {
        states[LEFT] = 0;
    }
    
    void onRightPressed()
    {
        states[RIGHT] = 0xFF;
    }
    
    void onRightReleased()
    {
        states[RIGHT] = 0;
    }
}

/** SDL Joystick handling */
final class Joystick
{
    /** Joystick index */
    uint index;
    /** SDL joystick handle */
    SDL_Joystick* joystick;
    /** NES Controller state this joystick emulates */
    ControllerState* state;

public:
    string name;
    
    /** Returns the number of joystick plugged into the PC */
    static uint getJoystickCount()
    {
        return SDL_NumJoysticks();
    }
    
    this(uint index, ControllerState *state)
    in
    {
        assert (index < getJoystickCount());
        //assert (state !is null);
    }
    body
    {
        this.index = index;
        this.state = state;
        joystick   = SDL_JoystickOpen(index);
        name       = to!(string)(SDL_JoystickName(joystick));
    }
    
    /** Handles joystick events for */
    void handleAxisEvent(const ref SDL_Event event)
    {
        if (event.jaxis.value < -3200)
        {
            if (event.jaxis.axis == 0) // Left right axis
            {
                debug { writefln("Left pressed"); }
                state.onLeftPressed();
            }
            else if (event.jaxis.axis == 1) // Up down axis
            {
                debug { writefln("Up pressed"); }
                state.onLeftPressed();
            }
        }
        else if (event.jaxis.value > 3200)
        {
            if (event.jaxis.axis == 0) // Left right axis
            {
                debug { writefln("Right pressed"); }
                state.onRightPressed();
            }
            else if (event.jaxis.axis == 1) // Up down axis
            {
                debug { writefln("Down pressed"); }
                state.onDownPressed();
            }
        }
        else
        {
            if (event.jaxis.axis == 0) // Left right axis
            {
                debug {writefln("Left/Right released");}
                state.onLeftPressed();
                state.onRightReleased();
            }
            
            if (event.jaxis.axis == 1) // up down axis
            {
                debug {writefln("Up/down released");}
                state.onUpReleased();
                state.onRightReleased();
            }
        }
    }
    
    void handleButtonDownEvent(const ref SDL_Event event)
    {
        debug {writefln("Button %d was pressed", event.jbutton.button);}
        switch (event.jbutton.button)
        {
            case 0:
                state.onBPressed();
                break;
            case 1:
                state.onAPressed();
                break;
            case 2:
                state.onSelectPressed();
                break;
            case 3:
                state.onStartPressed();
                break;
            default:
                debug { writefln("Button %s was pressed.", event.jbutton.button); }
        }
    }
    
    void handleButtonUpEvent(const ref SDL_Event event)
    {
        debug {writefln("Button %d was released", event.jbutton.button);}
        switch (event.jbutton.button)
        {
            case 0:
                state.onBReleased();
                break;
            case 1:
                state.onAReleased();
                break;
            case 2:
                state.onSelectReleased();
                break;
            case 3:
                state.onStartReleased();
                break;
            default:
                debug { writefln("Button %s was released.", event.jbutton.button); }
        }
    }
    
    void cleanup()
    {
        if (joystick)
            SDL_JoystickClose(joystick);
    }
}