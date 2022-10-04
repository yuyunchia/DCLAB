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
localparam S_CALC    = 2'd3;

// ===== Output Buffers =====
logic [255:0] o_a_pow_d_r, o_a_pow_d_w;
logic o_finished_r, o_finished_w;

// ===== Parameters =====
localparam BIT = 9'd256
logic [8:0] M_counter_r, M_counter_w;
logic [8:0] MP_counter_r, MP_counter_w;
logic [255:0] MP_temp_r, MP_temp_w; 	// parameter in ModuloProduct
logic [255:0] MP_r, MP_w; 				// output for ModuloProduct
logic MA_start_r, MA_start_w; 			// Montgomery Algorithm start
logic MA_end_r, MA_end_w; 				// Montgomery Algorithm end
logic [2:0] state_r, state_w;


// ===== Output Assignments ===== 
assign o_a_pow_d = o_a_pow_d_r;
assign o_finished = o_finished_r;

// ===== Combinational Circuits ===== 
always_comb begin // M_counter
	case(state_r)
		S_IDLE: begin 
			M_counter_w = 9'b0;
		end

		S_MONT: begin
			M_counter_w = (M_counter_r < BIT) ? M_counter_r + 1 : M_counter_r; // 0~255
		end

		S_CALC: begin
			M_counter_w = 9'b0;
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
			else state_w = (M_counter_r == BIT) ? S_CALC : state_r;
		end

		/*S_CALC: begin
			if(i_start) state_w = S_PREP;
			else begin
				if (COUNTER_r != BIT) begin
					if(i_d[COUNTER_r] == 1'b1 && m_counter_r == t_counter_r) begin
						state_w = S_MONT;
					end
					else if(m_counter_r != t_counter_r) state_w = S_MONT;
					else state_w = state_r;
				end
				else state_w = S_IDLE;

			end
		end*/
		default: state_w = state_r;

	endcase
end

always_comb begin //o_finished
	case(state_r)
		S_IDLE: begin
			o_finished_w = 1'b0;
		end

		S_MONT: begin
			if(M_counter_r == BIT) o_finished_w = 1'b1;
			else o_finished_w = 1'b0;
		end

		default: o_finished_w = o_finished_r;
	endcase
	o_finished_w = (M_counter_r == BIT) ? 1'b1 : o_finished_r;
end

always_comb begin //ModuloProduct
	case(state_r)
		S_IDLE: begin
			MP_temp_w = i_a;
			MP_w = 256'b0;
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
			MA_end_w = 1'b0;
			o_a_pow_d_w = 256'b0;
		end

		S_MONT: begin
			if(M_counter_r != BIT) begin
				if(i_d[M_counter_r] == 1'b1) begin
					MA_start_w = 1'b1;
					MA_end_w = 1'b0; 
					MontAlg ma1(
						.i_clk(i_clk),
						.i_rst(i_rst),
						.MA_start(MA_start_w),
						.i_n(i_n),
						.MA_a(o_a_pow_d_r),
						.MA_b(MP_r),
						.MA_o(o_a_pow_w),
						.MA_end(MA_end_w)
					)

					if(MA_end_w == 1'b1) MA_start_w = 1'b0;
					else MA_start_w = MA_start_r;

				end
				else begin
					o_a_pow_d_w = o_a_pow_d_r;
					MA_start_m_w = MA_start_m_r;
					MA_start_t_w = MA_start_t_r;
					MA_end_m_w = MA_end_m_r;
					MA_end_t_w = MA_end_t_r;
				end

				if (MA_end_w == 1'b1) begin
					MA_start_w = 1'b1;
					MA_end_w = 1'b0;
					MontAlg ma2(
							.i_clk(i_clk),
							.i_rst(i_rst),
							.MA_start(MA_start_w),
							.i_n(i_n),
							.MA_a(MP_r),
							.MA_b(MP_r),
							.MA_o(MP_w),
							.MA_end(MA_end_w)
						)
					if(MA_end_w == 1'b1) MA_start_w = 1'b0;
					else MA_start_w = MA_start_r;
				end
				else begin
					o_a_pow_d_w = o_a_pow_d_r;
					MA_start_m_w = MA_start_m_r;
					MA_start_t_w = MA_start_t_r;
					MA_end_m_w = MA_end_m_r;
					MA_end_t_w = MA_end_t_r;
				end
			end

			else begin 
				o_a_pow_d_w = o_a_pow_d_r;
				MA_start_m_w = MA_start_m_r;
				MA_start_t_w = MA_start_t_r;
				MA_end_m_w = MA_end_m_r;
				MA_end_t_w = MA_end_t_r;
			end
		end

		default: begin
			o_a_pow_d_w = o_a_pow_d_r;
			MA_start_m_w = MA_start_m_r;
			MA_start_t_w = MA_start_t_r;
			MA_end_m_w = MA_end_m_r;
			MA_end_t_w = MA_end_t_r;
		end

	endcase
end

always_comb begin //o_a_pow_d
	case(state_r) begin
		S_IDLE: begin
			o_a_pow_d_w = 256'b0;
		end

		S_MONT: begin
			o_a_pow_d_w = o_a_pow_d_r;
		end

		default: o_a_pow_d_w = o_a_pow_d_r;
	endcase

end



// ===== Sequential Circuits =====
always_ff @(posedge i_clk or negedge i_rst) begin
	if(i_rst) begin
		state_r 		<= S_IDLE;
		o_a_pow_d_r 	<= 256'b0;
		o_finished_r 	<= 1'd0;
		M_counter_r 	<= 256'b0;
		MP_counter_r 	<= 256'b0;
		m_counter_r 	<= 256'b0;
		t_counter_r 	<= 256'b0;
		COUNTER_r 		<= 256'b0;
		MP_temp_r 		<= 256'b0;
		MP_r 			<= 256'b0;
		MP_b_r 			<= 256'b0;
		MA_o_r 			<= 256'b0;
		MA_a_r 			<= 256'b0;
		MA_b_r 			<= 256'b0;
	end
	else begin
		o_finished_r 	<= o_finished_w;
		o_a_pow_d_r 	<= o_a_pow_d_w;
		state_r 		<= state_w;
		M_counter_r 	<= M_counter_w;
		MP_counter_r 	<= MP_counter_w;
		m_counter_r 	<= m_counter_w;
		t_counter_r 	<= t_counter_w;
		COUNTER_r 		<= COUNTER_w;
		MP_temp_r 		<= MP_temp_w;
		MP_r 			<= MP_w;
		MP_b_r 			<= MP_b_w;
		MA_o_r 			<= MA_o_w;
		MA_a_r 			<= MA_a_w;
		MA_b_r 			<= MA_b_w;
	end 
endmodule


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