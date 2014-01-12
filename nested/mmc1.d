/*------------------------------------------------------------------------------
Copyright© 2010-2014 Olivier Pisano

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

module mmc1;

final class MMC1
{
public:
    /**
     * bits 43210
     *      ||||+- Toggles between horizontal (0) and "vertical (1) mirroring 
     *      |||+-- Toggles between H/V (1) and "one-screen"(0) mirroring 
     *      ||+--- Toggles between low (1) and high PRGROM area switching (0)
     *      |+---- Toggles between 16KB (1) and 32KB (0) PRGROM bank switching
     *      +----- Sets 8KB (0) or 4KB (1) CHRROM switching mode
     */
    void reg0(ubyte value)
    {

    }

    void reg1(ubyte value)
    {

    }

    void reg2(ubyte value)
    {

    }

    void reg3(ubyte value)
    {

    }
}