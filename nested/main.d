module main;

import std.conv;
import std.stdio;

import console;
import file.ines;
import file.rom;
import graphics.init;

import derelict.sdl2.sdl;


/**
 * This class handles application events. 
 */
final class Application
{
    Display display;
    Console console;
    
    bool active;
    bool emulationActive;
    
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
                console.handleJoystickAxisEvent(event);
                break;
                
            case SDL_JOYBUTTONDOWN:
                console.handleJoystickButtonDownEvent(event);
                break;
                
            case SDL_JOYBUTTONUP:
                console.handleJoystickButtonUpEvent(event);
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
        display = new Display();
        

        active = false;
        emulationActive = false;
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
            display.dispose();
        
        SDL_Quit();
    }
}


void main(string[] argv)
{
    DerelictSDL2.load();
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
