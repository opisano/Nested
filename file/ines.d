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

module file.ines;

import std.exception;
import std.stdio;

import file.rom;

const(Rom) loadFile(string filename)
{
    enum PRG_PAGE_SIZE = 16_384;
    enum CHR_PAGE_SIZE =  8_192;
    enum TRAINER_SIZE  =    512;
    
    ubyte[16] header;
    Rom rom;
    File f = File(filename, "rb");
    
    // read the beginning of the file, to ensure it is a iNes file
    f.rawRead!(ubyte)(header);
    enforce( header[0..4] == [0x4E, 0x45, 0x53, 0x1A], 
            "File format unknown");
    
    // get PRG size
    enforce(header[4] >= 1 && header[4] <= 64, "incorrect rom PRG size");
    const prgSize = header[4] * PRG_PAGE_SIZE;
    
    // get CHR size
    enforce(header[5] <= 64, "incorrect rom CHR size");
    const chrSize = header[5] * CHR_PAGE_SIZE;
    
    // get mapper
    const ubyte flags6 = header[6];
    rom.mapper = cast(ubyte)(flags6 >> 4 | (header[7] & 0b1111_0000));
    
    // get mirroring 
    if (flags6 & 0b0000_1000)
    {
        rom.mirroring = Mirroring.FOUR_SCREEN;
    }
    else
    {
        if (flags6 & 0b0000_0001)
        {
            rom.mirroring = Mirroring.HORIZONTAL;
        }
        else
        {
            rom.mirroring = Mirroring.VERTICAL;
        }
    }
    
    // is the rom battery saved ? 
    rom.battery = flags6 & 0b0000_0010 ? true : false;
    
    // is a trainer present ?
    bool trainer = flags6 & 0b0000_0100 ? true : false;
    
    // load trainer 
    if (trainer)
    {
        rom.trainer = new ubyte[TRAINER_SIZE];
        f.rawRead!(ubyte)(rom.trainer);
    }
    
    // load prg
    rom.prg = new ubyte[prgSize];
    f.rawRead!(ubyte)(rom.prg);
    
    // load chr
    rom.chr = new ubyte[chrSize];
    f.rawRead!(ubyte)(rom.chr);
    
    return rom;
}
