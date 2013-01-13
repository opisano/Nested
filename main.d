module main;

import std.conv;
import std.stdio;

import controller;
import file.ines;
import file.rom;
import graphics.init;

import derelict.sdl.sdl;

/**
 * This class handles application events. 
 */
final class Application
{
    Display display;
    ControllerState ctrlState;
    Joystick joystick;
    bool active;
    
    /** Draws the screen */
    void render()
    {
        
    }
    
    /** Handles SDL events */
    void handleEvent(ref SDL_Event event)
    {
        switch (event.type)
        {
            case SDL_QUIT:
                active = false;
                break;
                
            case SDL_JOYAXISMOTION:
                if (joystick)
                {
                    joystick.handleAxisEvent(event);
                }
                break;
                
            case SDL_JOYBUTTONDOWN:
                if (joystick)
                {
                    joystick.handleButtonDownEvent(event);
                }
                break;
                
            case SDL_JOYBUTTONUP:
                if (joystick)
                {
                    joystick.handleButtonUpEvent(event);
                }
                break;
                
            default:
                break;
        }
    }
    
public:
    
    /** Initializes the application */
    this()
    in
    {
        uint init = SDL_WasInit(SDL_INIT_EVERYTHING);
        assert (init & SDL_INIT_VIDEO);
        assert (init & SDL_INIT_JOYSTICK);
    }
    body
    {
        display = new Display(1);
        if (Joystick.getJoystickCount() > 0)
        {
            SDL_JoystickEventState(SDL_ENABLE);
            joystick = new Joystick(0, &ctrlState);
        }
        active  = false;
    }

    /** Application main loop. Handles events. */
    void run()
    {
        active = true;
        
        SDL_Event event;
        while(active)
        {
            while (SDL_PollEvent(&event))
            {
                handleEvent(event);
            }
            
            render();
        }
    }
    
    /** Loads a rom file */
    void loadFile(string filename)
    {
        try
        {
            const(Rom) inesFile = file.ines.loadFile(filename);
            
        }
        catch (Exception e)
        {
            writefln(e.toString());
        }
    }
    
    /** Frees resources on application exit. */
    void cleanup()
    {
        if (display)
            display.cleanup();
        
        if (joystick)
            joystick.cleanup();
        
        SDL_Quit();
    }
}


void main(string[] argv)
{
    DerelictSDL.load();
    if (SDL_Init( SDL_INIT_VIDEO | SDL_INIT_JOYSTICK ) < 0)
    {
        string reason = to!(string)(SDL_GetError());
        writefln("Couldn't initialize SDL: %s", reason);
    }
        
    Application app = new Application();
    scope (exit) 
        app.cleanup();
    
    // load iNes file passed as a command line argument
    if (argv.length > 1)
    {
        app.loadFile(argv[1]);
    }
    
    app.run();
}
