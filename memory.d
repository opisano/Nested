/*------------------------------------------------------------------------------
    Copyright© 2010 Olivier Pisano    
    
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

module memory;

import ppu;
import controller;

enum MEMORY_SIZE   = 2048;
enum PPU_REGISTERS = 0x2000;
enum APU_REGISTERS = 0x4000;
enum CARTRIDGE_EX  = 0x4020;
enum SRAM          = 0x6000;
enum PRG_ROM       = 0x8000;

struct MemInfo
{
    ushort address;
    ubyte  value;
}


final class CPUMemoryMap
{
private:
    
    /// Nes actual memory : 2kB 
    ubyte[MEMORY_SIZE] memory;
    
    PPU ppu;
    
public:
    
    ControllerState controller1;
    ControllerState controller2;
    
    this(PPU a_ppu)
    {
        ppu = a_ppu;
    }
    
    ubyte opIndex(size_t index)
    {
        // if address is in the RAM
        if (index < MEMORY_SIZE)
        {
            return memory[index];
        }
        // if adress is in the RAM mirrors
        else if (index >= MEMORY_SIZE && index < MEMORY_SIZE * 4)
        {
            return memory[index % MEMORY_SIZE];
        }
        // if adress is in the PPU registers
        else if (index >= PPU_REGISTERS && index < APU_REGISTERS)
        {
            switch (index % 8)
             {   
             case 2:
                 return ppu.status();
                 
             
             default:
                 throw new Exception("Unknown PPU register access");
             }
        }
        
        else if (index >= APU_REGISTERS && index < CARTRIDGE_EX)
        {
            switch (index)
            {
            case 0x4016:
                return controller1.read();
            case 0x4017:
                return controller2.read();
            default:
                throw new Exception("Unknown APU register access"); 
            }
            
        }
        /+
        else if (index >= CARTRIDGE_EX && index < SRAM)
        {
            
        }
        else if (index >= SRAM && index < PRG_ROM)
        {
            
        }
        +/
        else
        {
            throw new Exception("Out of range memory access");
        }
    }
    
    ubyte opIndexAssign(ubyte value, size_t index)
    {
        if (index < MEMORY_SIZE)
        {
            return memory[index] = value;
        }
        // if adress is in the RAM mirrors
        else if (index >= MEMORY_SIZE && index < MEMORY_SIZE * 4)
        {
            return memory[index % MEMORY_SIZE] = value;
        }
        else if (index >= APU_REGISTERS && index < CARTRIDGE_EX)
        {
            switch (index)
            {
            case 0x4016:
                controller1.write(value);
                return value;
            case 0x4017:
                controller2.write(value);
                return value;
            default:
                throw new Exception("Unknown APU register access"); 
            }
        }
        else
        {
            throw new Exception("Out of range memory access");
        }
    }
}
