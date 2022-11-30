
`define REF_MAX_LENGTH              128
`define READ_MAX_LENGTH             128

//* Score parameters
`define DP_SW_SCORE_BITWIDTH        10

module Scorematrix(
    input                               i_clk,
    input                               i_rst,

    input                               i_start,
    input  [$clog2(`READ_MAX_LENGTH):0] i_i,
    input  [$clog2(`REF_MAX_LENGTH):0]  i_j,
    input                               i_op, // read:0/ write:1
    input  [`DP_SW_SCORE_BITWIDTH-1:0]  i_score,
    output [`DP_SW_SCORE_BITWIDTH-1:0]  o_score
    // output                              o_initial_finish
);




// ===== States =====
localparam S_IDLE   = 0;
// localparam S_INIT   = 1;
localparam S_WORK   = 2;




// ===== Output Buffers =====
logic [`DP_SW_SCORE_BITWIDTH-1:0]  o_score_r, o_score_w;
// logic o_initial_finish_r, o_initial_finish_w;





// ===== Registers =====
logic [`DP_SW_SCORE_BITWIDTH-1:0] matrix_r [0:$clog2(`READ_MAX_LENGTH)][0:$clog2(`REF_MAX_LENGTH)];
logic [`DP_SW_SCORE_BITWIDTH-1:0] matrix_w [0:$clog2(`READ_MAX_LENGTH)][0:$clog2(`REF_MAX_LENGTH)];

logic [2:0] state_r, state_w;


// ===== Output Assignments ===== 
assign o_score = o_score_r;
// assign o_initial_finish = o_initial_finish_r;





// ===== Combinational Circuits ===== 
always_comb begin // state
    state_w = state_r;
	case(state_r)
		S_IDLE: if(i_start) state_w = S_WORK;
		
		default: state_w = state_r;
	endcase
end

always_comb begin // matrix
    matrix_w = matrix_r;
	case(state_r)
		S_WORK: begin
            if (i_op) begin // write
                matrix_w[i_i][i_j] = i_score;
            end
        end
		default: matrix_w = matrix_r;
	endcase
end

always_comb begin // o_score
    o_score_w = o_score_r;
	case(state_r)
		S_WORK: begin
            o_score_w = (i_op) ? `DP_SW_SCORE_BITWIDTH'dz : matrix_r[i_i][i_j];     // 0 for read
        end
		default: o_score_w = o_score_r;
	endcase
end


integer row, col;
// ===== Sequential Circuits =====
always_ff @(posedge i_clk or posedge i_rst) begin
	if(i_rst) begin
		state_r 		<= S_IDLE;
        o_score_r       <= 0;
		for(row=0; row<`READ_MAX_LENGTH; row=row+1)begin
            for(col=0; col<`REF_MAX_LENGTH; col=col+1)begin
                matrix_r[row][col] <= 10'd0;
            end
        end
        

	end
	else begin
		state_r 		<= state_w;
        o_score_r       <= o_score_w;
        matrix_r        <= matrix_w;  
	end 
end



endmodule