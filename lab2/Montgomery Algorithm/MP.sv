
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


		// assign MP_a_w = i_MP_a;
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
					state_w = (i_MP_start == 1'b1)? S_SHFT : state_r; // S)WORK => S_SHFT
				end

				S_SHFT: begin
					state_w = (counter_r <= BIT) ? S_CIRC : state_r;
				end

				S_CIRC: begin
					state_w = (counter_r == BIT) ? S_LAST : S_SHFT;
                end
				S_LAST: begin
					state_w = (MP_end_r == 1'b1) ? S_IDLE : state_r;
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

				S_SHFT: begin // S_WORK -> S_SHFT
					MP_a_w = (counter_r == BIT) ? MP_a_r : MP_a_r << 1;
				end

				S_CIRC: begin
					MP_a_w = (counter_r < BIT && MP_a_r >= i_n) ? MP_a_r - i_n : MP_a_r;
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
					// MP_out_w = (MP_end_r == 1'b1) ? MP_a_r : MP_out_r; 
                    // MP_out_w = (counter == BIT) ? MP_a_r : MP_out_r; 
                    MP_out_w =  MP_a_r; 
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
				MP_a_r 			<= i_MP_a;
			end
			else begin
				state_r 		<= state_w;
				MP_out_r 		<= MP_out_w;
				MP_end_r 		<= MP_end_w;
				counter_r 		<= counter_w;
				MP_a_r 			<= MP_a_w;
			end
		end
			


endmodule