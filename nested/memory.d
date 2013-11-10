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

module memory;

import cpu;
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

    /// PRG ROM (game data)
    ubyte[0x8000] prgRom;
    
    PPU ppu;
    CPU cpu;
    
public:
    
    ControllerState controller1;
    ControllerState controller2;
    
    this(CPU a_cpu, PPU a_ppu)
    {
        ppu = a_ppu;
        cpu = a_cpu;
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
            switch (index & 7)
             {   
             case 2:
                 return ppu.status();

             case 7:
                 return ppu.memoryData();
                 
             
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
        else // if address is in PRG-ROM
        {
            size_t offset = index - PRG_ROM;
            return prgRom[offset];
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
        // if adress is in the PPU registers
        else if (index >= PPU_REGISTERS && index < APU_REGISTERS)
        {
            switch (index & 7)
            {
            case 0:
                ppu.control(value);
                return value;

            case 1:
                ppu.mask(value);
                return value;

            case 3:
                return ppu.spriteRAMAddress(value);

            case 4:
                return ppu.spriteRAMValue(value);

            case 5:
                return ppu.scroll(value);

            case 6:
                return ppu.memoryAddress(value);

            case 7:
                return ppu.memoryData(value);

            default:
                throw new Exception("Unknown PPU register access");
            }
        }
        else if (index >= APU_REGISTERS && index < CARTRIDGE_EX)
        {
            switch (index)
            {
            case 0x4014:
                {
                    size_t addr = value << 8;
                    for (size_t offset = 0; offset < 0xFF; ++offset)
                    {
                        ppu.writeSpriteRam(this[addr+offset], offset);
                    }
                    cpu.dmaOccured();
                }
                return value;
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

    /**
     * Loads a 1-bank or 2-bank Prg rom into CPU memory space.
     * @param firstBank The prg rom first bank. Must be 16k long.
     * @param secondBank The prg rom second bank 
     * (can be null if the rom does not have a second bank). Must be 16k long.
     */
    void loadPrgRom(const ubyte[] firstBank, const ubyte[] secondBank)
    in
    {
        assert(firstBank.length == 16_384);
        assert(secondBank is null || secondBank.length == 16_384);
    }
    body
    {
        prgRom[0..0x4000] = firstBank[0..0x4000];
        if (secondBank is null)
            prgRom[0x4000..0x8000] = firstBank[0..0x4000];
        else
            prgRom[0x4000..0x8000] = secondBank[0..0x4000];
    }
}
