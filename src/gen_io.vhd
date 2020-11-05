-- Copyright (c) 2010 Gregory Estrade (greg@torlus.com)
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- Redistributions of source code must retain the above copyright notice,
-- this list of conditions and the following disclaimer.
--
-- Redistributions in synthesized form must reproduce the above copyright
-- notice, this list of conditions and the following disclaimer in the
-- documentation and/or other materials provided with the distribution.
--
-- Neither the name of the author nor the names of other contributors may
-- be used to endorse or promote products derived from this software without
-- specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
--
-- Please report bugs to the author, but before you do so, please
-- make sure that this is not a derivative work and that
-- you have the latest version of this file.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- gen-hw.txt from line 416
entity gen_io is
	port(
		RST_N		: in std_logic;
		CLK		: in std_logic;
		
		J3BUT    : in std_logic;

		P1_UP		: in std_logic;
		P1_DOWN	: in std_logic;
		P1_LEFT	: in std_logic;
		P1_RIGHT	: in std_logic;
		P1_A		: in std_logic;
		P1_B		: in std_logic;
		P1_C		: in std_logic;
		P1_START	: in std_logic;
		P1_MODE	: in std_logic;
		P1_X	   : in std_logic;
		P1_Y	   : in std_logic;
		P1_Z	   : in std_logic;

		P2_UP		: in std_logic;
		P2_DOWN	: in std_logic;
		P2_LEFT	: in std_logic;
		P2_RIGHT	: in std_logic;
		P2_A		: in std_logic;
		P2_B		: in std_logic;
		P2_C		: in std_logic;
		P2_START	: in std_logic;
		P2_MODE	: in std_logic;
		P2_X	   : in std_logic;
		P2_Y	   : in std_logic;
		P2_Z	   : in std_logic;

		MSEL   : in std_logic_vector(1 downto 0);
		mouse_x: in std_logic_vector(7 downto 0);
		mouse_y: in std_logic_vector(7 downto 0);
		mouse_flags: in std_logic_vector(7 downto 0);
		mouse_strobe: in std_logic;

		SEL		: in std_logic;
		A			: in std_logic_vector(4 downto 0);
		RNW		: in std_logic;
		UDS_N		: in std_logic;
		LDS_N		: in std_logic;
		DI			: in std_logic_vector(15 downto 0);
		DO			: out std_logic_vector(15 downto 0);
		DTACK_N	: out std_logic;

		PAL		: in std_logic;
		PAL_OUT : out std_logic;
		MODEL   : in std_logic
	);
end gen_io;
architecture rtl of gen_io is
signal FF_DTACK_N	: std_logic;

signal VERS			: std_logic_vector(7 downto 0);
signal VERS_D		: std_logic_vector(7 downto 0);
signal DATA			: std_logic_vector(7 downto 0);
signal DATB			: std_logic_vector(7 downto 0);
signal DATC			: std_logic_vector(7 downto 0);
signal CTLA			: std_logic_vector(7 downto 0);
signal CTLB			: std_logic_vector(7 downto 0);
signal CTLC			: std_logic_vector(7 downto 0);
signal TXDA			: std_logic_vector(7 downto 0);
signal TXDB			: std_logic_vector(7 downto 0);
signal TXDC			: std_logic_vector(7 downto 0);
signal RXDA			: std_logic_vector(7 downto 0);
signal RXDB			: std_logic_vector(7 downto 0);
signal RXDC			: std_logic_vector(7 downto 0);
signal SCTA			: std_logic_vector(7 downto 0);
signal SCTB			: std_logic_vector(7 downto 0);
signal SCTC			: std_logic_vector(7 downto 0);

signal REG			: std_logic_vector(3 downto 0);
signal WD			: std_logic_vector(7 downto 0);
signal RD			: std_logic_vector(7 downto 0);

signal THA			: std_logic;
signal THB			: std_logic;
signal THA_D		: std_logic;
signal THB_D		: std_logic;

signal TRA			: std_logic;
signal TRB			: std_logic;
signal TRA_D		: std_logic;
signal TRB_D		: std_logic;

signal MSTATE       : std_logic_vector(3 downto 0);
signal MOUSE        : std_logic_vector(4 downto 0);
signal MSTROB       : std_logic;
signal MACKDELAY	: integer;
signal mouse_x_latch: std_logic_vector(7 downto 0);
signal mouse_y_latch: std_logic_vector(7 downto 0);
signal mouse_flags_latch: std_logic_vector(7 downto 0);

signal mouse_x_latch_d: std_logic_vector(7 downto 0);
signal mouse_y_latch_d: std_logic_vector(7 downto 0);
signal mouse_flags_latch_d: std_logic_vector(7 downto 0);

signal JCNT1		: integer range 0 to 3;
signal JCNT2		: integer range 0 to 3;

signal JTMR1		: integer range 0 to 129000;
signal JTMR2		: integer range 0 to 129000;

begin

DO <= RD & RD;
DTACK_N <= FF_DTACK_N;

REG <= A(4 downto 1);
WD <= DI(7 downto 0) when LDS_N = '0' else DI(15 downto 8);

--invalid combination (PAL with Japanese model) means auto-detect
VERS <= VERS_D when MODEL = '0' and PAL = '1' else (MODEL & PAL & "10" & x"0");
PAL_OUT <= VERS(6);

THA <= DATA(6) or not CTLA(6);
THB <= DATB(6) or not CTLB(6);

TRA <= DATA(5) or not CTLA(5);
TRB <= DATB(5) or not CTLB(5);

process( CLK )
begin
	if rising_edge(CLK) then
		THA_D <= THA;
		THB_D <= THB;
		TRA_D <= TRA;
		TRB_D <= TRB;
	end if;
end process;

process( RST_N, CLK )
begin
	if RST_N = '0' then
		FF_DTACK_N <= '1';
		RD <= (others => '1');

		DATA <= x"7F";
		DATB <= x"7F";
		DATC <= x"7F";

		CTLA <= x"00";
		CTLB <= x"00";
		CTLC <= x"00";

		TXDA <= x"FF";
		RXDA <= x"00";
		SCTA <= x"00";
		
		TXDB <= x"FF";
		RXDB <= x"00";
		SCTB <= x"00";

		TXDC <= x"FF";
		RXDC <= x"00";
		SCTC <= x"00";

		JCNT1 <= 0;
		JCNT2 <= 0;

	elsif rising_edge(CLK) then
		if J3BUT = '0' then
			-- state reset timer for 6 button controller
			-- about 1.5ms
			if(JTMR1 > 90000) then
				JCNT1 <= 0;
			else
				JTMR1 <= JTMR1 + 1;
			end if;

			if(JTMR2 > 90000) then
				JCNT2 <= 0;
			else
				JTMR2 <= JTMR2 + 1;
			end if;
		end if;

		if THA_D = '0' and THA = '1' then JCNT1 <= JCNT1 + 1; end if;
		if THA_D /= THA then JTMR1 <= 0; end if;

		if THB_D = '0' and THB = '1' then JCNT2 <= JCNT2 + 1; end if;
		if THB_D /= THB then JTMR2 <= 0; end if;

		if SEL = '0' then
			FF_DTACK_N <= '1';
		elsif SEL = '1' and FF_DTACK_N = '1' then

			if RNW = '0' then
				-- Write
				case REG is
				when x"0" =>
					VERS_D <= WD;
				when x"1" =>
					DATA <= WD;
				when x"2" =>
					DATB <= WD;
				when x"3" =>
					DATC <= WD;
				when x"4" =>
					CTLA <= WD;
				when x"5" =>
					CTLB <= WD;
				when x"6" =>
					CTLC <= WD;
				when x"7" =>
					TXDA <= WD;
				when x"8" =>
					RXDA <= WD;
				when x"9" =>
					SCTA <= WD;
				when x"A" =>
					TXDB <= WD;
				when x"B" =>
					RXDB <= WD;
				when x"C" =>
					SCTB <= WD;
				when x"D" =>
					TXDC <= WD;
				when x"E" =>
					RXDC <= WD;
				when x"F" =>
					SCTC <= WD;					
				when others => null;
				end case;
			else
				case REG is
				when x"0" =>
					RD <= VERS;
				when x"1" =>
					RD <= DATA;
					if CTLA(7) = '0' then RD(7) <= '1'; end if;
					if MSEL(0) = '0' and DATA(6) = '1' then
						-- joy TH = 1
						if(J3BUT='1' or JCNT1/=3) then
							if CTLA(5) = '0' then RD(5) <= P1_C;     end if;
							if CTLA(4) = '0' then RD(4) <= P1_B;     end if;
							if CTLA(3) = '0' then RD(3) <= P1_RIGHT; end if;
							if CTLA(2) = '0' then RD(2) <= P1_LEFT;  end if;
							if CTLA(1) = '0' then RD(1) <= P1_DOWN;  end if;
							if CTLA(0) = '0' then RD(0) <= P1_UP;    end if;
						else
							if CTLA(5) = '0' then RD(5) <= P1_C;     end if;
							if CTLA(4) = '0' then RD(4) <= P1_B;     end if;
							if CTLA(3) = '0' then RD(3) <= P1_MODE;  end if;
							if CTLA(2) = '0' then RD(2) <= P1_X;     end if;
							if CTLA(1) = '0' then RD(1) <= P1_Y;     end if;
							if CTLA(0) = '0' then RD(0) <= P1_Z;     end if;
						end if;
					elsif MSEL(0) = '0' then
						-- joy TH = 0
						if(J3BUT='1' or JCNT1<2) then
							if CTLA(5) = '0' then RD(5) <= P1_START; end if;
							if CTLA(4) = '0' then RD(4) <= P1_A;     end if;
							if CTLA(3) = '0' then RD(3) <= '0';      end if;
							if CTLA(2) = '0' then RD(2) <= '0';      end if;
							if CTLA(1) = '0' then RD(1) <= P1_DOWN;  end if;
							if CTLA(0) = '0' then RD(0) <= P1_UP;    end if;
						elsif (JCNT1=2) then
							if CTLA(5) = '0' then RD(5) <= P1_START; end if;
							if CTLA(4) = '0' then RD(4) <= P1_A;     end if;
							if CTLA(3) = '0' then RD(3) <= '0';      end if;
							if CTLA(2) = '0' then RD(2) <= '0';      end if;
							if CTLA(1) = '0' then RD(1) <= '0';      end if;
							if CTLA(0) = '0' then RD(0) <= '0';      end if;
						else
							if CTLA(5) = '0' then RD(5) <= P1_START; end if;
							if CTLA(4) = '0' then RD(4) <= P1_A;     end if;
							if CTLA(3) = '0' then RD(3) <= '1';      end if;
							if CTLA(2) = '0' then RD(2) <= '1';      end if;
							if CTLA(1) = '0' then RD(1) <= '1';      end if;
							if CTLA(0) = '0' then RD(0) <= '1';      end if;
						end if;
					else
						-- mouse
						if CTLA(4) = '0' then RD(4) <= MOUSE(4); end if;
						if CTLA(3) = '0' then RD(3) <= MOUSE(3); end if;
						if CTLA(2) = '0' then RD(2) <= MOUSE(2); end if;
						if CTLA(1) = '0' then RD(1) <= MOUSE(1); end if;
						if CTLA(0) = '0' then RD(0) <= MOUSE(0); end if;
					end if;
				when x"2" =>
					RD <= DATB;
					if CTLB(7) = '0' then RD(7) <= '1'; end if;
					if MSEL(1) = '0' and DATB(6) = '1' then
						if(J3BUT='1' or JCNT2/=3) then
							if CTLB(5) = '0' then RD(5) <= P2_C;     end if;
							if CTLB(4) = '0' then RD(4) <= P2_B;     end if;
							if CTLB(3) = '0' then RD(3) <= P2_RIGHT; end if;
							if CTLB(2) = '0' then RD(2) <= P2_LEFT;  end if;
							if CTLB(1) = '0' then RD(1) <= P2_DOWN;  end if;
							if CTLB(0) = '0' then RD(0) <= P2_UP;    end if;
						else
							if CTLB(5) = '0' then RD(5) <= P2_C;     end if;
							if CTLB(4) = '0' then RD(4) <= P2_B;     end if;
							if CTLB(3) = '0' then RD(3) <= P2_MODE;  end if;
							if CTLB(2) = '0' then RD(2) <= P2_X;     end if;
							if CTLB(1) = '0' then RD(1) <= P2_Y;     end if;
							if CTLB(0) = '0' then RD(0) <= P2_Z;     end if;
						end if;
					elsif MSEL(1) = '0' then
						if(J3BUT='1' or JCNT2<2) then
							if CTLB(5) = '0' then RD(5) <= P2_START; end if;
							if CTLB(4) = '0' then RD(4) <= P2_A;     end if;
							if CTLB(3) = '0' then RD(3) <= '0';      end if;
							if CTLB(2) = '0' then RD(2) <= '0';      end if;
							if CTLB(1) = '0' then RD(1) <= P2_DOWN;  end if;
							if CTLB(0) = '0' then RD(0) <= P2_UP;    end if;
						elsif (JCNT2=2) then
							if CTLB(5) = '0' then RD(5) <= P2_START; end if;
							if CTLB(4) = '0' then RD(4) <= P2_A;     end if;
							if CTLB(3) = '0' then RD(3) <= '0';      end if;
							if CTLB(2) = '0' then RD(2) <= '0';      end if;
							if CTLB(1) = '0' then RD(1) <= '0';      end if;
							if CTLB(0) = '0' then RD(0) <= '0';      end if;
						else
							if CTLB(5) = '0' then RD(5) <= P2_START; end if;
							if CTLB(4) = '0' then RD(4) <= P2_A;     end if;
							if CTLB(3) = '0' then RD(3) <= '1';      end if;
							if CTLB(2) = '0' then RD(2) <= '1';      end if;
							if CTLB(1) = '0' then RD(1) <= '1';      end if;
							if CTLB(0) = '0' then RD(0) <= '1';      end if;
						end if;
					else
						-- mouse
						if CTLB(4) = '0' then RD(4) <= MOUSE(4); end if;
						if CTLB(3) = '0' then RD(3) <= MOUSE(3); end if;
						if CTLB(2) = '0' then RD(2) <= MOUSE(2); end if;
						if CTLB(1) = '0' then RD(1) <= MOUSE(1); end if;
						if CTLB(0) = '0' then RD(0) <= MOUSE(0); end if;
					end if;
				when x"3" => -- Unconnected port
					RD <= DATC;
					if CTLC(7) = '0' then RD(7) <= '1'; end if;
					if CTLC(6) = '0' then RD(6) <= '1'; end if;
					if CTLC(5) = '0' then RD(5) <= '1'; end if;
					if CTLC(4) = '0' then RD(4) <= '1'; end if;
					if CTLC(3) = '0' then RD(3) <= '1'; end if;
					if CTLC(2) = '0' then RD(2) <= '1'; end if;
					if CTLC(1) = '0' then RD(1) <= '1'; end if;
					if CTLC(0) = '0' then RD(0) <= '1'; end if;
				when x"4" =>
					RD <= CTLA;
				when x"5" =>
					RD <= CTLB;
				when x"6" =>
					RD <= CTLC;
				when x"7" =>
					RD <= TXDA;
				when x"8" =>
					RD <= RXDA;
				when x"9" =>
					RD <= SCTA;
				when x"A" =>
					RD <= TXDB;
				when x"B" =>
					RD <= RXDB;
				when x"C" =>
					RD <= SCTB;
				when x"D" =>
					RD <= TXDC;
				when x"E" =>
					RD <= RXDC;
				when x"F" =>
					RD <= SCTC;
				when others => null;
				end case;
			end if;
			
			FF_DTACK_N <= '0';
		end if;
	end if;
end process;

process( RST_N, CLK )
begin
	if RST_N = '0' then
		MOUSE <= (others => '0');
		MSTATE <= (others =>'0');
		MACKDELAY <= 0;
		MSTROB <= '0';
	elsif rising_edge(CLK) then
		MSTROB <= '0';
		if MSTROB = '1' then
			case MSTATE is
			when "0000" => MOUSE <= "10000";
			when "0001" => MOUSE <= "01011";
			when "0010" => MOUSE(3 downto 0) <= "1111";
			when "0011" => MOUSE(3 downto 0) <= "1111";
			when "0100" => MOUSE(3 downto 0) <= mouse_flags_latch_d(7 downto 4);
			when "0101" => MOUSE(3 downto 0) <= '0' & mouse_flags_latch_d(2 downto 0);
			when "0110" => MOUSE(3 downto 0) <= mouse_x_latch_d(7 downto 4);
			when "0111" => MOUSE(3 downto 0) <= mouse_x_latch_d(3 downto 0);
			when "1000" => MOUSE(3 downto 0) <= mouse_y_latch_d(7 downto 4);
			when "1001" => MOUSE(3 downto 0) <= mouse_y_latch_d(3 downto 0);
			when others => null;
			end case;
		end if;

		if MSTATE = "1001" and
			((MSEL(0) = '1' and THA = '1' and TRA = '1') or
			 (MSEL(1) = '1' and THB = '1' and TRB = '1')) then
			mouse_x_latch <= (others => '0');
			mouse_y_latch <= (others => '0');
			mouse_flags_latch(7 downto 4) <= (others => '0');
		end if;
		if mouse_strobe = '1' then
			mouse_x_latch <= mouse_x;
			mouse_y_latch <= mouse_y;
			mouse_flags_latch <= mouse_flags;
		end if;
		if MSTATE = "0000" and MSTROB = '1' then
			mouse_x_latch_d <= mouse_x_latch;
			mouse_y_latch_d <= mouse_y_latch;
			mouse_flags_latch_d <= mouse_flags_latch;
		end if;

		if MSEL(0) = '1' then
			if THA = '1' and TRA = '1' then
				MSTATE <= "0000";
				MACKDELAY <= 0;
				MSTROB <= '1';
			elsif ((THA_D /= THA) or (TRA_D /= TRA)) and MSTATE /= "1001" then
				MSTATE <= MSTATE + 1;
				MACKDELAY <= 500;
				MSTROB <= '1';
			end if;
		elsif MSEL(1) = '1' then
			if THB = '1' and TRB = '1' then
				MSTATE <= "0000";
				MACKDELAY <= 0;
				MSTROB <= '1';
			elsif ((THB_D /= THB) or (TRB_D /= TRB)) and MSTATE /= "1001" then
				MSTATE <= MSTATE + 1;
				MACKDELAY <= 500;
				MSTROB <= '1';
			end if;
		end if;

		if MACKDELAY /= 0 then
			MACKDELAY <= MACKDELAY - 1;
			if MACKDELAY = 1 then
				MOUSE(4) <= not MOUSE(4);
			end if;
		end if;
	end if;
end process;

end rtl;
