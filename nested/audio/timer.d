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

module audio.timer;

enum ConsoleVersion
{
    NTSC,
    PAL
}

final class Timer(ConsoleVersion v)
{
    static if (v == NTSC)
    {
        immutable static int[16] periods = [4, 8, 16, 32, 64, 96, 128, 160,
                               202, 254, 380, 508, 762, 1016, 2034, 4068];
    }
    else
    {
        immutable static int[16] periods = [4, 7, 14, 30, 60, 88, 118, 148, 
                               188, 236, 354, 472, 708,  944, 1890, 3778];
    }
}
