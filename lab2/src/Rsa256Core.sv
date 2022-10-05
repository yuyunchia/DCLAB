module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // cipher text y
	input  [255:0] i_d, // private key
	input  [255:0] i_n, // divisor
	output [255:0] o_a_pow_d, // plain text x
	output         o_finished // the whole process has done
);

// operations for RSA256 decryption
// namely, the Montgomery algorithm

// ===== States =====
localparam S_IDLE   = 2'd0;
localparam S_PREP   = 2'd1;
localparam S_MONT   = 2'd2;
localparam S_CALC   = 2'd3;

// ===== Output Buffers =====
logic [255:0] o_a_pow_d_r, o_a_pow_d_w;
logic o_finished_r, o_finished_w;

// ===== Parameters =====
localparam BIT = 9'd256;
logic [8:0] M_counter_r, M_counter_w;
logic [8:0] MP_counter_r, MP_counter_w;
logic [255:0] MP_temp_r, MP_temp_w; 	// parameter in ModuloProduct
logic [255:0] MP_r, MP_w; 				// output for ModuloProduct
logic [2:0] state_r, state_w;

logic MA_start_r, MA_start_w; 			// Montgomery Algorithm parameter
logic [255:0] MA_a_r, MA_a_w;
logic [255:0] MA_b_r, MA_b_w;
logic MA_end;
logic [255:0] MA_o;

MontAlg ma1(
	.i_clk(i_clk),
	.i_rst(i_rst),
	.i_MA_start(MA_start_r),
	.i_n(i_n),
	.i_MA_a(MA_a_r),
	.i_MA_b(MA_b_r),
	.o_MA(MA_o),
	.o_MA_end(MA_end)
);


// ===== Output Assignments ===== 
assign o_a_pow_d = o_a_pow_d_r;
assign o_finished = o_finished_r;

// ===== Combinational Circuits ===== 
always_comb begin // M_counter
	case(state_r)
		S_IDLE: begin 
			M_counter_w = 9'b0;
		end

		S_CALC: begin
			M_counter_w = (M_counter_r < BIT) ? M_counter_r + 1 : M_counter_r; // 0~255
		end

		default: M_counter_w = M_counter_r;
	endcase
end

always_comb begin // MP_counter
	case(state_r)
		S_IDLE: begin 
			MP_counter_w = 9'b0;
		end

		S_PREP: begin
			MP_counter_w = (MP_counter_r < BIT) ? MP_counter_r + 1 : MP_counter_r; // 0~255
		end

		S_MONT: begin
			MP_counter_w = 9'b0;
		end

		default: MP_counter_w = MP_counter_r;
	endcase
end

always_comb begin //state
	case(state_r) 
		S_IDLE: begin
			if(i_start) state_w = S_PREP;
			else state_w = state_r;
		end
		
		S_PREP: begin
			if(i_start) state_w = S_PREP;
			else state_w = (MP_counter_r == BIT) ? S_MONT : state_r;
		end

		S_MONT: begin
			if(i_start) state_w = S_PREP;
			else state_w = (MA_end == 1) ? S_CALC : state_r;
		end

		S_CALC: begin
			if(i_start) state_w = S_PREP;
			else begin
				if(M_counter_r == BIT) state_w = S_IDLE;
				else if (MA_end == 1 && M_counter_r < BIT) state_w = S_MONT;
				else state_w = state_r;
			end
		end

		default: begin
			state_w = state_r;
		end

	endcase
end

always_comb begin //o_finished
	case(state_r)
		S_IDLE: begin
			o_finished_w = 1'b0;
		end

		S_CALC: begin
			o_finished_w = (M_counter_r == BIT) ? 1'b1 : o_finished_r;
		end

		default: o_finished_w = o_finished_r;
	endcase
	
end

always_comb begin //ModuloProduct
	case(state_r)
		S_IDLE: begin
			MP_temp_w = i_a;
			MP_w = 256'd0;
		end

		S_PREP: begin // create i_a * 2^256
			if (MP_counter_r < BIT) begin
				MP_temp_w = (MP_temp_r + MP_temp_r > i_n) ? MP_temp_r + MP_temp_r - i_n : MP_temp_r + MP_temp_r;
			end
			else begin 
				MP_w = (MP_r + MP_temp_r >= i_n) ? MP_r + MP_temp_r - i_n : MP_temp_r + MP_r;
				MP_temp_w = (MP_temp_r + MP_temp_r > i_n) ? MP_temp_r + MP_temp_r - i_n : MP_temp_r + MP_temp_r;
			end
			
		end

		default: begin
			MP_w = MP_r; 
			MP_temp_w = MP_temp_r;
		end
	endcase
end

always_comb begin //Montgomery Algorithm
	case(state_r)
		S_IDLE: begin
			MA_start_w = 1'b0;
			o_a_pow_d_w = 256'b1;
			MA_a_w = 256'd0;
			MA_b_w = 256'd0;
			MP_w   = 256'd0 ;
		end

		S_MONT: begin
			MP_w = MP_r;
			if(M_counter_r < BIT) begin
				if(i_d[M_counter_r] == 1'b1) begin
					MA_a_w = o_a_pow_d_r;
					MA_b_w = MP_r;
					MA_start_w = 1'b1;
					
					if(MA_end == 1'b1) begin
						MA_start_w = 1'b0;
						o_a_pow_d_w = MA_o;
					end
					else begin
						MA_start_w = MA_start_r;
						o_a_pow_d_w = o_a_pow_d_r;
					end
				end
				
			end

			else begin 
				o_a_pow_d_w = o_a_pow_d_r;
				MA_start_w = MA_start_r;
				MA_a_w = MA_a_r;
				MA_b_w = MA_b_r;
			end
		end

		S_CALC: begin
			if(M_counter_r < BIT) begin
				MA_a_w = MP_r;
				MA_b_w = MP_r;
				MA_start_w = 1'b1;

				if(MA_end == 1'b1) begin
					MA_start_w = 1'b0;
					MP_w = MA_o;
				end
				else begin
					MA_start_w = MA_start_r;
					MP_w = MP_r;
				end
			end

			else begin
				MP_w = MP_r;
				MA_start_w = MA_start_r;
				MA_a_w = MA_a_r;
				MA_b_w = MA_b_r;
			end
		end

		default: begin
			o_a_pow_d_w = o_a_pow_d_r;
			MP_w = MP_r;
			MA_start_w = MA_start_r;
			MA_a_w = MA_a_r;
			MA_b_w = MA_b_r;
		end

	endcase
end

// ===== Sequential Circuits =====
always_ff @(posedge i_clk or negedge i_rst) begin
	if(i_rst) begin
		state_r 		<= S_IDLE;
		o_a_pow_d_r 	<= 256'b1;
		o_finished_r 	<= 1'd0;
		M_counter_r 	<= 256'b0;
		MP_counter_r 	<= 256'b0;
		MP_temp_r 		<= 256'b0;
		MP_r 			<= 256'b0;
		MA_start_r 		<= 256'b0;
		MA_a_r			<= 256'b0;
		MA_b_r 			<= 256'b0;
	end
	else begin
		state_r 		<= state_w;
		o_a_pow_d_r 	<= o_a_pow_d_w;
		o_finished_r 	<= o_finished_w;
		M_counter_r 	<= M_counter_w;
		MP_counter_r 	<= MP_counter_w;
		MP_temp_r 		<= MP_temp_w;
		MP_r 			<= MP_w;
		MA_start_r 		<= MA_start_w;
		MA_a_r			<= MA_a_w;
		MA_b_r 			<= MA_b_w;
	end 
end
endmodule


module MontAlg(
	input i_clk,
	input i_rst,
	input i_MA_start, 
	input [255:0] i_n, 
	input [255:0] i_MA_a, 
	input [255:0] i_MA_b, 
	output [255:0] o_MA,
	output o_MA_end
);

localparam S_IDLE = 3'd0;
localparam S_LONE = 3'd1;
localparam S_LODD = 3'd2;
localparam S_LSFT = 3'd3;
localparam S_POST = 3'd4;

localparam BIT = 9'd256;
logic [255:0] o_MA_r, o_MA_w;
logic o_MA_end_r, o_MA_end_w;
logic [9:0] counter_r, counter_w;
logic [2:0] state_r, state_w;
//local [255:0] MA_a_r, MA_a_w;
//local [255:0] MA_b_r, MA_b_w;

assign o_MA = o_MA_r;
assign o_MA_end = o_MA_end_r;
//assign MA_a_w = MA_a;
//assign MA_b_w = MA_b;

// ===== Combinational Blocks =====
always_comb begin //state
	case(state_r)
		S_IDLE: begin
			if(i_MA_start) state_w = S_LONE;
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
			state_w = (o_MA_end_r == 1'b1) ? S_IDLE : state_r;
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
		S_IDLE: o_MA_w = 256'b0;
		S_LONE: begin
			if(i_MA_a[counter_r] == 1'b1) o_MA_w = o_MA_r + i_MA_b;
			else o_MA_w = o_MA_r;
		end

		S_LODD: begin
			if(o_MA_r[0] == 1'b1) o_MA_w = o_MA_r + i_n;
			else o_MA_w = o_MA_r;
		end

		S_LSFT: begin
			o_MA_w = o_MA_r >> 1;
		end

		S_POST: begin
			o_MA_w = (o_MA_r >= i_n) ? o_MA_r - i_n : o_MA_r;
		end

		default: o_MA_w = o_MA_r;
	endcase
end

always_comb begin //MA_end
	case(state_r)
		S_IDLE: o_MA_end_w = 1'b0;
		S_POST: o_MA_end_w = 1'b1;
		default: o_MA_end_w = o_MA_end_r;
	endcase
end

/*always_comb begin //MA_a, MA_b
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
end*/

// ===== Sequential Blocks =====
always_ff @(posedge i_clk) begin
	if(i_rst) begin
		state_r 	<= S_IDLE;
		o_MA_r 		<= 256'b0;
		o_MA_end_r 	<= 1'b0;
		counter_r 	<= 9'b0;
		//MA_a_r 		<= MA_a;
		//MA_b_r 		<= MA_b;
	end
	else begin
		state_r 	<= state_w;
		o_MA_r 		<= o_MA_w;
		o_MA_end_r 	<= o_MA_end_w;
		counter_r 	<= counter_w;
		//MA_a_r 		<= MA_a_w;
		//MA_b_r 		<= MA_b_w;
	end
	
end

endmodule