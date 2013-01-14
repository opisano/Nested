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

module cpu;
 

import std.conv;

import memory;
import ppu;


// Flag indices
enum CARRY     = 0b0000_0001;
enum ZERO      = 0b0000_0010;
enum INTERRUPT = 0b0000_0100;
enum DECIMAL   = 0b0000_1000;
enum BREAK     = 0b0001_0000;

enum OVERFLOW  = 0b0100_0000;
enum NEGATIVE  = 0b1000_0000;


/**
 * Modelization of the MOS 6502 CPU.
 */
final class CPU
{
private:
    uint cycles;

    void setZero(ubyte value)
    {
        if (value == 0)
        {
             flags |= ZERO;
        }
        else
        {
            flags &= ~ZERO;
        }
    }
    
    void setSign(ubyte value)
    {
        if (a & 0b1000_0000)
        {
            flags |= NEGATIVE;
        }
        else
        {
            flags &= ~ NEGATIVE;
        }
    }
    
    void setCarry(int value)
    {
        if (value)
        {
            flags |= CARRY;
        }
        else
        {
            flags &= ~CARRY;
        }
    }
    
    void setOverflow(int value)
    {
        if (value)
        {
            flags |= OVERFLOW;
        }
        else
        {
            flags &= ~OVERFLOW;
        }
    }
    
    static bool crossPage(uint addr1, uint addr2) pure nothrow
    {
        return (addr1 & 0xFF00) != (addr2 & 0xFF00);
    }
    
    /**
     * Reads the next byte after the current opcode in memory
     * used to fetch instruction operands.
     */
    ubyte read_mem()
    {
        return memory[pc++];
    }
    
    /// Adressing modes
    
    MemInfo absolute()
    {
        ushort address = read_mem();
        address |= read_mem() << 8;
        
        boundary_crossed = crossPage(pc, address);
        
        MemInfo mi;
        mi.address = address; 
        mi.value   = memory[address];
        
        return mi;
    }
    
    ushort absolute_address()
    {
        ushort address = read_mem();
        address |= read_mem() << 8;
        boundary_crossed = crossPage(pc, address);
        return address;
    }
    
    MemInfo zero_page()
    {
        ushort a = read_mem();
        
        MemInfo mi;
        mi.address = a; 
        mi.value   = memory[a];
        
        return mi;
    }
    
    MemInfo absolute_x()
    {
        ushort address = read_mem();
        address |= read_mem() << 8;
        address += x;
        
        boundary_crossed = crossPage(pc, address);
        MemInfo mi;
        mi.address = address;
        mi.value   = memory[address];
        
        return mi;
    }
    
    MemInfo absolute_y()
    {
        ushort address = read_mem();
        address |= read_mem() << 8;
        address += y;
        
        boundary_crossed = crossPage(pc, address);
        
        MemInfo mi;
        mi.address = address;
        mi.value   = memory[address];
        
        return mi;
    }
    
    MemInfo zero_page_x()
    {
        ubyte address = read_mem();
        address += x;
        boundary_crossed = crossPage(pc, address);
        
        MemInfo mi; 
        mi.address = address;
        mi.value  = memory[address];
        
        return mi;
    }
    
    MemInfo zero_page_y()
    {
        ubyte address = read_mem();
        address += y;
        boundary_crossed = crossPage(pc, address);
        
        MemInfo mi;
        mi.address = address;
        mi.value   = memory[address];
        
        return mi;
    }
    
    ushort absolute_indirect()
    {
        ushort address = read_mem();
        address |= read_mem() << 8;
        
        ushort result = memory[address];
        result |= memory[address+1] << 8;
        
        boundary_crossed = crossPage(pc, result);
        
        return result;
    }
    
    ushort indirect()
    {
        ushort address = read_mem();
        address |= read_mem() << 8;
        address +=  x;
        
        ushort result = memory[address];
        result |= memory[address+1] << 8;
        
        boundary_crossed = crossPage(pc, result);
        
        return result;
    }
    
    MemInfo zero_page_x_indirect()
    {
        ubyte address = read_mem();
        address += x;
        
        ushort address2 = memory[address];
        address2 |= memory[address+1] << 8;
        
        boundary_crossed = crossPage(pc, address2);
        
        MemInfo mi;
        mi.address = address2;
        mi.value   = memory[address2];
        
        return mi;
    }
    
    MemInfo zero_page_y_indirect()
    {
        ubyte address = read_mem();
        
        ushort address2 = memory[address];
        address2 |= memory[address+1] << 8;
        address2 += y;
        
        boundary_crossed = crossPage(pc, address2);
        
        MemInfo mi;
        mi.address = address2;
        mi.value   = memory[address2];
        
        return mi;
    }
	
	alias void delegate() func;
	func[ubyte] opCodes;
	
	/**
	 * Initializes decoding. 
	 * Fills the opCodes associative array with anonymous methods that process
	 * the corresponding operations.
	 */
	void initDecoding()
	{
		opCodes[0x00] = (){ brk(); cycles += 7; }; //BRK
		opCodes[0x01] = (){ ora(zero_page_x_indirect().value); cycles += 6; }; //ORA, indirect X
		opCodes[0x05] = (){ ora(zero_page().value); cycles += 2; }; //ORA, Zero page
		opCodes[0x06] = (){ asl(zero_page().tupleof); cycles += 5; }; //ASL, zero page
		opCodes[0x08] = (){ php(); cycles += 3; }; //PHP
		opCodes[0x09] = (){ ubyte m = read_mem(); ora(m); cycles += 2; }; //ORA, immediate
		opCodes[0x0A] = (){ asl(); cycles += 2; }; //ASL, Acc
		opCodes[0x0D] = (){ ora(absolute().value); cycles += 4; }; //ORA, absolute
		opCodes[0x0E] = (){ asl(absolute().tupleof); cycles += 6; }; //ASL, absolute
		opCodes[0x10] = (){ ubyte m = read_mem(); bpl(m); cycles += 2; }; //BPL
		opCodes[0x11] = (){ ora(zero_page_y_indirect().value); cycles += boundary_crossed ? 6 : 5; }; //ORA indirect Y
		opCodes[0x15] = (){ ora(zero_page_x().value); cycles += 3; }; //ORA, zero page X
		opCodes[0x16] = (){ asl(zero_page_x().tupleof); cycles += 6; }; //asl, zero page x
		opCodes[0x18] = (){ clc(); cycles += 2; }; //CLC
		opCodes[0x19] = (){ ora(absolute_y().value); cycles += boundary_crossed ? 5 : 4; }; //ORA absolute y 
		opCodes[0x1D] = (){ ora(absolute_x().value); cycles += boundary_crossed ? 5 : 4; }; //ORA absolute x
		opCodes[0x1E] = (){ asl(absolute_x().tupleof); cycles += 7; }; //ASL, absolute x
		opCodes[0x20] = (){ jsr(absolute_address()); cycles += 6; }; //JSR
		opCodes[0x21] = (){ and(zero_page_x_indirect().value); cycles += 6; }; //AND indirect X
		opCodes[0x24] = (){ bit(zero_page().value); cycles += 3; }; //Bit zero page
		opCodes[0x25] = (){ and(zero_page().value); cycles += 2; }; //AND zero page
		opCodes[0x26] = (){ rol(zero_page().tupleof); cycles += 5; }; //ROL zero page
		opCodes[0x28] = (){ plp(); cycles += 4; }; //PLP
		opCodes[0x29] = (){ ubyte m = read_mem(); and(m); cycles += 2; }; //AND immediate
		opCodes[0x2A] = (){ rol(); cycles += 2; }; //ROL acc
		opCodes[0x2C] = (){ bit(absolute().value); cycles += 4; }; //Bit test absolute
		opCodes[0x2D] = (){ and(absolute().value); cycles += 4; }; //AND absolute
		opCodes[0x2E] = (){ rol(absolute().tupleof); cycles += 6; }; //ROL absolute
		opCodes[0x30] = (){ ubyte m = read_mem(); bmi(m); cycles += 2; }; //BMI
		opCodes[0x31] = (){ and(zero_page_y_indirect().value); cycles += boundary_crossed ? 6 : 5; }; //AND y indirect
		opCodes[0x35] = (){ and(zero_page_x().value); cycles += 3; }; //ANd zero page X
		opCodes[0x36] = (){ rol(zero_page_x().tupleof); cycles += 6; }; //ROL zero page x
		opCodes[0x38] = (){ sec(); cycles += 2; }; //SEC
		opCodes[0x39] = (){ and(absolute_y().value); cycles += boundary_crossed ? 4 : 3; }; //AND absolute y
		opCodes[0x3D] = (){ and(absolute_x().value); cycles += boundary_crossed ? 4 : 3; }; //AND absolute x
		opCodes[0x3E] = (){ rol(absolute_x().tupleof); cycles += 7; }; //ROL absolute X
		opCodes[0x40] = (){ rti(); cycles += 6; }; //RTI
		opCodes[0x41] = (){ eor(zero_page_x_indirect().value); cycles += 6; }; //EOR, indirect x
		opCodes[0x45] = (){ eor(zero_page().value); cycles += 3; }; //EOR zero page
		opCodes[0x46] = (){ lsr(zero_page().tupleof); cycles += 5; }; //LSR zero page
		opCodes[0x48] = (){ pha(); cycles += 3; }; //PHA
		opCodes[0x49] = (){ ubyte m = read_mem(); eor(m); cycles += 2; }; //EOR
		opCodes[0x4A] = (){ lsr(); cycles += 2; }; //LSR Acc
		opCodes[0x4C] = (){ jmp(absolute_address()); cycles += 3; }; //JMP absolute
		opCodes[0x4D] = (){ eor(absolute().value); cycles += 4; }; //EOR absolute
		opCodes[0x4E] = (){ lsr(absolute().tupleof); cycles += 6; }; //LSR absolute
		opCodes[0x50] = (){ ubyte m = read_mem(); bvc(m); cycles += 2; }; //BVC
		opCodes[0x51] = (){ eor(zero_page_y_indirect().value); cycles += boundary_crossed ? 6 : 5; }; //EOR indirect Y
		opCodes[0x55] = (){ eor(zero_page_x().value); cycles += 4; }; //EOR zero page x
		opCodes[0x56] = (){ lsr(zero_page_x().tupleof); cycles += 6; }; //LSR zero page x
		opCodes[0x58] = (){ cli(); cycles += 2; }; //CLI
		opCodes[0x59] = (){ eor(absolute_y().value); cycles += boundary_crossed ? 5 : 4; }; //EOR absolute y
		opCodes[0x5D] = (){ eor(absolute_x().value); cycles += boundary_crossed ? 5 : 4; }; //EOR absolute x
		opCodes[0x5E] = (){ lsr(absolute_x().tupleof); cycles += 7; }; //LSR absolute X
		opCodes[0x60] = (){ rts(); cycles += 6; }; //rts
		opCodes[0x61] = (){ adc(zero_page_x_indirect().value); cycles += 6; }; //ADC indirect x
		opCodes[0x65] = (){ adc(zero_page().value); cycles += 3; }; //ADC zero page
		opCodes[0x66] = (){ ror(zero_page().tupleof); cycles += 5; }; //ROR zero page
		opCodes[0x68] = (){ pla(); cycles += 4; }; //PLA
		opCodes[0x69] = (){ ubyte m = read_mem(); adc(m); cycles += 2; }; //ADC immediate
		opCodes[0x6A] = (){ ror(); cycles += 2; }; //ROR accumulator 
		opCodes[0x6C] = (){ jmp(indirect()); cycles += 5; }; //JMP indirect
		opCodes[0x6D] = (){ adc(absolute().value); cycles += 4; }; //ADC absolute
		opCodes[0x6E] = (){ ror(absolute().tupleof); cycles += 6; }; //ROR absolute
		opCodes[0x70] = (){ ubyte m = read_mem(); bvs(m); cycles += 2; }; //BVS
		opCodes[0x71] = (){ adc(zero_page_y_indirect().value); cycles += boundary_crossed ? 6 : 5; }; //ADC indirect Y
		opCodes[0x75] = (){ adc(zero_page_x().value); cycles += 4; }; //ADC zero page X
		opCodes[0x76] = (){ ror(zero_page_x().tupleof); cycles += 6; }; //ROR zero page x
		opCodes[0x78] = (){ sei(); cycles += 2; }; //SEI
		opCodes[0x79] = (){ adc(absolute_y().value); cycles += boundary_crossed ? 5 : 4; }; //ADC absolute Y
		opCodes[0x7D] = (){ adc(absolute_x().value); cycles += boundary_crossed ? 5 : 4; }; //ADC absolute X
		opCodes[0x7E] = (){ ror(absolute_x().tupleof); cycles += 7; }; //ROR absolute X
		opCodes[0x81] = (){ sta(zero_page_x_indirect().address); cycles += 6; }; //STA indirect x
		opCodes[0x84] = (){ sty(zero_page().address); cycles += 3; }; //STY zero page
		opCodes[0x85] = (){ sta(zero_page().address); cycles += 3; }; //STA zero page
		opCodes[0x86] = (){ stx(zero_page().address); cycles += 3; }; //STX zero page
		opCodes[0x88] = (){ dey(); cycles += 2; }; //DEY
		opCodes[0x8A] = (){ txa(); cycles += 2; }; // TXA
		opCodes[0x8C] = (){ sty(absolute().address); cycles += 4; }; //STY absolute
		opCodes[0x8D] = (){ sta(absolute().address); cycles += 4; }; //STA absolute
		opCodes[0x8E] = (){ stx(absolute().address); cycles += 4; }; //STX absolute
		opCodes[0x90] = (){ ubyte m = read_mem(); bcc(m); cycles += 2; }; //BCC
		opCodes[0x91] = (){ sta(zero_page_y_indirect().address); cycles += 6; }; //STA indirect y
		opCodes[0x94] = (){ sty(zero_page_x().address); cycles += 4; }; //STY zero page X
		opCodes[0x95] = (){ sta(zero_page_x().address); cycles += 4; }; //STA zero page x
		opCodes[0x96] = (){ stx(zero_page_y().address); cycles += 4; }; //STX zero page y
		opCodes[0x98] = (){ tya(); cycles += 2; }; //TYA:
		opCodes[0x99] = (){ sta(absolute_y().address); cycles += 5; }; //STA absolute Y
		opCodes[0x9A] = (){ txs(); cycles += 2; }; //TXS
		opCodes[0x9D] = (){ sta(absolute_x().address); cycles += 5; }; //STA absolute x
		opCodes[0xA0] = (){ ubyte m = read_mem(); ldy(m); cycles += 2; }; //LDY immediate
		opCodes[0xA1] = (){ lda(zero_page_x_indirect().value); cycles += 6; }; //LDA indirect x
		opCodes[0xA2] = (){ ubyte m = read_mem(); ldx(m); cycles += 2; }; //LDX immediate
		opCodes[0xA4] = (){ ldy(zero_page().value); cycles += 3; }; //LDY zero page
		opCodes[0xA5] = (){ lda(zero_page().value); cycles += 3; }; //LDA zero page
		opCodes[0xA6] = (){ ldx(zero_page().value); cycles += 3; }; //LDX zero page
		opCodes[0xA8] = (){ tay(); cycles += 2; }; //TAY 
		opCodes[0xA9] = (){ ubyte m = read_mem(); lda(m); cycles += 2; }; //LDA immediate
		opCodes[0xAA] = (){ tax(); cycles += 2; }; //TAX
		opCodes[0xAC] = (){ ldy(absolute().value); cycles += 4; }; //LDY absolute
		opCodes[0xAD] = (){ lda(absolute().value); cycles += 4; }; //LDA absolute
		opCodes[0xAE] = (){ ldx(absolute().value); cycles += 4; }; //LDX absolute
		opCodes[0xB0] = (){ ubyte m = read_mem(); bcs(m); cycles += 2; }; //BCS
		opCodes[0xB1] = (){ lda(zero_page_y_indirect().value); cycles += boundary_crossed ? 6 : 5; }; //LDA indirect y
		opCodes[0xB4] = (){ ldy(zero_page_x().value); cycles += 4; }; //LDY zero page x
		opCodes[0xB5] = (){ lda(zero_page_x().value); cycles += 4; }; //LDA zero page x
		opCodes[0xB6] = (){ ldx(zero_page_y().value); cycles += 4; }; //LDX zero page y
		opCodes[0xB8] = (){ clv(); cycles += 2; }; //CLV
		opCodes[0xB9] = (){ lda(absolute_y().value); cycles += boundary_crossed ? 5 : 4; }; //LDA absolute y
		opCodes[0xBA] = (){ tsx(); cycles += 2; }; //TSX
		opCodes[0xBC] = (){ ldy(absolute_x().value); cycles += boundary_crossed ? 5 : 4; }; //LDX absolute x
		opCodes[0xBD] = (){ lda(absolute_x().value); cycles += boundary_crossed ? 5 : 4; }; //LDA absolute X
		opCodes[0xBE] = (){ ldx(absolute_y().value); cycles += boundary_crossed ? 5 : 4; }; //LDX absolute y
		opCodes[0xC0] = (){ ubyte m = read_mem(); cpy(m); cycles += 2; }; //CPY immediate
		opCodes[0xC1] = (){ cmp(zero_page_x_indirect().value); cycles += 6; }; //CMP indirect X
		opCodes[0xC4] = (){ cpy(zero_page().value); cycles += 3; }; //CPY zero page
		opCodes[0xC5] = (){ cmp(zero_page().value); cycles += 3; }; //CMP Zero page
		opCodes[0xC6] = (){	dec(zero_page().address); cycles += 5; }; // DEC zero page
		opCodes[0xC8] = (){ iny(); cycles += 2; }; //INY
		opCodes[0xC9] = (){ ubyte m = read_mem(); cmp(m); cycles += 2; }; //cmp immediate
		opCodes[0xCA] = (){ dex(); cycles += 2; }; //DEX
		opCodes[0xCC] = (){ cpy(absolute().value); cycles += 4; }; //CPY absolute
		opCodes[0xCD] = (){ cmp(absolute().value); cycles += 4; }; //CMP absolute
		opCodes[0xCE] = (){ dec(absolute().address); cycles += 6; }; //DEC absolute
		opCodes[0xD0] = (){ ubyte m = read_mem(); bne(m); cycles += 2; }; // BNE
		opCodes[0xD1] = (){ cmp(zero_page_y_indirect().value); cycles += boundary_crossed ? 6 : 5; }; //CMP indirect y
		opCodes[0xD5] = (){ cmp(zero_page_x().value); cycles += 4; }; //CMP zero page X
		opCodes[0xD6] = (){ dec(zero_page_x().address); cycles += 6; }; // DEC zero page X
		opCodes[0xD8] = (){ cld(); cycles += 2; }; //CLD 
		opCodes[0xD9] = (){ cmp(absolute_y().value); cycles += boundary_crossed ? 5 : 4; }; //CMP absolute Y
		opCodes[0xDD] = (){ cmp(absolute_x().value); cycles += boundary_crossed ? 5 : 4; }; //CMP absolute X
		opCodes[0xDE] = (){ dec(absolute_x().address); cycles += 7; }; //DEC absolute x
		opCodes[0xE0] = (){ ubyte m = read_mem(); cpx(m); cycles += 2; }; //cpx, immeditate
		opCodes[0xE1] = (){ sbc(zero_page_x_indirect().value); cycles += 6; }; //SBC inderect x
		opCodes[0xE4] = (){ cpx(zero_page().value); cycles += 3; }; //CPX zero page
		opCodes[0xE5] = (){ sbc(zero_page().value); cycles += 3; }; //SBC zero page
		opCodes[0xE6] = (){ inc(zero_page().address); cycles += 5; }; //INC zero page
		opCodes[0xE8] = (){ inx(); cycles += 2; }; //INX
		opCodes[0xE9] = (){ ubyte m = read_mem(); sbc(m); cycles += 2; }; //SBC immediate
		opCodes[0xEA] = (){ nop(); cycles += 2; }; //NOP
		opCodes[0xEC] = (){ cpx(absolute().value); cycles += 4; }; //CPX absolute
		opCodes[0xED] = (){ sbc(absolute().value); cycles += 4; }; //SBC absolute
		opCodes[0xEE] = (){ inc(absolute().address); cycles += 6; }; //INC absolute
		opCodes[0xF0] = (){ ubyte m = read_mem(); beq(m); cycles += 2; }; //BEQ 
		opCodes[0xF1] = (){ sbc(zero_page_y_indirect().value); cycles += boundary_crossed ? 6 : 5; }; //SBC indirect Y
		opCodes[0xF5] = (){ sbc(zero_page_x().value); cycles += 4; }; //SBC zero page X
		opCodes[0xF6] = (){ inc(zero_page_x().address); cycles += 6; }; //INC zero page X
		opCodes[0xF8] = (){ sed(); cycles += 2; }; //SED
		opCodes[0xF9] = (){ sbc(absolute_y().value); cycles += boundary_crossed ? 5 : 4; }; //SBC // absolute y
		opCodes[0xFD] = (){ sbc(absolute_x().value); cycles += boundary_crossed ? 5 : 4; }; //SBC absolute X
		opCodes[0xFE] = (){ inc(absolute_x().address); cycles += 7; }; //INC absolute X
	}
    
    void decode(ubyte opcode)
    in
    {
        assert (cycles == 0);
    }
    out
    {
        assert (cycles >= 2 && cycles <= 7);
		assert (boundary_crossed == false);
    }
    body
    {
        auto fp = (opcode in opCodes);
		scope (exit) boundary_crossed = false;
		
		if (fp !is null)
		{
			(*fp)();
		}
		else
		{
            throw new Exception("Cpu.decode() : Unknown opcode : " 
                    ~ to!(string)(opcode));   
        }
    }
    
    // memory
    CPUMemoryMap memory;
    
    /// program counter
    ushort pc;
    
    /// CPU FLAGS
    ubyte flags;
    
    /// Accumulator register
    ubyte a;
    
    /// X index register
    ubyte x;
    
    /// Y index register
    ubyte y;
    
    /// stack pointer
    ubyte sp;
    
    /// signals that last instruction crossed pages boundaries
    bool boundary_crossed;

    /// signal that an IRQ occured
    bool irq;

    /// signal that a reset interrupt occured
    bool reset;

    /// signal that a NMI occured
    bool nmi;

    /** Signals that the CPU was interrupted. Can be caused by:
     *   - Reset interrupt occured.
     *   - NMI occured.
     *   - IRQ occured while the interrupt disable flag is clear.
     */
    bool interrupted() const nothrow
    {
        return (reset || nmi || (irq && !(flags & INTERRUPT)));
    }
    
public:

    this(PPU ppu)
    in
    {
        assert (ppu !is null);
    }
    body
    {
        memory = new CPUMemoryMap(ppu);
		initDecoding();
    }
    
    void clock()
    {
        if (cycles)
        {
            cycles--;
        }
        else
        {
            if (!interrupted()) // normal execution
            {
                ubyte opcode = read_mem();
                decode(opcode);
            }
            else // CPU was interrupted
            {
                // push the program courter 
                memory[0x0100 | sp--] = pc & 0xFF;
                memory[0x0100 | sp--] = (pc >> 8) & 0xFF;

                // push status register onto the stack
                php();

                // Set the interrupt disable flag
                sei();

                ushort addr;
                if (reset)
                {
                    reset = false;
                    addr = memory[0xFFFC];
                    addr |= (memory[0xFFFD] << 8);
                }
                else if (nmi)
                {
                    nmi = false;
                    addr = memory[0xFFFA];
                    addr |= (memory[0xFFFB] << 8);
                }
                else // irq
                {
                    irq = false;
                    addr = memory[0xFFFF];
                    addr |= (memory[0xFFFE] << 8);
                }

                // Load the address of the interrupt handling routine
                jmp(addr);
                cycles = 7;
            }
        }
    }

private:
    
    /**
     * A,Z,C,N = A+M+C
     *
     * This instruction adds the contents of a memory location to the 
     * accumulator together with the carry bit. If overflow occurs the 
     * carry bit is set, this enables multiple byte addition to be performed.
     */
    void adc(ubyte m)
    {
        uint temp = m + a + (flags & CARRY);
        setZero(cast(ubyte)temp);
        
        if (flags & DECIMAL)
        {
             if (((a & 0xf) + (m & 0xf) + (flags & CARRY ? 1 : 0)) > 9) 
                 temp += 6;
             setSign(cast(ubyte)temp);
             setOverflow(!((a ^ m) & 0x80) && ((a ^ temp) & 0x80));
             if (temp > 0x99) temp += 96;
             setCarry(temp > 0x99 ? 1 : 0);
        }
        else
        {
            setSign(cast(ubyte)temp);
            setOverflow(!((a ^ m) & 0x80) && ((a ^ temp) & 0x80));
            setCarry(temp > 0xff ? 1 : 0);
        }
        
        a = cast(ubyte) temp;
    }
    
    
    
    /**
     * AND - Logical AND
     * A,Z,N = A&M
     * A logical AND is performed, bit by bit, on the accumulator contents 
     * using the contents of a byte of memory.
     */
    void and(ubyte value)
    {
        a &= value;         
        setZero(a);
        setSign(a);
    }
    
    /**
     * ASL - Arithmetic Shift Left
     *
     * A,Z,C,N = M*2 or M,Z,C,N = M*2
     *
     * This operation shifts all the bits of the accumulator or memory contents
     * one bit left. Bit 0 is set to 0 and bit 7 is placed in the carry flag. 
     * The effect of this operation is to multiply the memory contents by 2 
     * (ignoring 2's complement considerations), setting the carry if the result
     * will not fit in 8 bits.
     */
    void asl()
    {
        setCarry(a & 0b1000_0000);        
        a <<= 1;
        
        setZero(a);
        setSign(a);
    }
    
    void asl(ushort address, ubyte value)
    {
        setCarry(value & 0b1000_0000);        
        value <<= 1;
        memory[address] = value;
        
        setZero(value);
        setSign(value);
    }
    
    /**
     * Branch if carry clear
     * If the carry flag is clear then add the relative displacement to the 
     * program counter to cause a branch to a new location.
     */
    void bcc(byte offset)
    {
        if ((flags & CARRY) == 0)
        {
            cycles += crossPage(pc, pc + offset) ? 2 : 1;
            pc += offset;
        }
        cycles += 2;
    }
    
    /**
     * Branch if carry set.
     * If the carry flag is clear then add the relative displacement to the 
     * program counter to cause a branch to a new location.
     */
    void bcs(byte offset)
    {
        if (flags & CARRY)
        {
            cycles += crossPage(pc, pc + offset) ? 2 : 1;
            pc += offset;
        }
        cycles += 2;
    }
    
    /**
     * BEQ - Branch if equal
     * If the zero flag is set then add the relative displacement to the 
     * program counter to cause a branch to a new location.
     */
    void beq(byte offset)
    {
        if (flags & ZERO)
        {
            cycles += crossPage(pc, pc + offset) ? 2 : 1;
            pc += offset;
        }
        cycles += 2;
        
    }
    
    /**
     * BIT - Bit Test
     *
     * A & M, N = M7, V = M6
     *
     * This instructions is used to test if one or more bits are set in a 
     * target memory location. The mask pattern in A is ANDed with the value 
     * in memory to set or clear the zero flag, but the result is not kept. 
     * Bits 7 and 6 of the value from memory are copied into the N and V flags.
     */
    void bit(ubyte value)
    {
        ubyte temp = value & a;
        setZero(temp);
        
        if (value & 0b1000_0000)
        {
            flags |= NEGATIVE;
        }
        else
        {
            flags &= ~NEGATIVE;
        }
        
        setSign(value);
    }
    
    /**
     * BMI - Branch if minus
     * 
     * If the negative flag is set then add the relative displacement to the 
     * program counter to cause a branch to a new location.
     */
    void bmi(byte offset)
    {
        if (flags & NEGATIVE)
        {
            cycles += crossPage(pc, pc + offset) ? 2 : 1;
            pc += offset;
        }
        cycles += 2;
    }
    
    /**
     * BEQ - Branch if not Equal
     *
     * If the zero flag is clear then add the relative displacement to the 
     * program counter to cause a branch to a new location.
     */
    void bne(byte offset)
    {
        if ((flags & ZERO) ==  0)
        {
            cycles += crossPage(pc, pc + offset) ? 2 : 1;
            pc += offset;
        }
        cycles += 2;
    }
    
    /**
     * BPL - Branch if positive
     * 
     * If the negative flag is clear then add the relative displacement to the 
     * program counter to cause a branch to a new location.
     */
    void bpl(byte offset)
    {
        if ((flags & NEGATIVE) == 0)
        {
            cycles += crossPage(pc, pc + offset) ? 2 : 1;
            pc += offset;
        }
        cycles += 2;
    }
    
    /**
     * BRK - Force interrupt
     *
     * The BRK instruction forces the generation of an interrupt request. 
     * The program counter and processor status are pushed on the stack then 
     * the IRQ interrupt vector at $FFFE/F is loaded into the PC and the break 
     * flag in the status set to one.
     */
    void brk()
    {
        pc++;
        
        // push the pc on the stack
        memory[0x0100 | sp--] = cast(ubyte)(pc >> 8);
        memory[0x0100 | sp--] = cast(ubyte)(pc);
        
        // set the break flag 
        flags |= BREAK;
        
        // push the status on the stack
        php();
        
        // the IRQ interrupt vector at $FFFE/F is loaded into the PC
        pc =  memory[0xFFFE];
        pc |= memory[0xFFFF] << 8;
    }
    
    /**
     * BVC - Branch if overflow clear
     *
     * If the overflow flag is clear then add the relative displacement to the 
     * program counter to cause a branch to a new location.
     */
    void bvc(byte offset)
    {
        if ((flags & OVERFLOW) == 0)
        {
            cycles += crossPage(pc, pc + offset) ? 2 : 1;
            pc += offset;
        }
        cycles += 2;
    }
    
    /**
     * BVS - Branch if overflow set
     * 
     * If the overflow flag is set then add the relative displacement to the 
     * program counter to cause a branch to a new location.
     */
    void bvs(byte offset)
    {
        if (flags & OVERFLOW)
        {
            cycles += crossPage(pc, pc + offset) ? 2 : 1;
            pc += offset;
        }
        cycles += 2;
    }
    
    /**
     * CLC - Clear Carry Flag
     *
     * C = 0
     * Set the carry flag to zero.
     */
    void clc()
    {
        flags &= ~CARRY;
    }
    
    /**
     * CLD - Clear Decimal flag
     * D = 0
     */
    void cld()
    {
        flags &= ~DECIMAL;
    }
    
    /** 
     * CLI - Clear Interrupt disable
     * I = 0
     */
    void cli()
    out
    {
        assert ((flags & INTERRUPT) == 0);
    }
    body
    {
        flags &= ~INTERRUPT;
    }
    
    /**
     * CLV - Clear overflow flag
     * V = 0
     */
    void clv()
    out
    {
        assert ((flags & OVERFLOW) == 0);
    }
    body
    {
        flags &= ~OVERFLOW;
    }
    
    /**
     * CMP - Compare
     * 
     * Z,C,N = A-M
     *
     * This instruction compares the contents of the accumulator with another 
     * memory held value and sets the zero and carry flags as appropriate.
     */
    void cmp(ubyte value)
    {
        ubyte temp = cast(ubyte)(a - value);
        
        setSign(temp);
        
        setZero(temp);
        
        if (a >= value)
        {
            flags |= CARRY;
        }
        else
        {
            flags &= ~CARRY;
        }
    }
    
    /**
     * CPX - Compare X Register
     * 
     * Z,C,N = X-M
     * 
     * This instruction compares the contents of the X register with another 
     * memory held value and sets the zero and carry flags as appropriate.
     */
    void cpx(ubyte value)
    {
        ubyte temp = cast(ubyte)(x - value);
        
        // set negative flag
        setSign(temp);
        setZero(temp);
        
        if (a >= value)
        {
            flags |= CARRY;
        }
        else
        {
            flags &= ~CARRY;
        }
    }
    
    /**
     * CPY - Compare Y register
     *
     * This instruction compares the contents of the Y register with another 
     * memory held value and sets the zero and carry flags as appropriate.
     */
    void cpy(ubyte value)
    {
        ubyte temp = cast(ubyte)(x - value);
        
        // set negative flag
        setSign(temp);
        setZero(temp);
        
        if (a >= value)
        {
            flags |= CARRY;
        }
        else
        {
            flags &= ~CARRY;
        }
    }
    
    /**
     * DEC - Decrement Memory
     *
     * M,Z,N = M-1
     * 
     * Subtracts one from the value held at a specified memory location setting
     * the zero and negative flags as appropriate.
     */
    void dec(ushort address)
    {
        ubyte value = cast(ubyte)(memory[address] - 1);
        memory[address] = value;
        setZero(value);
        setSign(value);
    }    
    
    /**
     * DEX - Decrement X Register
     *
     * X,Z,N = X-1
     *
     * Subtracts one from the X register setting the zero and negative flags 
     * as appropriate.
     */
    void dex()
    {
        x--;
        
        setZero(x);
        setSign(x);
    }
    
    /**
     * DEY - Decrement Y Register
     *
     * Y,Z,N = Y-1
     *
     * Subtracts one from the Y register setting the zero and negative flags 
     * as appropriate.
     */
    void dey()
    {
        y--;
        
        setZero(y);
        setSign(y);
    }
    
    /**
     * EOR - Exclusive OR
     *
     * A,Z,N = A^M
     *
     * An exclusive OR is performed, bit by bit, on the accumulator 
     * contents using the contents of a byte of memory.
     */
    void eor(ubyte value)
    {
        a ^= value;
        
        setZero(a);
        setSign(a);
    }
    
    
    /**
     * INC - Increment Memory
     *
     * M,Z,N = M+1
     *
     * Adds one to the value held at a specified memory location setting the 
     * zero and negative flags as appropriate.
     */
    void inc(ushort address)
    {
        ubyte value = cast(ubyte)(memory[address] + 1);
        memory[address] = value;
        setZero(value);
        setSign(value);
    }
    
    /**
     * INX - Increment X Register
     *
     * X,Z,N = X+1
     *
     * Adds one to the X register setting the zero and negative flags as 
     * appropriate.
     */
    void inx()
    {
        x++;
        
        setZero(x);
        setSign(x);
    }
    
    /**
     * INY - Increment Y Register
     *
     * Y,Z,N = Y+1
     *
     * Adds one to the Y register setting the zero and negative flags as 
     * appropriate.
     */
    void iny()
    {
        y++;
        
        setZero(y);
        setSign(y);
    }
    
    /**
     * JMP - Jump
     *
     * Sets the program counter to the address specified by the operand.
     */
    void jmp(ushort address)
    {
        pc = address;
    }
    
    /**
     * JSR - Jump to Subroutine
     * 
     * The JSR instruction pushes the address (minus one) of the return point 
     * on to the stack and then sets the program counter to the target memory 
     * address.JSR - Jump to Subroutine
     * 
     * The JSR instruction pushes the address (minus one) of the return point 
     * on to the stack and then sets the program counter to the target memory 
     * address.
     */
    void jsr(ushort address)
    {
        ushort temp = cast(ushort)(pc - 1);
        memory[0x0100 | sp--] = cast(ubyte)(pc >> 8);
        memory[0x0100 | sp--] = cast(ubyte)(pc);
        
        pc = address;
    }
    
    /**
     * LDA - Load Accumulator
     *
     * A,Z,N = M
     *
     * Loads a byte of memory into the accumulator setting the zero and 
     * negative flags as appropriate.
     */
    void lda(ubyte value)
    {
        a = value;
        setZero(a);
        setSign(a);
    }
    
    /**
     * LDX - Load X
     *
     * X,Z,N = M
     *
     * Loads a byte of memory into the X register setting the zero and 
     * negative flags as appropriate.
     */
    void ldx(ubyte value)
    {
        x = value;
        setZero(x);
        setSign(x);
    }
    
    /**
     * LDY - Load Y
     *
     * Y,Z,N = M
     *
     * Loads a byte of memory into the Y register setting the zero and 
     * negative flags as appropriate.
     */
    void ldy(ubyte value)
    {
        y = value;
        setZero(y);
        setSign(y);
    }
    
    /**
     * LSR - Logical Shift Right
     * 
     * A,C,Z,N = A/2 or M,C,Z,N = M/2
     *
     * Each of the bits in A or M is shift one place to the right. The bit that
     * was in bit 0 is shifted into the carry flag. Bit 7 is set to zero.
     */
    void lsr()
    {
        setCarry(a & 1);
        flags &= ~NEGATIVE;
        
        a >>= 1;
        setZero(a);
    }
    
    void lsr(ushort address, ubyte value)
    {
        setCarry(value & 1);
        flags &= ~NEGATIVE;
        
        value >>= 1;
        memory[address] = value;
        setZero(value);
    }
    
    /**
     * ORA - Logical Inclusive OR
     * 
     * A,Z,N = A|M
     *
     * An inclusive OR is performed, bit by bit, on the accumulator contents 
     * using the contents of a byte of memory.
     */
    void ora(ubyte value)
    {
        a |= value;
        
        setZero(a);
        setSign(a);
    }
    
    /** 
     * Does nothing
     */
    void nop()
    {
        
    }
    
    /**
     * PHA - Push Accumulator
     *
     * Pushes a copy of the accumulator on to the stack.
     * 
     * Processor Status after use:
     */
    void pha()
    {
        memory[0x0100 | sp--] = a;
    }
    
    /**
     * PHP - Push Processor Status
     *
     * Pushes a copy of the status flags on to the stack.
     */
    void php()
    {
        memory[0x0100 | sp--] = flags;
    }
    
    /**
     * PLA - Pull Accumulator
     *
     * Pulls an 8 bit value from the stack and into the accumulator. The zero 
     * and negative flags are set as appropriate.
     */
    void pla()
    {
        a = memory[0x1000 | ++sp];
    }
    
    /**
     * PLP - Pull Processor Status
     *
     * Pulls an 8 bit value from the stack and into the processor flags. The 
     * flags will take on new states as determined by the value pulled.
     */
    void plp()
    {
        flags = memory[0x1000 | ++sp];
    }
    
    /**
     * ROL - Rotate Left
     *
     * Move each of the bits in either A or M one place to the left. Bit 0 is 
     * filled with the current value of the carry flag whilst the old bit 7 
     * becomes the new carry flag value.
     */
    void rol()
    {
        ubyte temp = a & 0b1000_0000;
        a <<= 1;
        if (flags & CARRY)
            a++;
        setCarry(temp);
        setZero(a);
        setSign(a);
    }
    
    void rol(ushort address, ubyte value)
    {
        ubyte temp = value & 0b1000_0000;
        value <<= 1;
        if (flags & CARRY)
            value++;
        
        memory[address] = value;
        
        setCarry(temp);
        setZero(value);
        setSign(value);
    }
    
    /**
     * ROR - Rotate Right
     * 
     * Move each of the bits in either A or M one place to the right. Bit 7 is 
     * filled with the current value of the carry flag whilst the old bit 0 
     * becomes the new carry flag value.
     */
    void ror()
    {
        int carry = a & 1;
        a >>= 1;
        if (flags & CARRY)
            a |=  0b1000_0000;
        setCarry(carry);
        setZero(a);
        setSign(a);
    }
    
    void ror(ushort address, ubyte value)
    {
        int carry = value & 1;
        value >>= 1;
        if (flags & CARRY)
            value |=  0b1000_0000;
        
        memory[address] = value;
        
        setCarry(carry);
        setZero(value);
        setSign(value);
    }
    
    /**
     * RTI - Return from Interrupt
     *
     * The RTI instruction is used at the end of an interrupt processing 
     * routine. It pulls the processor flags from the stack followed by the 
     * program counter.
     */
    void rti()
    {
        plp();
        pc = memory[0x1000 | ++sp];
        pc |= memory[0x1000 | ++sp] << 8;
    }
    
    /**
     * RTS - Return from Subroutine
     *
     * The RTS instruction is used at the end of a subroutine to return to the 
     * calling routine. It pulls the program counter (minus one) from the 
     * stack.
     */
    void rts()
    {
        pc = memory[0x1000 | ++sp];
        pc += (memory[0x1000 | ++sp] << 8) + 1;
    }
    
    /**
     * SBC - Subtract with Carry
     *
     * A,Z,C,N = A-M-(1-C)
     * 
     * This instruction subtracts the contents of a memory location to the 
     * accumulator together with the not of the carry bit. If overflow occurs 
     * the carry bit is clear, this enables multiple byte subtraction to be 
     * performed.
     */
    void sbc(ubyte m)
    {
        uint temp = a - m - (flags & CARRY ? 0 : 1);
        setSign(cast(ubyte)temp);
        setZero(cast(ubyte)temp);
        setOverflow(((a ^ temp) & 0x80) && ((a ^ m) & 0x80));
        if (flags & DECIMAL) 
        {
            if ( ((a & 0xf) - (flags & CARRY ? 0 : 1)) < (m & 0xf))
                temp -= 6;
            if (temp > 0x99) 
                temp -= 0x60;
        }
        setCarry(temp < 0x100 ? 1 : 0);
        a = cast(ubyte)(temp);
    }
    
    /**
    * SEC - Set Carry Flag
    *
    * C = 1
    * Set the carry flag to one.
    */
    void sec()
    out
    {
        assert (flags & CARRY);
    }
    body
    {
        flags |= CARRY;
    }
    
    /**
     * SED - Set Decimal flag
     * D = 1
     *
     */
    void sed()
    out
    {
        assert (flags & DECIMAL);
    }
    body
    {
        flags |= DECIMAL;
    }
    
    /**
     * SEI - Set Interrupt disable 
     * I = 1
     */
    void sei()
    out
    {
        assert (flags & INTERRUPT);
    }
    body
    {
        flags |= INTERRUPT; 
    }
    
    /**
     * STA - Store Accumulator
     *
     * M = A
     *
     * Stores the contents of the accumulator into memory.
     */
    void sta(ushort address)
    {
        memory[address] = a;
    }
    
    /**
     * STX - Store X
     *
     * M = X
     *
     * Stores the contents of the X register into memory.
     */    
    void stx(ushort address)
    {
        memory[address] = x;
    }
    
    /**
     * STY - Store Y
     *
     * M = Y
     *
     * Stores the contents of the Y register into memory.
     */
    void sty(ushort address)
    {
        memory[address] = y;
    }
    
    /**
     * TAX - Transfer Accumulator to X
     *
     * X = A
     *
     * Copies the current contents of the accumulator into the X register and 
     * sets the zero and negative flags as appropriate.
     */
    void tax()
    {
        x = a;
        setZero(x);
        setSign(x);
    }
    
    /**
     * TAY - Transfer Accumulator to Y
     *
     * Y = A
     *
     * Copies the current contents of the accumulator into the Y register and 
     * sets the zero and negative flags as appropriate.
     */
    void tay()
    {
        y = a;
        setZero(y);
        setSign(y);
    }
    
    /**
     * TSX - Transfer Stack Pointer to X
     *
     * X = S
     *
     * Copies the current contents of the stack register into the X register 
     * and sets the zero and negative flags as appropriate.
     */
    void tsx()
    {
        x = sp;
        setZero(x);
        setSign(x);
    }
    
    /**
     * TXA - Transfer X to Accumulator
     *
     * A = X
     *
     * Copies the current contents of the X register into the accumulator and 
     * sets the zero and negative flags as appropriate.
     */
    void txa()
    {
        a = x;
        setZero(a);
        setSign(a);
    }
    
    /**
     * TXS - Transfer X to Stack Pointer
     *
     * S = X
     *
     * Copies the current contents of the X register into the stack register.
     */
    void txs()
    {
        sp = x;
    }
    
    /**
     * TYA - Transfer Y to Accumulator
     *
     * A = Y
     *
     * Copies the current contents of the Y register into the accumulator and 
     * sets the zero and negative flags as appropriate.
     */
    void tya()
    {
        a = y;
        setZero(a);
        setSign(a);
    }
}


