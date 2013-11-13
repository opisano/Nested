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

module audio.framesequencer;

private enum Mode
{
    MODE_0_4,
    MODE_1_5
}

final class FrameSequencer(T)
{
private:
    T    m_ownee;
    int  m_count;
    Mode m_mode;
    bool m_frameInterrupt;
    
public:
    this(T ownee)
    {
        m_ownee = ownee;
    }
    
    void write(ubyte value)
    {
        m_mode = value & 0b1000_0000 ? MODE_0_4 : MODE_1_5;
        
        if (value & 0b0100_0000)
            m_frameInterrupt = false;
        
        m_count = 0;
    }
}


