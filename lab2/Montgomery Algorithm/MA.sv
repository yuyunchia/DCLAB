



module MontAlg(
	input i_clk,
	input i_rst,
	input MA_start, 
	input [255:0] i_n, 
	input [255:0] MA_a, 
	input [255:0] MA_b, 
	output [255:0] MA_o,
	output MA_end
)
localparam S_IDLE = 3'd0;
localparam S_LONE = 3'd1;
localparam S_LODD = 3'd2;
localparam S_LSFT = 3'd3;
localparam S_POST = 3'd4;

localparam BIT = 9'd256;
local [255:0] MA_o_r, MA_o_w;
local MA_end_r, MA_end_w;
local [9:0] counter_r, counter_w;
local [2:0] state_r, state_w;
local [255:0] MA_a_r, MA_a_w;
local [255:0] MA_b_r, MA_b_w;

assign MA_o = MA_o_r;
assign MA_end = MA_end_r;

// ===== Combinational Blocks =====
always_comb begin //state
	case(state_r)
		S_IDLE: begin
			if(MA_start) state_w = S_LONE;
			else state_w = state_r;
		end

		S_LONE: begin
			state_w = S_LODD;
		end

		S_LODD: begin
			state_w = S_LSFT;
		end

		S_LSFT: begin
			state_w = (counter_r == BIT) ? S_POST : S_LONE;
		end

		S_POST: begin
			state_w = (MA_end_r == 1'b1) ? S_IDLE : state_r;
		end

		default: state_w = state_r;
	endcase
end

always_comb begin //counter
	case(state_r)
		S_IDLE: counter_w = 9'b0;
		S_LSFT: counter_w = counter_r + 1;
		S_POST: counter_w = 9'b0;

		default: counter_w = counter_r;
	endcase
end

always_comb begin //MA_o
	case (state_r)
		S_IDLE: MA_o_w = 256'b0;
		S_LONE: begin
			if(MA_a[counter_r] == 1'b1) MA_o_w = MA_o_r + MA_b;
			else MA_o_w = MA_o_r;
		end

		S_LODD: begin
			if(MA_o_r[0] == 1'b1) MA_o_w = MA_o_r + i_n;
			else MA_o_w = MA_o_r;
		end

		S_LSFT: begin
			MA_o_w = MA_o_r >> 1;
		end

		S_POST: begin
			MA_o_w = (MA_o_r >= i_n) ? MA_o_r - i_n : MA_o_r;
		end

		default: MA_o_w = MA_o_r;
	endcase
end

always_comb begin //MA_end
	case(state_r)
		S_IDLE: MA_end_w = 1'b0;
		S_POST: MA_end_w = 1'b1;
		default: MA_end_w = MA_end_r;
	endcase
end

always_comb begin //MA_a, MA_b
	case(state_r)
		S_IDLE: begin
			MA_a_w = MA_a;
			MA_b_w = MA_b;
		end
		default: begin
			MA_a_w = MA_a_r;
			MA_b_w = MA_b_r;
		end
	endcase
end

// ===== Sequential Blocks =====
always_ff @(posedge i_clk) begin
	if(i_rst) begin
		state_r 	<= S_IDLE;
		MA_o_r 		<= 256'b0;
		MA_end_r 	<= 1'b0;
		counter_r 	<= 9'b0;
		MA_a_r 		<= MA_a;
		MA_b_r 		<= MA_b;
	end
	else begin
		state_r 	<= state_w;
		MA_o_r 		<= MA_o_w;
		MA_end_r 	<= MA_end_w;
		counter_r 	<= counter_w;
		MA_a_r 		<= MA_a_w;
		MA_b_r 		<= MA_b_w;
	end
	
end

endmodule





