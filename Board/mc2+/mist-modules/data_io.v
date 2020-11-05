//
// data_io.v
//
// data_io for the MiST board
// http://code.google.com/p/mist-board/
//
// Copyright (c) 2014 Till Harbaum <till@harbaum.org>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
///////////////////////////////////////////////////////////////////////

module data_io # (
parameter STRLEN		=	0
)
(
	input             clk_sys,
	input             SPI_SCK,
	input             SPI_SS2,
	input             SPI_DI,
	output            SPI_DO,

	input             clkref_n, // assert ioctl_wr one cycle after clkref stobe (negative active)
	
	input   [7:0]           data_in,
	input [(8*STRLEN)-1:0] conf_str,
	output reg [31:0] status,
	

	// ARM -> FPGA download
	output reg        ioctl_download = 0, // signal indicating an active download
	output reg  [7:0] ioctl_index,        // menu index used to upload the file
	output reg        ioctl_wr,           // strobe indicating ioctl_dout valid
	output reg [24:0] ioctl_addr,
	output reg  [7:0] ioctl_dout
);

parameter START_ADDR = 25'd0;

reg sdo_s;

assign SPI_DO = sdo_s;

///////////////////////////////   DOWNLOADING   ///////////////////////////////

reg  [7:0] data_w;
reg  [7:0] data_w2;
reg        rclk   = 0;
reg        rclk2  = 0;
reg        addr_reset = 0;

reg        downloading_reg = 0;
reg  [7:0] index_reg = 0;

localparam DIO_FILE_TX      = 8'h53;
localparam DIO_FILE_TX_DAT  = 8'h54;
localparam DIO_FILE_INDEX   = 8'h55;

reg [7:0]	ACK = 8'd75; // letter K - 0x4b
reg  [10:0]  byte_cnt;   // counts bytes
reg  [7:0] cmd;
reg  [4:0] cnt;

// SPI MODE 0 : incoming data on Rising, outgoing on Falling
	always@(negedge SPI_SCK, posedge SPI_SS2) 
	begin
	
		
				//each time the SS goes down, we will receive a command from the SPI master
				if (SPI_SS2) // not selected
					begin
						sdo_s <= 1'bZ;
						byte_cnt <= 11'd0;
					end
				else
					begin
							
							if (cmd == 8'h10 ) //command 0x10 - send the data to the microcontroller
								sdo_s <= data_in[~cnt[2:0]];
								
							else if (cmd == 8'h00 ) //command 0x00 - ACK
								sdo_s <= ACK[~cnt[2:0]];
							
						//	else if (cmd == 8'h61 ) //command 0x61 - echo the pumped data
						//		sdo_s <= sram_data_s[~cnt[2:0]];			
					
					
							else if(cmd == 8'h14) //command 0x14 - reading config string
								begin
								
									if(byte_cnt < STRLEN + 1 ) // returning a byte from string
										sdo_s <= conf_str[{STRLEN - byte_cnt,~cnt[2:0]}];
									else
										sdo_s <= 1'b0;
										
								end	
						
				
							if(cnt[2:0] == 7) 
								byte_cnt <= byte_cnt + 8'd1;
							
					end
	end
	
// data_io has its own SPI interface to the io controller
always@(posedge SPI_SCK, posedge SPI_SS2) begin
	reg  [6:0] sbuf;
	reg [24:0] addr;
	reg  [4:0] cnf_byte;

	if(SPI_SS2) 
	begin
		cnt <= 0;
		cnf_byte <= 4'd15;
	end
	else begin
		// don't shift in last bit. It is evaluated directly
		// when writing to ram
		if(cnt != 15) sbuf <= { sbuf[5:0], SPI_DI};

		// count 0-7 8-15 8-15 ...
		if(cnt != 15) cnt <= cnt + 1'd1;
			else cnt <= 8;

		// finished command byte
		if(cnt == 7) 
		begin 
			cmd <= {sbuf, SPI_DI};
		
		
				// command 0x61: start the data streaming
				if(sbuf[6:0] == 7'b0110000 && SPI_DI == 1'b1)
				begin
					addr_reset <= ~addr_reset;
					downloading_reg <= 1;
				end
				
				// command 0x62: end the data streaming
				if(sbuf[6:0] == 7'b0110001 && SPI_DI == 1'b0)
				begin
					//addr_w <= addr;
					downloading_reg <= 0;
				end
		end
		
		
		if(cnt == 15) 
		begin 
		
				// command 0x15: stores the status word (menu selections)
				if (cmd == 8'h15)
				begin
					case (cnf_byte)	
										
						4'd15: status[31:24] <={sbuf, SPI_DI};
						4'd14: status[23:16] <={sbuf, SPI_DI};
						4'd13: status[15:8]  <={sbuf, SPI_DI};
						4'd12: status[7:0]   <={sbuf, SPI_DI};
						
					endcase
					
					cnf_byte <= cnf_byte - 1'd1;

				end
		
			// command 0x60: stores a configuration byte
				if (cmd == 8'h60)
				begin
						//config_buffer_o[cnf_byte] <= {sbuf, SPI_DI};
						cnf_byte <= cnf_byte - 1'd1;
				end
						
				// command 0x61: Data Pump 8 bits
				if (cmd == 8'h61) 
				begin
						data_w <= {sbuf, SPI_DI};
						rclk <= ~rclk;
				end
		end
		
		
		
		/*

		// prepare/end transmission
		if((cmd == DIO_FILE_TX) && (cnt == 15)) begin
			// prepare
			if(SPI_DI) begin
				addr_reset <= ~addr_reset;
				downloading_reg <= 1;
			end else begin
				downloading_reg <= 0;
			end
		end

		// command 0x54: UIO_FILE_TX
		if((cmd == DIO_FILE_TX_DAT) && (cnt == 15)) begin
			data_w <= {sbuf, SPI_DI};
			rclk <= ~rclk;
		end
		*/

		// expose file (menu) index
		if((cmd == DIO_FILE_INDEX) && (cnt == 15)) index_reg <= {sbuf, SPI_DI};
	end
end

/*
// direct SD Card->FPGA transfer
always@(posedge SPI_SCK, posedge SPI_SS4) begin
	reg  [6:0] sbuf2;
	reg  [2:0] cnt2;
	reg  [9:0] bytecnt;

	if(SPI_SS4) begin
		cnt2 <= 0;
		bytecnt <= 0;
	end else begin
		// don't shift in last bit. It is evaluated directly
		// when writing to ram
		if(cnt2 != 7)
			sbuf2 <= { sbuf2[5:0], SPI_DO };

		cnt2 <= cnt2 + 1'd1;

		// received a byte
		if(cnt2 == 7) begin
			bytecnt <= bytecnt + 1'd1;
			// read 514 byte/sector (512 + 2 CRC)
			if (bytecnt == 513) bytecnt <= 0;
			// don't send the CRC bytes
			if (~bytecnt[9]) begin
				data_w2 <= {sbuf2, SPI_DO};
				rclk2 <= ~rclk2;
			end
		end
	end
end
*/

always@(posedge clk_sys) begin
	// bring flags from spi clock domain into core clock domain
	reg rclkD, rclkD2;
	reg rclk2D, rclk2D2;
	reg addr_resetD, addr_resetD2;
	reg wr_int, wr_int_direct;
	reg [24:0] addr;

	{ rclkD, rclkD2 } <= { rclk, rclkD };
	{ rclk2D ,rclk2D2 } <= { rclk2, rclk2D };
	{ addr_resetD, addr_resetD2 } <= { addr_reset, addr_resetD };

	ioctl_wr <= 0;

	ioctl_download <= downloading_reg;

	if (~clkref_n) begin
		wr_int <= 0;
		wr_int_direct <= 0;
		if (wr_int || wr_int_direct) begin
			ioctl_dout <= wr_int ? data_w : data_w2;
			ioctl_wr <= 1;
			addr <= addr + 1'd1;
			ioctl_addr <= addr;
		end
	end

	// detect transfer start from the SPI receiver
	if(addr_resetD ^ addr_resetD2) begin
		addr <= START_ADDR;
		ioctl_index <= index_reg;
	end

	// detect new byte from the SPI receiver
	if (rclkD ^ rclkD2)   wr_int <= 1;
	if (rclk2D ^ rclk2D2) wr_int_direct <= 1;
end

endmodule
