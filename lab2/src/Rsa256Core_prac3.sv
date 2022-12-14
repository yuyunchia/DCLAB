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
logic [269:0] o_a_pow_d_r, o_a_pow_d_w;
logic o_finished_r, o_finished_w;

// ===== Parameters =====
localparam BIT = 9'd255;
logic [8:0] M_counter_r, M_counter_w;

logic MP_start_r, MP_start_w;
logic [269:0] MP_r, MP_w; 				// output for ModuloProduct
logic [269:0] t_r, t_w; 				
logic [2:0] state_r, state_w;

logic MA_start_r, MA_start_w; 			// Montgomery Algorithm parameter
logic [269:0] MA_a_r, MA_a_w;
logic [269:0] MA_b_r, MA_b_w;
logic MA_end;
logic [269:0] MA_o;

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
			M_counter_w = (M_counter_r < BIT && MA_end == 1'd1) ? M_counter_r + 1 : M_counter_r; // 0~255
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
			else if (M_counter_r < BIT) begin
				if (i_d[M_counter_r] == 1'b1 && MA_end == 1) state_w = S_CALC;
				else if (i_d[M_counter_r] == 1'b0) state_w = S_CALC;
				else state_w = state_r;
			end
			else state_w = state_r;
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

always_comb begin // t
	case(state_r)
		S_IDLE: begin
			t_w = 256'd0;
		end

		S_PREP: begin
			t_w = (MP_counter_r == BIT) ? MP_r : t_r;
		end

		S_CALC: begin
			if(M_counter_r < BIT && MA_end == 1'b1) t_w = MA_o;
			else t_w = t_r;
		end 

		default: t_w = t_r;
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
		end

		S_MONT: begin
			if(M_counter_r < BIT) begin
				// if(i_d[M_counter_r] == 1'b1) begin
				// 		MA_a_w = o_a_pow_d_r;  // MA_a = m
				// 		MA_b_w = MP_r;         // MA_b = t
				// 		MA_start_w = 1'b1;    
						
				// 		if(MA_end == 1'b1) begin
				// 				MA_start_w = 1'b0;
				// 				o_a_pow_d_w = MA_o;
				// 		end
				// 		else begin
				// 				MA_start_w = MA_start_r;
				// 				o_a_pow_d_w = o_a_pow_d_r;
				// 		end
				// end
				if(MA_end == 1'b1) begin
					MA_start_w = 1'b0;
					MA_a_w = MA_a_r;
					MA_b_w = MA_b_r;
				 	o_a_pow_d_w = MA_o;
				end
				else if (i_d[M_counter_r] == 1'b1) begin
						MA_a_w = o_a_pow_d_r;
						MA_b_w = MP_r;
						MA_start_w = 1'b1;
						o_a_pow_d_w = o_a_pow_d_r;
				end
				else begin
						MA_start_w = MA_start_r;
						MA_a_w = MA_a_r;
						MA_b_w = MA_b_r;
						o_a_pow_d_w = o_a_pow_d_r;
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
			// if(M_counter_r < BIT) begin
			// 		MA_a_w = MP_r;
			// 		MA_b_w = MP_r;
			// 		MA_start_w = 1'b1;

			// 	if(MA_end == 1'b1) begin
			// 		MA_start_w = 1'b0;
			// 	end
			// 	else begin
			// 		MA_start_w = MA_start_r;
			// 	end
			// end
			// else begin
			// 		MA_start_w = MA_start_r;
			// 		MA_a_w = MA_a_r;
			// 		MA_b_w = MA_b_r;
			// end
			if(MA_end == 1'b1) begin
					MA_start_w = 1'b0;
					MA_a_w = MA_a_r;
					MA_b_w = MA_b_r;
					o_a_pow_d_w = o_a_pow_d_r;
			end
			else if (M_counter_r < BIT) begin
					MA_a_w = MP_r;
					MA_b_w = MP_r;
					MA_start_w = 1'b1;
					o_a_pow_d_w = o_a_pow_d_r;
			end
			else begin
					MA_start_w = MA_start_r;
					MA_a_w = MA_a_r;
					MA_b_w = MA_b_r;
					o_a_pow_d_w = o_a_pow_d_r;
			end
		end

		default: begin
			o_a_pow_d_w = o_a_pow_d_r;
			MA_start_w = MA_start_r;
			MA_a_w = MA_a_r;
			MA_b_w = MA_b_r;
		end

	endcase
end

// ===== Sequential Circuits =====
always_ff @(posedge i_clk or posedge i_rst) begin
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
		t_r 			<= 256'b0;
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
		t_r 			<= t_w;
	end 
end
endmodule


module MontAlg(
	input i_clk,
	input i_rst,
	input i_MA_start, 
	input [255:0] i_n, 
	input [269:0] i_MA_a, 
	input [269:0] i_MA_b, 
	output [269:0] o_MA,
	output o_MA_end
);

localparam S_IDLE = 3'd0;
localparam S_LONE = 3'd1;
localparam S_LODD = 3'd2;
localparam S_LSFT = 3'd3;
localparam S_POST = 3'd4;

localparam BIT = 9'd255;
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
			// state_w = (o_MA_end_r == 1'b1) ? S_IDLE : state_r;
			state_w = S_IDLE;
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
always_ff @(posedge i_clk or posedge i_rst) begin
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

module ModProd (
	input 			i_clk,
	input 			i_rst,
	input 			i_MP_start,
	input [255:0] 	i_n,
	input [269:0] 	i_MP_a,
	output [269:0] 	o_MP_a,
	output 			o_MP_end
);

localparam S_IDLE = 2'd0;
localparam S_SHFT = 2'd1;
localparam S_CIRC = 2'd2;
localparam S_LAST = 2'd3;

localparam 		BIT = 9'd256;
logic [2:0] 	state_r, state_w;
logic [269:0] 	MP_a_w, MP_a_r;
logic [9:0] 	counter_w, counter_r;
logic [269:0] 	MP_out_w, MP_out_r;
logic 			MP_end_w, MP_end_r;


assign MP_a_w = i_MP_a;
assign o_MP_a = MP_out_r;
assign o_MP_end = MP_end_r;

// ===== Combinational blocks =====
always_comb begin //counter
	case(state_r)
		S_IDLE: begin
			counter_w = 9'b0;
		end

		S_CIRC: begin
			counter_w = (counter_r == BIT) ? counter_r : counter_r + 1;
		end

		default: counter_w = counter_r; 
	endcase
end

always_comb begin //state
	case(state_r)
		S_IDLE: begin
			state_w = (i_MP_start == 1'b1)? S_WORK : state_r;
		end

		S_SHFT: begin
			state_w = (counter_r <= BIT) ? S_CIRC : state_r;
		end

		S_CIRC: begin
			state_w = (counter_r == BIT) ? S_LAST : S_SHFT;

		S_LAST: begin
			state_w = (MP_end r == 1'b1) ? S_IDLE : state_r;
		end
		default: state_w = state_r;
	endcase
end

always_comb begin //MP_end
	case(state_r)
		S_IDLE: begin
			MP_end_w = 1'b0;
		end

		S_LAST: begin
			MP_end_w = (counter_r == BIT) ? 1'b1 : MP_end_r;
		end

		default: MP_end_w = MP_end_r;
	endcase
end

always_comb begin //MP_a
	case(state_r)
		S_IDLE: begin
			MP_a_w = i_MP_a;
		end

		S_WORK: begin
			MP_a_w = (counter_r == BIT) ? MP_a_r : MP_a_r << 1;
		end

		S_CIRC: begin
			MP_a_w = (counter_r < BIT && MP_a_r >= i_n) ? MP_a_r - 1 : MP_a_r;
		end

		S_LAST: begin
			MP_a_w = (counter_r == BIT && MP_a_r >= i_n) ? MP_a_r - i_n : MP_a_r;
		end

		default: MP_a_w = MP_a_r;
	endcase
end

always_comb begin //MP_out
	case(state_r)
		S_IDLE: begin
			MP_out_w = 269'd0;
		end

		S_LAST: begin
			MP_out_w = (MP_end_r == 1'b1) ? MP_a_r : MP_out_r;
		end
		default:  MP_out_w = MP_out_r;
	endcase
end

// ===== Sequential blocks =====
always_ff @(posedge i_clk or posedge i_rst) begin
	if(i_rst) begin
		state_r 		<= S_IDLE;
		MP_out_r 		<= 269'b0;
		MP_end_r 		<= 1'b0;
		counter_r 		<= 9'b0;
		MA_a_r 			<= i_MP_a;
	end
	else begin
		state_r 		<= state_w;
		MP_out_r 		<= MP_out_w;
		MP_end_r 		<= MP_end_w;
		counter_r 		<= counter_w;
		MP_a_r 			<= MP_a_w;
	end
end
	
end

endmodule