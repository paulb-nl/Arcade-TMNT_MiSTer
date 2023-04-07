module sprites(
	input reset,
	input clk,
	input clken,	// Currently unused
	
	input rom_prom1_we,
	input ioctl_download,
	input [15:0] rom_data,
	input [25:0] rom_addr,
	
	input OBJCS,
	input PDS,
	input NREAD,
	output PE,
	
	input HVOT,
	
	input [7:0] DB_IN,
	input [15:1] AB,
	input nUDS,
	
	output [7:0] DB_OUT_k051960,
	output DBDIR_k051960,
	output [7:0] DB_OUT_k051937,
	output DBDIR_k051937,
	
	output SHA, NOBJ,
	output [11:0] OB,
	
	output reg ODTAC,
	
	output [18:0] spr_rom_addr,
	input [31:0] spr_rom_dout
);

	wire clk_12M;
	wire PQ;
	wire [31:0] spr_rom_planar;
	wire [8:0] HP;
	wire [7:0] OC;
	wire [17:0] CA;
	wire [9:0] OA;
	wire [7:0] OD_in;
	wire [7:0] OD_out;

	reg [9:1] CA_DEC;
	wire [3:0] PROM_dout;
	
	// TODO: Really use ce_main properly
	wire clk_main;
	reg [1:0] clk_div;
	always @(posedge clk or posedge reset) begin
		if (reset)
			clk_div <= 2'd1;
		else begin
			clk_div <= clk_div + 1'b1;
		end
	end
	assign clk_main = clk_div[1];
	
	// LS74
	reg I20_Q;
	always @(posedge PQ or negedge PDS) begin
		if (!PDS)
			I20_Q <= 1'b1;
		else
			I20_Q <= OBJCS;
	end
	
	// LS74
	always @(posedge clk_12M or negedge PDS) begin
		if (!PDS)
			ODTAC <= 1'b1;
		else
			ODTAC <= I20_Q;
	end
	
	k051960 k051960_1 (
		.clk_96M(clk),
	
		.nRES(~reset),
		.clk_24M(clk_main),
		.clk_12M(clk_12M),
		
		.HVIN(HVOT),
		
		.PQ(PQ), .PE(PE),
		
		.NRD(NREAD), .OBCS(ODTAC),
		
		.AB({AB[10:1], nUDS}),
		
		.DB_OUT(DB_OUT_k051960),
		.DB_IN(DB_IN),
		.DB_DIR(DBDIR_k051960),
		
		.OHF(OHF), .OREG(OREG), .HEND(HEND), .LACH(LACH), .CARY(CARY),
		
		.HP(HP),
		.OC(OC),
		.CA(CA),
		
		.OA_out(OA),
		.OWR(OWR), .OOE(OOE),
		.OD_in(OD_in),
		.OD_out(OD_out)
	);

	// Sprite VRAM
	//ram_sim #(8, 10, "C:/Users/furrtek/Documents/Arcade-TMNT_MiSTer/sim/tools/vram_spr_8.txt") RAM_SPR(OA, OWR, 1'b0, OD_out, OD_in);		// 1k * 8
	ram_sprites RAM_SPRITES(
		.clock(~clk_main),
		.address(OA),
		.q(OD_in),
		.wren(~OWR),
		.data(OD_out)
	);
	
	assign spr_rom_addr = {OC[4], CA[17:10], CA_DEC, CA[3]};
	
	// ../../sim/roms/
	//rom_sim #(32, 19, "C:/Users/furrtek/Documents/Arcade-TMNT_MiSTer/sim/roms/rom_sprites_32.txt") ROM_SPRITES({OC[4], CA[17:10], CA_DEC, CA[3]}, spr_rom_dout);	// 512k * 32
	/*rom_sprites ROM_SPRITES(
		.clock(clk_main),
		.address({OC[4], CA[17:10], CA_DEC, CA[3]}),
		.q(spr_rom_dout),
		.wren(0),		// TODO
		.data(16'h0)	// TODO
	);*/
	
	// Chunky to planar (routing on PCB)
	assign spr_rom_planar = {
		spr_rom_dout[31],	// V
		spr_rom_dout[27],	// R
		spr_rom_dout[23],	// N
		spr_rom_dout[19],	// J
		
		spr_rom_dout[15],	// F
		spr_rom_dout[11],	// B
		spr_rom_dout[7],	// 7
		spr_rom_dout[3],	// 3
		
		spr_rom_dout[30],	// U
		spr_rom_dout[26],	// Q
		spr_rom_dout[22],	// M
		spr_rom_dout[18],	// I
		
		spr_rom_dout[14],	// E
		spr_rom_dout[10],	// A
		spr_rom_dout[6],	// 6
		spr_rom_dout[2],	// 2
		
		spr_rom_dout[29],	// T
		spr_rom_dout[25],	// P
		spr_rom_dout[21],	// L
		spr_rom_dout[17],	// H
		
		spr_rom_dout[13],	// D
		spr_rom_dout[9],	// 9
		spr_rom_dout[5],	// 5
		spr_rom_dout[1],	// 1
		
		spr_rom_dout[28],	// S
		spr_rom_dout[24],	// O
		spr_rom_dout[20],	// K
		spr_rom_dout[16],	// G
		
		spr_rom_dout[12],	// C
		spr_rom_dout[8],	// 8
		spr_rom_dout[4],	// 4
		spr_rom_dout[0]	// 0
	};
	
	// MiSTer specific: load 8-bit ROM from 16-bit data
	reg rom_dec_we, rom_lsb;
	always @(posedge clk) begin
		if (ioctl_download) begin
			if (rom_prom1_we) begin
				rom_lsb <= 1'b0;
				rom_dec_we <= 1'b1;
			end
			if (rom_dec_we & !rom_lsb) begin
				rom_lsb <= 1'b1;
			end
			if (rom_dec_we & rom_lsb) begin
				rom_lsb <= 1'b0;
				rom_dec_we <= 1'b0;
			end
		end else begin
			rom_lsb <= 1'b0;
			rom_dec_we <= 1'b0;
		end
	end

	// clk_sys			_|'|_|'|_|'|_|'|_|'|_|'|_
	// rom_prom1_we	_____|'''|_______________
	// rom_dec_we		_________|'''''''|_______
	// rom_lsb			_____________|'''|_______

	//rom_sim #(8, 8, "C:/Users/furrtek/Documents/Arcade-TMNT_MiSTer/sim/roms/prom_sprdec_8.txt") ROM_SPRDEC({OC[4], CA[17:11]}, PROM_dout);	// 256 * 8
	
	// 256 * 8 (really 256 * 4)
	rom_dec ROM_DEC(
		.clock(~clk),
		.address(ioctl_download ? {rom_addr[7:1], rom_lsb} : {OC[4], CA[17:11]}),
		.q(PROM_dout),
		.wren(rom_dec_we),
		.data(rom_lsb ? rom_data[11:8] : rom_data[3:0])
	);

	always @(*) begin
		case(PROM_dout[2:0])
			3'd0: CA_DEC <= {CA[9], CA[8], CA[7], CA[6], CA[5], CA[4], CA[2], CA[1], CA[0]};
			3'd1: CA_DEC <= {CA[9], CA[8], CA[7], CA[5], CA[6], CA[4], CA[2], CA[1], CA[0]};	// Checked ok
			3'd2: CA_DEC <= {CA[9], CA[8], CA[7], CA[6], CA[4], CA[2], CA[1], CA[0], CA[5]};
			3'd3: CA_DEC <= {CA[9], CA[8], CA[7], CA[6], CA[4], CA[2], CA[1], CA[0], CA[5]};
			3'd4: CA_DEC <= {CA[9], CA[7], CA[8], CA[6], CA[4], CA[2], CA[1], CA[0], CA[5]};
			3'd5: CA_DEC <= {CA[9], CA[8], CA[6], CA[4], CA[2], CA[1], CA[0], CA[7], CA[5]};
			3'd6: CA_DEC <= {CA[9], CA[8], CA[6], CA[4], CA[2], CA[1], CA[0], CA[7], CA[5]};
			3'd7: CA_DEC <= {CA[8], CA[6], CA[4], CA[2], CA[1], CA[0], CA[9], CA[7], CA[5]};
		endcase
	end

	k051937 k051937_1 (
		.clk_96M(clk),
		
		.nRES(~reset),
		.clk_24M(clk_main),
		
		.HVIN(HVOT),
		
		.NRD(NREAD), .OBCS(ODTAC),
		
		.AB({AB[2:1], nUDS}),
		.AB10(AB[11]),
		
		.DB_OUT(DB_OUT_k051937),
		.DB_IN(DB_IN),
		.DB_DIR(DBDIR_k051937),
		
		.SHAD(SHA), .NCO0(NOBJ),
		.OB(OB),

		.CD0(spr_rom_planar[7:0]),
		.CD1(spr_rom_planar[15:8]),
		.CD2(spr_rom_planar[23:16]),
		.CD3(spr_rom_planar[31:24]),

		.OC({OC[7:5], 1'b0, OC[3:0]}),
		.HP(HP),
		.CARY(CARY), .LACH(LACH), .HEND(HEND), .OREG(OREG), .OHF(OHF)
	);
	
endmodule
