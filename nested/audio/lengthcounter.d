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

module audio.lengthcounter;

private immutable int SETVALUES[2][16] = 
    [[0x0A, 0x14, 0x28, 0x50, 0xA0, 0x3C, 0x0E, 0x1A, 
      0x0C, 0x18, 0x30, 0x60, 0xC0, 0x48, 0x10, 0x20],
     [0xFE, 0x02, 0x04, 0x06, 0x08, 0x0A, 0x0C, 0x0E,
      0x10, 0x12, 0x14, 0x16, 0x18, 0x1A, 0x1C, 0x1E]];   
      
final class LengthCounter(Owner)
{
private:
    int   m_count;
    Owner m_owner;
    bool  m_enabled;
    
public:    
    this(Owner owner)
    {
        m_owner = owner;
    }
    
    void clock()
    {
        if (m_enabled)
        {
            if (--m_count == 0)
            {
                m_owner.stop();
                m_enabled = false;
            }
        }
    }
    
    void write(ubyte value)
    {
        if (m_enabled)
        {
            int firstIndex  = (value >> 3) & 1;
            int secondIndex = (value >> 4) & 0b0000_1111;
            m_count = SETVALUES[firstIndex][secondIndex];
        }
    }
    
    void setEnabled(bool enabled)
    {
        m_enabled = enabled;
    }
}
