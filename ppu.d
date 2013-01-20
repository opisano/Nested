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

module ppu;

import derelict.sdl.sdl;
import core.bitop;

enum TILES_PER_ROW      = 32;
enum TILES_PER_COL      = 30;
enum PATTERN_TILE_SIZE  = 16;

enum ATTR_TABLE_INDEX = buildAttrTableIndex();


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
    // correspondance between NES palette index and BBGGRR values
    static immutable uint[64] COLORS = [
        0x848078, 0xfc0000, 0xc40000, 0xc42840,
        0x8c0094, 0x2800ac, 0x0010ac, 0x00188c,
        0x003050, 0x007800, 0x006800, 0x005800,
        0x584000, 0x000000, 0x000000, 0x080000,

        0xc4c0bc, 0xfc7800, 0xfc8800, 0xfc4868,
        0xd400dc, 0x6000e4, 0x0038fc, 0x1860e4,
        0x0080ac, 0x00b800, 0x00a800, 0x48a800,
        0x948800, 0x2c2c2c, 0x000000, 0x000000, 

        0xfcf8fc, 0xfcc038, 0xfc8868, 0xfc4868,
        0xfc78fc, 0x9c58fc, 0x5878fc, 0x48a0fc,
        0x00b8fc, 0x18f8bc, 0x58d858, 0x9cf858,
        0xe4e800, 0x606060, 0x000000, 0x000000,

        0xfcf8fc, 0xfce8a4, 0xfcb8bc, 0xfcb8dc,
        0xfcb8fc, 0xe0c0f4, 0xb4d0f4, 0xb4e0fc,
        0x84d8fc, 0x78f8dc, 0x78f8b8, 0xd8f0b0,
        0xfcf800, 0xc0c0c8, 0x000000, 0x000000
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

ubyte[960] buildAttrTableIndex()
{
    ubyte[960] t;

    foreach (j; 0..TILES_PER_COL)
    {
        foreach (i; 0..TILES_PER_ROW)
        {
            auto index = j * TILES_PER_ROW + i;
            t[index] = cast(ubyte)((i / 4) % (TILES_PER_ROW/4) + (index / TILES_PER_ROW*4)*8);
        }
    }

    return t;
}

/**
* Performs a read in a pattern table and returns a 8x8 tile where each pixel 
* least significant two bits are filled.
* @param memory 16 bytes chunk from pattren table memory
* @param tile a 8x8 memory block 
*/
void patternTableAccess(const ubyte[] memory, out ubyte[64] tile)
in
{
    assert (memory.length == 16);
}
out
{
    // check only the 2 least significant bits are set
    foreach (b; tile)
        assert (b < 4);
}
body
{
    // test a bit
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




ubyte attributeTableAccess(const ubyte[] attrTable, size_t xTile, size_t yTile)
in
{
    assert (attrTable.length == 64);
    assert (xTile < 32);
    assert (yTile < 30);
}
out (result)
{
    assert (result < 4);
}
body
{
    enum SQUARES = [0, 0, 1, 1,
                    0, 0, 1, 1,
                    2, 2, 3, 3,
                    2, 2, 3, 3];

    size_t indexTile = yTile * TILES_PER_ROW + xTile;
    size_t indexAttr = ATTR_TABLE_INDEX[indexTile];

    ubyte attrValue = attrTable[indexAttr];
    xTile &= 3;
    yTile &= 3;

    final switch(SQUARES[yTile*4+xTile])
    {
    case 0:
        return attrValue & 0b0000_0011;
    case 1:
        return (attrValue & 0b0000_1100) >> 2;
    case 2:
        return (attrValue & 0b0011_0000) >> 4;
    case 3:
        return (attrValue & 0b1100_0000) >> 6;
    }
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

    ubyte m_spriteRAMAddress;

    static immutable nametableAdresses = [0x2000, 0x2400, 0x2800, 0x2C00];
    
    
    
    size_t baseNameTableAddress;
    
    size_t vramAddressIncrement;
    
    size_t spritePatternTableAddress;
    
    size_t bgPatternTableAddress;
    
    SpriteSize spriteSize;

    TableMirroring mirroring;
    
    bool verticalBlankNMIGeneration;

    SDL_Surface* bg0;

    SDL_Surface* bg1;

    SDL_Surface* sdlTile;

    void drawNameTable(const ubyte[] nameTable, SDL_Surface* bg)
    in
    {
        assert (nameTable !is null);
        assert (bg !is null);
        assert (nameTable.length == 1024);
    }
    body
    {
        for (size_t y = 0; y < TILES_PER_COL; ++y)
        {
            ubyte msb;
            for (size_t x = 0; x < TILES_PER_ROW; ++x)
            {
                ubyte[64] tile;

                // Get address of tile in the pattern tables
                size_t name_addr = (y * TILES_PER_ROW) + x;
                size_t tile_addr = bgPatternTableAddress + nameTable[name_addr] * PATTERN_TILE_SIZE;
                assert (tile_addr < 0x2000);

                // Get two lower bits from the pattern tables
                patternTableAccess(m_patternTables[tile_addr..tile_addr+16], tile);

                // Get the upper bits from the attributes table
                if ((x & 1 ) == 0)
                    msb = cast(ubyte)(attributeTableAccess(nameTable[960..1024], x, y) << 2);
                tile[] |= msb;

                // Draw tile to SDL surface
                SDL_LockSurface(bg);
                foreach (offset; 0..64)
                {
                    (cast(uint*)(*sdlTile).pixels)[offset] = hsvToRgb(tile[offset]);
                }
                SDL_UnlockSurface(sdlTile);

                // blit tile to background
                SDL_Rect dstRect = {cast(short)(x * 8), cast(short)(y * 8), 8, 8};
                SDL_BlitSurface(sdlTile, null, bg, &dstRect);
            }
        }
    }

    void drawBackground(ref SDL_Surface display)
    {
        drawNameTable(m_nameAttrTable1[], bg0);

        if (mirroring == TableMirroring.SINGLE_SCREEN
                || (horizontalScroll == 0 && verticalScroll == 0))
        {
            SDL_BlitSurface(bg0, null, &display, null);
            return;
        }
        else
        {
            drawNameTable(m_nameAttrTable2[], bg1);
            switch (mirroring)
            {
            case TableMirroring.HORIZONTAL:
                {
                    SDL_Rect dstRect = {cast(short)-horizontalScroll, cast(short)-verticalScroll};
                    SDL_BlitSurface(bg0, null, &display, &dstRect);
                    dstRect.x += 256;
                    SDL_BlitSurface(bg0, null, &display, &dstRect);
                    dstRect.y += 240;
                    SDL_BlitSurface(bg1, null, &display, &dstRect);
                    dstRect.x -= 256;
                    SDL_BlitSurface(bg1, null, &display, &dstRect);
                }
            case TableMirroring.VERTICAL:
                {
                    SDL_Rect dstRect = {cast(short)-horizontalScroll, cast(short)-verticalScroll};
                    SDL_BlitSurface(bg0, null, &display, &dstRect);
                    dstRect.x += 256;
                    SDL_BlitSurface(bg1, null, &display, &dstRect);
                    dstRect.y += 240;
                    SDL_BlitSurface(bg0, null, &display, &dstRect);
                    dstRect.x -= 256;
                    SDL_BlitSurface(bg1, null, &display, &dstRect);
                }
            default:
                // not supported
            }
        }
    }

    void drawSprites(ref SDL_Surface display)
    {

    }
    
public:

    this()
    {
        bg0 = SDL_CreateRGBSurface(SDL_HWSURFACE, 256, 240, 32,
                                   0xFF, 0xFF00, 0xFF0000, 0xFF000000);
    }

    ubyte opIndex(size_t index) const
    {
        // global mirroring
        index &= 0x3FFF; //index %= 0x4000;

        // name table mirroring
        if (index.between(0x3000, 0x3F00))
        {
            index -= 0x1000;
        }
        // palette mirroring
        else if (index.between(0x3F20, 0x4000))
        {
            size_t offset = 0x3F20 - index;
            offset &= 0x1F;
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

    ubyte opIndexAssign(ubyte value, size_t index)
    {
        // global mirroring
        index &= 0x3FFF; //index %= 0x4000;

        // name table mirroring
        if (index.between(0x3000, 0x3F00))
        {
            index -= 0x1000;
        }
        // palette mirroring
        else if (index.between(0x3F20, 0x4000))
        {
            size_t offset = 0x3F20 - index;
            offset &= 0x1F;
            index = 0x3F00 + offset;
        }

        // Access to pattern tables
        if (index < 0x2000)
            return m_patternTables[index] = value;


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
                        return m_nameAttrTable1[offset] = value;
                    }
                    else // Access Table 2
                    {
                        int offset = index - 0x2800;
                        // suppress mirroring
                        offset = offset > 0x400 ? (offset - 0x400) : offset;
                        return m_nameAttrTable2[offset] = value;
                    }
                case TableMirroring.VERTICAL:
                    // suppress mirroring
                    index = index > 0x2800 ? (index - 0x800) : index;
                    if (index.between(0x2000, 0x2400)) // Access Table 1
                    {
                        return m_nameAttrTable1[index-0x2000] = value;
                    }
                    else // Access Table 2
                    {
                        return m_nameAttrTable2[index-0x2400] = value;
                    }

                case TableMirroring.SINGLE_SCREEN:
                    while (index >= 0x2400)
                    {
                        index -= 0x400;
                    }
                    return m_nameAttrTable1[index-0x2000] = value;

                case TableMirroring.FOUR_SCREEN:
                    return 0; // Not implemented yet
            }            
        }

        if (index.between(0x3F00, 0x3F20))
            return m_palette[index - 0x3F00] = value;

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

    ubyte verticalScroll;

    ubyte horizontalScroll;

    ushort vramAddress;

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

    /**
     * 0x2003.
     * Sets the address in SPR-RAM to access on the next write to 0x2004.
     */
    ubyte spriteRAMAddress(ubyte value)
    {
        // lastWritten = value; ?
        return m_spriteRAMAddress = value;
    }

    /**
     * 0x2004.
     * Writes a byte in SPR-RAM at the address indicated by 0x2003.
     */
    ubyte spriteRAMValue(ubyte value)
    {
        // lastWritten = value; ?
        return m_spriteRAM[m_spriteRAMAddress] = value;
    }

    /**
     * 0x2005.
     * There are two scroll registers, vertical and horizontal, 
     * which are both written via this port. The first value written
     * will go into the Vertical Scroll Register (unless it is >239,
     * then it will be ignored). The second value will appear in the
     * Horizontal Scroll Register. Name Tables are assumed to be
     * arranged in the following way:
     *   +-----------+-----------+
     *   | 2 ($2800) | 3 ($2C00) |
     *   +-----------+-----------+
     *   | 0 ($2000) | 1 ($2400) |
     *   +-----------+-----------+
     * When scrolled, the picture may span over several Name Tables.
     * Remember that because of the mirroring there are only 2 real
     * Name Tables, not 4. 
     */
    ubyte scroll(ubyte value)
    {
        // identifies wether the write concerns the vertical or horizontal 
        // scroll register
        static bool horizontal = false;

        if (!horizontal && value > 239)
        {
            verticalScroll = value;
            horizontal = !horizontal;
        }
        else
        {
            horizontalScroll = value;
            horizontal = !horizontal;
        }

        return value;
    }

    /**
     * 0x2006.
     * Used to set the address of PPU Memory to be accessed via
     * $2007. The first write to this register will set 8 lower
     * address bits. The second write will set 6 upper bits. The
     * address will increment either by 1 or by 32 after each
     * access to $2007 (see "PPU Memory").
     */
    ubyte memoryAddress(ubyte value)
    {
        // indentifies wether the write concerns lower or upper bits
        static bool upperBits = false;

        if (!upperBits)
        {
            vramAddress = (vramAddress & 0xFF00) | value;
        }
        else
        {
            vramAddress = (vramAddress & 0xFF) | ((value & 0x3F) << 8);
        }

        return value;
    }

    /**
     * 0x2007
     * Used to read the PPU Memory. The address is set via
     * $2006 and increments after each access, either by 1 or by 32

     */
    ubyte memoryData()
    {
        ubyte b = this[vramAddress];
        vramAddress += vramAddressIncrement;
        return b;
    }

    /**
    * 0x2007
    * Used to write the PPU Memory. The address is set via
    * $2006 and increments after each access, either by 1 or by 32
    */
    ubyte memoryData(ubyte value)
    {
        this[vramAddress] = value;
        vramAddress += vramAddressIncrement;
        return value;
    }    

    void writeSpriteRam(ubyte value, size_t address)
    {
        m_spriteRAM[address] = value;
    }
    
    void draw(ref SDL_Surface display)
    in
    {
        assert (display.w == 256);
        assert (display.h == 240);
    }
    body
    {
        if (showBackground)
        {
            drawBackground(display);
        }

        if (showSprites)
        {
            drawSprites(display);
        }
    }
}
