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

module audio.noise;

import audio.lengthcounter;

/**
 * The NES APU noise channel generates pseudo-random 1-bit noise at 16 different
 * frequencies.
 *
 * The noise channel contains the following: envelope generator, timer, shift 
 * register with feedback, length counter.
 */ 
final class Noise
{
    LengthCounter!(Noise) lengthCounter;
    bool                  m_looping;
    int                   m_shifter;
    ushort                m_shiftRegister;
    
public:
    this()
    {
        lengthCounter   = new LengthCounter!(Noise)(this);
        m_shiftRegister = 1; 
    }
    
    void write400C(ubyte value)
    {
        // enveloppe = value & 0b0001_1111;
        lengthCounter.setEnabled((value & 0b0010_0000) != 0);
    }
    
    void write400E(ubyte value)
    {
        m_looping = (value & 0b1000_0000) != 0;
        m_shifter = m_looping ? 6 : 1;
    }
    
    void write400F(ubyte value)
    {
        lengthCounter.write(value);
        // enveloppe restart
    }
    
    void stop()
    {
        
    }
    
    void start()
    {
        
    }
    
    void shift()
    {
        int otherBit = m_shiftRegister >> m_shifter;
        int feedback = (m_shiftRegister ^ otherBit) & 1;
        
        m_shiftRegister >>= 1;
        m_shiftRegister |= feedback << 14;
    }
}
