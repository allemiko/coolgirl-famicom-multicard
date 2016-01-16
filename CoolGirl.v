module CoolGirl 
	(
	input	m2,
	input romsel,
	input cpu_rw_in,
	input [14:0] cpu_addr_in,
	input [7:0] cpu_data_in,
	output reg [26:13] cpu_addr_out,
	output flash_we,
	output flash_oe,
	output sram_ce,
	output sram_we,
	output sram_oe,
		
	input ppu_rd_in,
	input ppu_wr_in,
	input [13:0] ppu_addr_in,
	output reg [17:10] ppu_addr_out,
	output ppu_rd_out,
	output ppu_wr_out,
	output reg ppu_ciram_a10,
	output ppu_ciram_ce,
		
	output irq
);
	reg [26:14] cpu_base;
	reg [18:14] cpu_mask;
	reg [17:13] chr_mask;
	reg [1:0] sram_page;
	reg [3:0] mapper;
	reg sram_enabled;
	reg chr_write_enabled;
	reg prg_write_enabled;
	reg mirroring;
	reg lockout;

	// some common registers for all mappers
	reg [7:0] r0;
	reg [7:0] r1;
	reg [7:0] r2;
	reg [7:0] r3;
	reg [7:0] r4;
	reg [7:0] r5;
	reg [7:0] r6;
	reg [7:0] r7;
	reg [7:0] r8;
	
	assign flash_we = cpu_rw_in | romsel | ~prg_write_enabled;
	assign flash_oe = ~cpu_rw_in | romsel;
	assign sram_ce = !(cpu_addr_in[14] & cpu_addr_in[13] & m2 & romsel & sram_enabled);
	assign sram_we = cpu_rw_in;
	assign sram_oe = ~cpu_rw_in;
	assign ppu_rd_out = ppu_rd_in | ppu_addr_in[13];
	assign ppu_wr_out = ppu_wr_in | ppu_addr_in[13] | ~chr_write_enabled;
	
	assign ppu_ciram_ce = 1'bZ; // for backward compatibility
	
	assign irq = 1'bz;

	always @ (negedge m2)
	begin
		if (cpu_rw_in == 0) // write
		begin
			if (romsel == 1) // $0000-$7FFF
			begin
				if ((cpu_addr_in[14:12] == 3'b101) && (lockout == 0)) // $5000-5FFF & lockout is off
				begin
					if (cpu_addr_in[2:0] == 3'b000) // $5xx0
						cpu_base[26:22] = cpu_data_in[4:0]; // CPU base address A26-A22
					if (cpu_addr_in[2:0] == 3'b001) // $5xx1
						cpu_base[21:14] = cpu_data_in[7:0]; // CPU base address A21-A14
					if (cpu_addr_in[2:0] == 3'b010) // $5xx2
						cpu_mask[18:14] = cpu_data_in[4:0]; // CPU mask A18-A14
					if (cpu_addr_in[2:0] == 3'b011) // $5xx3
						r0[4:0] = cpu_data_in[4:0];			// direct r0 access for mapper #0 CHR bank
					if (cpu_addr_in[2:0] == 3'b100) // $5xx4
						chr_mask[17:13] = cpu_data_in[4:0];	// CHR mask A17-A13
					if (cpu_addr_in[2:0] == 3'b101) // $5xx5
						sram_page = cpu_data_in[1:0];			// current SRAM page 0-3
					if (cpu_addr_in[2:0] == 3'b110) // $5xx6
						mapper = cpu_data_in[3:0];				// mapper
					if (cpu_addr_in[2:0] == 3'b111) // $5xx7
						// some other parameters
						{lockout, mirroring, prg_write_enabled, chr_write_enabled, sram_enabled} = {cpu_data_in[7], cpu_data_in[3:0]};
				end
			end else begin // $8000-$FFF
				// Mapper #7 - AxROM
				if (mapper == 4'b0111)
				begin
					r0 = cpu_data_in;
				end				
			end // romsel
		end // write
	end

	always @ (*)
	begin
		// Mapper #0 - NROM
		if (mapper == 4'b0000)
		begin
			if (romsel == 0) // accessing $8000-$FFFF
				cpu_addr_out[26:13] = {cpu_base[26:15], cpu_addr_in[14] & ~cpu_mask[14], cpu_addr_in[13]};		
			ppu_addr_out[17:10] = {r0[4:0], ppu_addr_in[12:10]};		
			ppu_ciram_a10 = !mirroring ? ppu_addr_in[10] : ppu_addr_in[11]; // vertical / horizontal			
		end
		// Mapper #7 - AxROM
		if (mapper == 4'b0111)
		begin
			if (romsel == 0) // accessing $8000-$FFFF
				cpu_addr_out[26:13] = {cpu_base[26:15] | (r0[2:0] & ~cpu_mask[17:15]), cpu_addr_in[14:13]};
			ppu_addr_out[17:10] = {5'b00000, ppu_addr_in[12:10]};		
			ppu_ciram_a10 = r0[4];
		end
		
		// accessing $0000-$7FFF, so need to select SRAM page
		if (sram_enabled & romsel)
			cpu_addr_out[14:13] = sram_page[1:0]; // accessing $0000-$7FFF, so need to select SRAM page
	end

endmodule