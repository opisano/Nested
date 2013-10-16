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

import std.algorithm;

import common;

enum TILES_PER_ROW      = 32;
enum TILES_PER_COL      = 30;
enum PATTERN_TILE_SIZE  = 16;

enum ATTR_TABLE_INDEX = buildAttrTableIndex();
    
bool isOAMHFlipped(ubyte attributes) pure nothrow { return (attributes & 0b0100_0000) != 0; }
    
bool isOAMVFlipped(ubyte attributes) pure nothrow { return (attributes & 0b1000_0000) != 0; }
    
bool isOAMPrioritary(ubyte attributes) pure nothrow { return (attributes & 0b0010_0000) != 0; }


enum SpriteSize
{
    SINGLE,
    DOUBLE
}

/+
/**
 * Checks value is in range [lower, upper[.
 */
bool between(uint value, uint lower, uint upper) pure nothrow
{
    return (lower <= value && upper > value);
}+/



uint hsvToRgb(ubyte hsv) pure nothrow
{
    // correspondance between NES palette index and BBGGRR values
    static immutable uint[64] COLORS = [
        0xFF848078, 0xFFfc0000, 0xFFc40000, 0xFFc42840,
        0xFF8c0094, 0xFF2800ac, 0xFF0010ac, 0xFF00188c,
        0xFF003050, 0xFF007800, 0xFF006800, 0xFF005800,
        0xFF584000, 0xFF000000, 0xFF000000, 0xFF080000,

        0xFFc4c0bc, 0xFFfc7800, 0xFFfc8800, 0xFFfc4868,
        0xFFd400dc, 0xFF6000e4, 0xFF0038fc, 0xFF1860e4,
        0xFF0080ac, 0xFF00b800, 0xFF00a800, 0xFF48a800,
        0xFF948800, 0xFF2c2c2c, 0xFF000000, 0xFF000000, 

        0xFFfcf8fc, 0xFFfcc038, 0xFFfc8868, 0xFFfc4868,
        0xFFfc78fc, 0xFF9c58fc, 0xFF5878fc, 0xFF48a0fc,
        0xFF00b8fc, 0xFF18f8bc, 0xFF58d858, 0xFF9cf858,
        0xFFe4e800, 0xFF606060, 0xFF000000, 0xFF000000,

        0xFFfcf8fc, 0xFFfce8a4, 0xFFfcb8bc, 0xFFfcb8dc,
        0xFFfcb8fc, 0xFFe0c0f4, 0xFFb4d0f4, 0xFFb4e0fc,
        0xFF84d8fc, 0xFF78f8dc, 0xFF78f8b8, 0xFFd8f0b0,
        0xFFfcf800, 0xFFc0c0c8, 0xFF000000, 0xFF000000
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
 * CTFE-only function that builds a tile index to attribute table index
 * mapping
 */
private ubyte[960] buildAttrTableIndex()
{
    ubyte[960] t;

    foreach (j; 0..TILES_PER_COL)
    {
        foreach (i; 0..TILES_PER_ROW)
        {
            auto index = j * TILES_PER_ROW + i;
            t[index] = cast(ubyte)((i / 4) % (TILES_PER_ROW/4) 
                                   + (index / TILES_PER_ROW*4)*8);
        }
    }

    return t;
}

/**
 * CTFE-only function that builds a bit to byte look up table 
 */
private ulong[256] buildBitToByteTable()
{
    ulong[256] result;

    foreach (num; 0..256)
    {
        ulong value;
        foreach (bit; 0..8)
        {
            ulong bitvalue = (num & (1 << bit)) >> bit;
            value |= (bitvalue << ((7-bit) *8));
        }
        result[num] = value;
    }
    return result;
}


private enum bitToByte = buildBitToByteTable();


/**
* Performs a read in a pattern table and returns a 8x8 tile where each pixel 
* least significant two bits are filled.
* @param memory 16 bytes chunk from pattern table memory
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
    for (size_t i = 0; i < 8; ++i)
    {   
        // Use lookup table to get byte equivalents to bits in memory[i]
        auto row1 = bitToByte[memory[i]];
        auto row2 = bitToByte[memory[i+8]];
        void* presult = &tile[i*8];
        *(cast(ulong*)presult) = row1 | (row2 << 1);
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
 * Flips a tile horizontally
 */
void hflip(ref ubyte[64] tile) pure
{
    auto original = tile.idup;
    for (size_t x = 0; x < 8; ++x)
    {
        for (size_t y = 0; y < 8; ++y)
        {
            tile[y*8+x] = original[y*8+(7-x)];
        }
    }
}


unittest
{
    ubyte[64] original = [  0, 0, 0, 1, 0, 0, 0, 0,
                            0, 0, 2, 0, 2, 0, 0, 0,
                            0, 3, 0, 0, 0, 3, 0, 0,
                            2, 0, 0, 0, 0, 0, 2, 0,
                            1, 1, 1, 1, 1, 1, 1, 0,
                            2, 0, 0, 0, 0, 0, 2, 0,
                            3, 0, 0, 0, 0, 0, 3, 0,
                            0, 0, 0, 0, 0, 0, 0, 0 ];

    ubyte[64] expected = [  0, 0, 0, 0, 1, 0, 0, 0, 
                            0, 0, 0, 2, 0, 2, 0, 0, 
                            0, 0, 3, 0, 0, 0, 3, 0, 
                            0, 2, 0, 0, 0, 0, 0, 2, 
                            0, 1, 1, 1, 1, 1, 1, 1, 
                            0, 2, 0, 0, 0, 0, 0, 2, 
                            0, 3, 0, 0, 0, 0, 0, 3, 
                            0, 0, 0, 0, 0, 0, 0, 0 ];

    hflip(original);
    assert (original == expected);
}

/**
 * Flips a tile vertically
 */
void vflip(ref ubyte[64] tile) pure
{
    auto original = tile.idup;
    for (size_t line = 0; line < 8; ++line)
    {
        size_t tile_idx = line *8;
        size_t orig_idx = (7-line)*8;
        tile[tile_idx..tile_idx+8] = original[orig_idx..orig_idx+8];
    }
}

unittest
{
    ubyte[64] original = [  0, 0, 0, 1, 0, 0, 0, 0,
                            0, 0, 2, 0, 2, 0, 0, 0,
                            0, 3, 0, 0, 0, 3, 0, 0,
                            2, 0, 0, 0, 0, 0, 2, 0,
                            1, 1, 1, 1, 1, 1, 1, 0,
                            2, 0, 0, 0, 0, 0, 2, 0,
                            3, 0, 0, 0, 0, 0, 3, 0,
                            0, 0, 0, 0, 0, 0, 0, 0 ];

    ubyte[64] expected  = [ 0, 0, 0, 0, 0, 0, 0, 0,
                            3, 0, 0, 0, 0, 0, 3, 0,
                            2, 0, 0, 0, 0, 0, 2, 0,
                            1, 1, 1, 1, 1, 1, 1, 0,
                            2, 0, 0, 0, 0, 0, 2, 0,
                            0, 3, 0, 0, 0, 3, 0, 0,
                            0, 0, 2, 0, 2, 0, 0, 0,
                            0, 0, 0, 1, 0, 0, 0, 0 ];

    vflip(original);
    assert (original == expected);
}

struct SpriteInfo
{    
    bool        priority;
    ubyte       index;
    ubyte       left;
    ubyte       top;

    private int priorityScore() const
    {
        int score = priority ? -100 : 0;
        score -= index;
        return score;
    }

    int opCmp(const ref SpriteInfo other) const
    {
        return priorityScore() - other.priorityScore();
    }
}

SpriteInfo[64] m_spriteinfos;

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

    /// 256×240 nametable1
    SDL_Surface* bg0;

    /// 256×240 nametable2
    SDL_Surface* bg1;

    /// 512×16 sprites
    SDL_Surface* sprites;

    SDL_Surface* sdlTile;

    bool needRedraw;

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
                SDL_LockSurface(sdlTile);
                foreach (offset; 0..64)
                {
                    (cast(uint*)(*sdlTile).pixels)[offset] = selectColor(tile[offset]);
                }
                SDL_UnlockSurface(sdlTile);

                // blit tile to background
                SDL_Rect dstRect = {cast(short)(x * 8), cast(short)(y * 8), 8, 8};
                SDL_BlitSurface(sdlTile, null, bg, &dstRect);
            }
        }
    }

    /**
     * Get a ABGR color from a palette color index.
     */
    uint selectColor(ubyte colorIndex) const nothrow
    in
    {
        assert (colorIndex < 32);
    }
    body
    {
        if ((colorIndex & 3) == 0)
            return 0x00000000;

        ubyte paletteEntry = m_palette[colorIndex];
        return hsvToRgb(paletteEntry);
    }

    void drawBackground(SDL_Surface* display)
    {
        if (needRedraw)
        {
            drawNameTable(m_nameAttrTable1[], bg0);

            if (mirroring == TableMirroring.SINGLE_SCREEN
                    || (horizontalScroll == 0 && verticalScroll == 0))
            {
                SDL_BlitSurface(bg0, null, display, null);
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
                        SDL_BlitSurface(bg0, null, display, &dstRect);
                        dstRect.x += 256;
                        SDL_BlitSurface(bg0, null, display, &dstRect);
                        dstRect.y += 240;
                        SDL_BlitSurface(bg1, null, display, &dstRect);
                        dstRect.x -= 256;
                        SDL_BlitSurface(bg1, null, display, &dstRect);
                    }
                case TableMirroring.VERTICAL:
                    {
                        SDL_Rect dstRect = {cast(short)-horizontalScroll, cast(short)-verticalScroll};
                        SDL_BlitSurface(bg0, null, display, &dstRect);
                        dstRect.x += 256;
                        SDL_BlitSurface(bg1, null, display, &dstRect);
                        dstRect.y += 240;
                        SDL_BlitSurface(bg0, null, display, &dstRect);
                        dstRect.x -= 256;
                        SDL_BlitSurface(bg1, null, display, &dstRect);
                    }
                default:
                    // not supported
                }
            }
            needRedraw = false;
        }
    }

    size_t drawSprites(SDL_Surface* display, size_t fromIndex, bool priority)
    {
        ushort height = spriteSize == SpriteSize.SINGLE ? 8 : 16;
        size_t i;
        for (i = fromIndex; i < 64 && m_spriteinfos[i].priority == priority; ++i)
        {
            SDL_Rect srcRect, dstRect;

            srcRect.x = m_spriteinfos[i].index * 8;
            srcRect.y = 0;
            srcRect.w = 8;
            srcRect.h = height;

            dstRect.x = m_spriteinfos[i].left;
            dstRect.y = m_spriteinfos[i].top;

            SDL_BlitSurface(sprites, &srcRect, display, &dstRect);
        }

        return i;
    }

    void decodeSprites()
    {
        SpriteInfo* latest_priority;
        SpriteInfo* latest_normal;

        if (spriteSize == SpriteSize.SINGLE)
        {
            // for each sprite in spriteRAM
            for (ubyte i = 60; i >= 0; i -= 4)
            {
                ubyte[64] tile;
                const oam = m_spriteRAM[i..i+4];
                size_t index = oam[1] + spritePatternTableAddress;
                patternTableAccess(m_patternTables[index..index+16], tile);
                tile[] |= (0b100 | ((oam[2] & 0b0000_0011) << 2));

                if (isOAMHFlipped(oam[2]))
                    hflip(tile);

                if (isOAMVFlipped(oam[2]))
                    vflip(tile);

                // Draw tile to SDL surface
                SDL_LockSurface(sdlTile);
                foreach (offset; 0..64)
                {
                    (cast(uint*)(*sdlTile).pixels)[offset] = hsvToRgb(tile[offset]);
                }
                SDL_UnlockSurface(sdlTile);

                // blit tile to sprite surface
                SDL_Rect dstRect = {cast(short)(i*8), 0};
                SDL_BlitSurface(sdlTile, null, sprites, &dstRect);

                // decode sprite info
                m_spriteinfos[i].priority = isOAMPrioritary(oam[2]);
                m_spriteinfos[i].index    = i;
                m_spriteinfos[i].left     = oam[3];
                m_spriteinfos[i].top      = oam[0];
            }
        }
        else
        {
            for (ubyte i = 60; i >= 0; i -= 4)
            {
                const oam = m_spriteRAM[i..i+4];

                for (ubyte j = 0; j < 2; ++j)
                {
                    ubyte[64] tile;                    
                    size_t index = (oam[1] >> 1) + (oam[1] & 1 ? 0x1000 : 0) + j*16;
                    patternTableAccess(m_patternTables[index..index+16], tile);
                    tile[] |= (0b100 | ((oam[2] & 0b0000_0011) << 2));

                    // Draw tile to SDL surface
                    SDL_LockSurface(sdlTile);
                    foreach (offset; 0..64)
                    {
                        (cast(uint*)(*sdlTile).pixels)[offset] = hsvToRgb(tile[offset]);
                    }
                    SDL_UnlockSurface(sdlTile);

                    // blit tile to sprite surface
                    SDL_Rect dstRect = {cast(short)(i*8), cast(short)(j*8)};
                    SDL_BlitSurface(sdlTile, null, sprites, &dstRect);
                }

                // decode sprite info
                m_spriteinfos[i].priority = isOAMPrioritary(oam[2]);
                m_spriteinfos[i].index    = i;
                m_spriteinfos[i].left     = oam[3];
                m_spriteinfos[i].top      = oam[0];
            }
        }

        sort(m_spriteinfos[]);
    }
    
public:

    this()
    {
        bg0 = SDL_CreateRGBSurface(SDL_SWSURFACE, 256, 240, 32,
                                   0xFF, 0xFF00, 0xFF0000, 0xFF000000);
        bg1 = SDL_CreateRGBSurface(SDL_SWSURFACE, 256, 240, 32,
                                   0xFF, 0xFF00, 0xFF0000, 0xFF000000);
        sprites = SDL_CreateRGBSurface(SDL_SWSURFACE, 512, 16, 32,
                                       0xFF, 0xFF00, 0xFF0000, 0xFF000000);

        sdlTile = SDL_CreateRGBSurface(SDL_SWSURFACE, 8, 8, 32,
                                       0xFF, 0xFF00, 0xFF0000, 0xFF000000);

        needRedraw = true;
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
        needRedraw = true;
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
        needRedraw = true;
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
    ubyte status() const
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
        needRedraw = true;
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
        needRedraw = true;
        return value;
    }    

    void writeSpriteRam(ubyte value, size_t address)
    {
        m_spriteRAM[address] = value;
    }
    
    void draw(SDL_Surface* display)
    in
    {
        assert (display.w == 256);
        assert (display.h == 240);
    }
    body
    {
        size_t spriteIndex = 0;
        if (showSprites)
        {
            decodeSprites();
            spriteIndex = drawSprites(display, 0, true);
        }

        if (showBackground)
        {
            drawBackground(display);
        }

        if (showSprites)
        {
            drawSprites(display, spriteIndex, false);
        }
    }
}


/**
 * This interface is here to list PPU public members and is only used with 
 * std.typecons.BlackHole.
 */
interface IPPU
{
    const ubyte opIndex(size_t index);
    const ubyte opIndexAssign(ubyte value, size_t index);
    void control(ubyte value);
    void mask(ubyte value);
    ubyte status() const;
    ubyte spriteRAMAddress(ubyte value);
    ubyte spriteRAMValue(ubyte value);
    ubyte scroll(ubyte value);
    ubyte memoryAddress(ubyte value);
    ubyte memoryData();
    ubyte memoryData(ubyte value);
    void writeSpriteRam(ubyte value, size_t address);
}
