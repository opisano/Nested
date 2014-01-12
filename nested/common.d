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

module common;


interface IDisposable
{
    void dispose();
}

/**
* Checks value is in range [lower, upper[.
*/
bool between(uint value, uint lower, uint upper) pure nothrow
{
    return (lower <= value && upper > value);
}

bool among(T)(T value, T[] ts)
{
    foreach (t; ts)
    {
        if (t == value)
        {
            return true;
        }
    }
    return false;
}