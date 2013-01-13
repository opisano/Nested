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

module ppu;

import derelict.sdl.sdl;
import core.bitop;

/**
 * The tile is the base unit in NES graphics. 
 * It is an 8x8 image whose pixels are coded by two bits.
 * First pixels is coded in the first 8 bytes while the second is coded in the 
 * next eight bytes.
 */
struct Tile
{
private:
    static immutable uint[8] tile_mask = [128, 64, 32, 16, 8, 4, 2, 1];

    /** Pixel data */
    ubyte[16] m_data; 
    
public:
    /** Read access to the pixels */
    ubyte opIndex(size_t y, size_t x) const
    in
    {
        assert (y < 8);
        assert (x < 8);
    }
    out (result)
    {
        assert (result < 4);
    }
    body
    {
        ubyte value = m_data[x] & tile_mask[y] ? 1 : 0;
        value |= (m_data[8+x] & tile_mask[y] ? 1 : 0) << 1;
        
        return value;
    }
    
    /** Write access to the pixels */
    ubyte opIndexAssign(uint value, size_t y, size_t x)
    in
    {
        assert (y < 8);
        assert (x < 8);
    }
    out (result)
    {
        assert (result < 4);
    }
    body
    {
        value &= 0b0000_0011;
        if (value & 0b0000_0001)
            m_data[x] |= tile_mask[y];
        else
            m_data[x] &= ~(tile_mask[y]);
        
        if (value & 0b0000_0010)
            m_data[8+x] |= tile_mask[y];
        else
            m_data[8+x] &= ~(tile_mask[y]);
        
        return cast(ubyte) value;
    }
}

struct OAM
{
    ubyte top;
    ubyte tileIndex;
    
    /**
     *  x+$02: Attributes
     *  76543210
     *  ||||||||
     *  ||||||++- Palette (4 to 7) of sprite
     *  |||+++--- Unused
     *  ||+------ Priority (0: in front of background; 1: behind background)
     *  |+------- Flip hoizontally?
     *  +-------- Flip vertically?
     */
    ubyte attributes;
    ubyte left;
    
    int palette() nothrow
    out (result)
    {
        assert (palette >= 4 && palette <= 7);
    }
    body
    {
        return 4 + attributes & 0b0000_0011;
    }
    
    bool isHFlipped() nothrow { return (attributes & 0b0100_0000) != 0; }
    
    bool isVFlipped() nothrow { return (attributes & 0b1000_0000) != 0; }
    
    bool isPrioritary() nothrow { return (attributes & 0b0010_0000) != 0; }
}

unittest
{
    assert (Tile.sizeof == 16);
    Tile t;
    foreach (x; 0..8)
    {
        foreach(y; 0..8)
        {
            foreach (m; 0..4)
            {
                t[x, y] = m;
                assert (t[x, y] == m);
            }
        }
    }
}

enum SpriteSize
{
    SINGLE,
    DOUBLE
}

/**
 * Checks value is in range [lower, upper[.
 */
bool between(uint value, uint lower, uint upper) pure nothrow
{
    return (lower <= value && upper > value);
}

uint hsvToRgb(ubyte hsv) pure nothrow
{
    // correspondance between NES palette index and RRGGBB values
    static immutable uint[64] COLORS = [
        0x788084, 0x0000fc, 0x0000c4, 0x4028c4,
        0x94008c, 0xac0028, 0xac1000, 0x8c1800,
        0x503000, 0x007800, 0x006800, 0x005800,
        0x004058, 0x000000, 0x000000, 0x000008,

        0xbcc0c4, 0x0078fc, 0x0088fc, 0x6848fc,
        0xdc00d4, 0xe40060, 0xfc3800, 0xe46018,
        0xac8000, 0x00b800, 0x00a800, 0x00a848,
        0x008894, 0x2c2c2c, 0x000000, 0x000000, 

        0xfcf8fc, 0x38c0fc, 0x6888fc, 0x6848fc,
        0xfc78fc, 0xfc589c, 0xfc7858, 0xfca048,
        0xfcb800, 0xbcf818, 0x58d858, 0x58f89c,
        0x00e8e4, 0x606060, 0x000000, 0x000000,

        0xfcf8fc, 0xa4e8fc, 0xbcb8fc, 0xdcb8fc,
        0xfcb8fc, 0xf4c0e0, 0xf4d0b4, 0xfce0b4,
        0xfcd884, 0xdcf878, 0xb8f878, 0xb0f0d8,
        0x00f8fc, 0xc8c0c0, 0x000000, 0x000000
    ];

    return COLORS[hsv & 0b0011_1111];
}

enum TableMirroring
{
    HORIZONTAL,
    VERTICAL,
    SINGLE_SCREEN,
    FOUR_SCREEN
}

/**
* Performs a read in a pattern table and returns a 8x8 tile where each pixel 
* least significant two bits are filled.
*/
void patternTableAccess(ubyte[] memory, out ubyte[64] tile)
in
{
    assert (memory.length == 16);
}
body
{
    uint BT(uint* p, size_t bitnum)
    {
        return bt(p, bitnum) ? 1 : 0;
    }

    for (size_t i = 0; i < 8; ++i)
    {
        uint row1  = memory[i];
        uint row2  = memory[i+8];

        tile[i*8]   = cast(ubyte)(BT(&row1, 7) | (BT(&row2, 7) << 1)); 
        tile[i*8+1] = cast(ubyte)(BT(&row1, 6) | (BT(&row2, 6) << 1));
        tile[i*8+2] = cast(ubyte)(BT(&row1, 5) | (BT(&row2, 5) << 1));
        tile[i*8+3] = cast(ubyte)(BT(&row1, 4) | (BT(&row2, 4) << 1));
        tile[i*8+4] = cast(ubyte)(BT(&row1, 3) | (BT(&row2, 3) << 1));
        tile[i*8+5] = cast(ubyte)(BT(&row1, 2) | (BT(&row2, 2) << 1));
        tile[i*8+6] = cast(ubyte)(BT(&row1, 1) | (BT(&row2, 1) << 1));
        tile[i*8+7] = cast(ubyte)(BT(&row1, 0) | (BT(&row2, 0) << 1));
    }
}

void attributeTableAccess(ubyte tableValue, out ubyte[4] tiles)
{
    tiles[0] = tableValue & 0b0000_0011;
    tiles[1] = (tableValue & 0b0000_1100) >> 2;
    tiles[2] = (tableValue & 0b0011_0000) >> 4;
    tiles[3] = (tableValue & 0b1100_0000) >> 6;
}

unittest
{
    ubyte[16] patterns = [  0b00010000,
    0b00000000,
    0b01000100,
    0b00000000,
    0b11111110,
    0b00000000,
    0b10000010,
    0b00000000,

    0b00000000,
    0b00101000,
    0b01000100,
    0b10000010,
    0b00000000,
    0b10000010,
    0b10000010,
    0b00000000 ];

    ubyte[64] expected = [  0, 0, 0, 1, 0, 0, 0, 0,
    0, 0, 2, 0, 2, 0, 0, 0,
    0, 3, 0, 0, 0, 3, 0, 0,
    2, 0, 0, 0, 0, 0, 2, 0,
    1, 1, 1, 1, 1, 1, 1, 0,
    2, 0, 0, 0, 0, 0, 2, 0,
    3, 0, 0, 0, 0, 0, 3, 0,
    0, 0, 0, 0, 0, 0, 0, 0 ];

    ubyte[64] ub;
    patternTableAccess(patterns, ub);
    assert(ub == expected);
}


/**
 * Modelizes the Picture Processing Unit of the NES
 */
final class PPU
{
private:
    ubyte[0x2000] m_patternTables;
    ubyte[0x400]  m_nameAttrTable1;
    ubyte[0x400]  m_nameAttrTable2;
    ubyte[0x20]   m_palette;
    ubyte[0x100]  m_spriteRAM;


    static immutable nametableAdresses = [0x2000, 0x2400, 0x2800, 0x2C00];
    
    
    
    size_t baseNameTableAddress;
    
    size_t vramAddressIncrement;
    
    size_t spritePatternTableAddress;
    
    size_t bgPatternTableAddress;
    
    SpriteSize spriteSize;
    
    bool verticalBlankNMIGeneration;    

    TableMirroring mirroring;
    
public:

    ubyte opIndex(size_t index) const
    {
        // global mirroring
        if (index >= 0x4000)
            index %= 0x4000;

        // name table mirroring
        if (index.between(0x3000, 0x3F00))
        {
            index -= 0x1000;
        }
        // palette mirroring
        else if (index.between(0x3F20, 0x4000))
        {
            size_t offset = 0x3F20 - index;
            offset %= 0x20;
            index = 0x3F00 + offset;
        }

        // Access to pattern tables
        if (index < 0x2000)
            return m_patternTables[index];

        // Access to name/attribute tables
        if (index.between(0x2000, 0x3000))
        {
            final switch (mirroring)
            {
            case TableMirroring.HORIZONTAL:
                if (index.between(0x2000, 0x2800)) // Access Table 1
                {
                    int offset = index - 0x2000;
                    // suppress mirroring
                    offset = offset > 0x400 ? (offset - 0x400) : offset;
                    return m_nameAttrTable1[offset];
                }
                else // Access Table 2
                {
                    int offset = index - 0x2800;
                    // suppress mirroring
                    offset = offset > 0x400 ? (offset - 0x400) : offset;
                    return m_nameAttrTable2[offset];
                }
            case TableMirroring.VERTICAL:
                // suppress mirroring
                index = index > 0x2800 ? (index - 0x800) : index;
                if (index.between(0x2000, 0x2400)) // Access Table 1
                {
                    return m_nameAttrTable1[index-0x2000];
                }
                else // Access Table 2
                {
                    return m_nameAttrTable2[index-0x2400];
                }

            case TableMirroring.SINGLE_SCREEN:
                while (index >= 0x2400)
                {
                    index -= 0x400;
                }
                return m_nameAttrTable1[index-0x2000];

            case TableMirroring.FOUR_SCREEN:
                return 0; // Not implemented yet
            }            
        }

        if (index.between(0x3F00, 0x3F20))
            return m_palette[index - 0x3F00];

        return 0;
    }
    
    /**
     * PPU control (write)
     *  76543210
     *  ||||||||
     *  ||||||++- base nametable address
     *  ||||||    (00 = $2000; 01 = $2400; 02 = $2800; 03 = $2c00)
     *  |||||+--- VRAM address increment
     *  |||||     (0: increment by 1, going across; 1: increment by 32, going down)
     *  ||||+---- Sprite pattern table address for 8x8 sprites (0: $0000; 1: $1000)
     *  |||+----- Background pattern table address (0: $0000; 1: $1000)
     *  ||+------ Sprite size (0: 8x8 sprites; 1: 8x16 sprites)
     *  |+------- PPU layer select (should always be 0 in the NES; some Nintendo
     *  |         arcade boards presumably had two PPUs)
     *  +-------- Vertical blank NMI generation (0: off; 1: on)
     */
    void control(ubyte value)
    {
        static immutable size_t[4] bnta = [0x2000, 0x2400, 0x2800, 0x2C00];
        
        baseNameTableAddress = bnta[value & 0b0000_0011];
        vramAddressIncrement = value & 0b0000_0100 ? 32 : 1;
        spritePatternTableAddress = value & 0b0000_1000 ? 0x1000 : 0;
        bgPatternTableAddress = value & 0b0001_0000 ? 0x1000 : 0;
        spriteSize = value & 0b0010_0000 ? SpriteSize.DOUBLE : SpriteSize.SINGLE;
        verticalBlankNMIGeneration = (value & 0b1000_0000) != 0;
        
        lastWritten = value;
    }
    
    bool grayscale;
    
    bool showLeftMostBackground;
    
    bool showLeftMostSprites;
    
    bool showBackground;
    
    bool showSprites;
    
    bool intensifyReds;
    
    bool intensifyGreens;
    
    bool intensifyBlues;

    /**
     * Mask
     * 76543210
     * ||||||||
     * |||||||+- Grayscale (0: normal color; 1: produce a monochrome display)
     * ||||||+-- 1: Show background in leftmost 8 pixels of screen; 0: Hide
     * |||||+--- 1: Show sprites in leftmost 8 pixels of screen; 0: Hide
     * ||||+---- 1: Show background
     * |||+----- 1: Show sprites
     * ||+------ Intensify reds (and darken other colors)
     * |+------- Intensify greens (and darken other colors)
     * +-------- Intensify blues (and darken other colors)
     */
    void mask(ubyte value)
    {
        grayscale              = value & 1;
        showLeftMostBackground = value & 0b0000_0010 ? true : false;
        showLeftMostSprites    = value & 0b0000_0100 ? true : false;
        showBackground         = value & 0b0000_1000 ? true : false;
        showSprites            = value & 0b0001_0000 ? true : false;
        intensifyReds          = value & 0b0010_0000 ? true : false;
        intensifyGreens        = value & 0b0100_0000 ? true : false;
        intensifyBlues         = value & 0b1000_0000 ? true : false;
        
        lastWritten = value;
    }
    
    ubyte lastWritten;
    
    bool spriteOverflow;
    
    bool sprite0Hit;
    
    bool inVBlank;
    
    /**
     * Status
     * 76543210
     * ||||||||
     * |||+++++- Least significant bits previously written into a PPU register
     * |||       (due to register not being updated for this address)
     * ||+------ Sprite overflow. The PPU can handle only eight sprites on one
     * ||        scanline and sets this bit if it starts dropping sprites.
     * ||        Normally, this triggers when there are 9 sprites on a scanline,
     * ||        but the actual behavior is significantly more complicated.
     * |+------- Sprite 0 Hit.  Set when a nonzero pixel of sprite 0 'hits'
     * |         a nonzero background pixel.  Used for raster timing.
     * +-------- Vertical blank has started (0: not in VBLANK; 1: in VBLANK)
     */
    ubyte status()
    {
        ubyte value = lastWritten & 0b0001_1111;
        
        if (spriteOverflow)
            value |= 0b0010_0000;
        
        if (sprite0Hit)
            value |= 0b0100_0000;
        
        if (inVBlank)
            value |= 0b1000_0000;
        
        return value;
    }
    
    ubyte oamAddress;
    
    ubyte oamData;
    
    ubyte scroll;
    
    ubyte address;
    
    ubyte data;
    
    void draw(ref SDL_Surface display)
    in
    {
        assert (display.w == 256);
        assert (display.h == 240);
    }
    body
    {
        
    }
}
