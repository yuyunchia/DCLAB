
`define REF_MAX_LENGTH              128
`define READ_MAX_LENGTH             128

`define REF_LENGTH                  128
`define READ_LENGTH                 128

//* Score parameters
`define DP_SW_SCORE_BITWIDTH        10

`define CONST_MATCH_SCORE           1
`define CONST_MISMATCH_SCORE        -4
`define CONST_GAP_OPEN              -6
`define CONST_GAP_EXTEND            -1

// SW Core --------------------------------------------
module SW_core(
    input                                       clk,
    input                                       rst,   
   
    output reg                                  o_ready,
    input                                       i_valid,
    input [2*`REF_MAX_LENGTH-1:0]               i_sequence_ref,     // reference seq
    input [2*`READ_MAX_LENGTH-1:0]              i_sequence_read,    // read seq
    input [$clog2(`REF_MAX_LENGTH):0]           i_seq_ref_length,   // (1-based)
    input [$clog2(`READ_MAX_LENGTH):0]          i_seq_read_length,  // (1-based)

    input                                       i_ready,
    output reg                                  o_valid,
    output signed [`DP_SW_SCORE_BITWIDTH-1:0]   o_alignment_score,
    output reg [$clog2(`REF_MAX_LENGTH)-1:0]    o_column,
    output reg [$clog2(`READ_MAX_LENGTH)-1:0]   o_row
);



// ===== States =====
localparam S_IDLE   = 0;
localparam S_WORK   = 1;
localparam S_FINISH = 2;




logic [2:0] state_r, state_w;

logic [$clog2(`READ_MAX_LENGTH):0] align_scores_i_r, align_scores_i_w; 
logic [$clog2(`READ_MAX_LENGTH):0] align_scores_j_r, align_scores_j_w; 

logic [`DP_SW_SCORE_BITWIDTH-1:0]  align_scores_i_score;
logic [`DP_SW_SCORE_BITWIDTH-1:0]  align_scores_o_score;


logic [9:0] counter_i_r, counter_i_w;
logic [9:0] counter_j_r, counter_j_w;



Scorematrix align_scores(
    .i_clk(clk),
    .i_rst(rst),
    .i_start(1),
    .i_i(align_scores_i_r),                    // input  [$clog2(`READ_MAX_LENGTH):0] i_i,
    .i_j(align_scores_j_r),                    // input  [$clog2(`REF_MAX_LENGTH):0]  i_j,
    .i_op(1),                   // input                               i_op, // read:0/ write:1
    .i_score(align_scores_i_score),                // input  [`DP_SW_SCORE_BITWIDTH-1:0]  i_score,
    .o_score(align_scores_o_score)                 // output [`DP_SW_SCORE_BITWIDTH-1:0]  o_score
);


assign align_scores_i_w = counter_i_r;
assign align_scores_j_w = counter_j_r;
assign align_scores_i_score = counter_i_r + counter_j_r;


// ===== Combinational Circuits ===== 
always_comb begin // state
    state_w = state_r;
	case(state_r)
		S_IDLE: state_w = S_WORK;
        S_WORK: if(counter_i_r == 63 && counter_j_r == 63) state_w = S_FINISH;
		default: state_w = state_r;
	endcase
end

always_comb begin // counter
    counter_i_w = counter_i_r;
    counter_j_w = counter_j_r;

	case(state_r)
		S_WORK: begin
            counter_i_w = (counter_i_r == 63) ? 0 : counter_i_r + 1;
            if (counter_i_r == 63 && counter_j_r == 63) counter_j_w = 0;
            else if (counter_i_r == 63) counter_j_w = counter_j_r + 1;
        end
	endcase
end

// always_comb begin // align_scores
  
// end

// ===== Sequential Circuits =====
always_ff @(posedge clk or posedge rst) begin
	if(rst) begin
		state_r 		   <= S_IDLE;
        align_scores_i_r   <= 0; 
        align_scores_j_r   <= 0; 
        counter_i_r        <= 0;
        counter_j_r        <= 0;
		
        

	end
	else begin
        state_r 		   <= state_w;
        align_scores_i_r   <= align_scores_i_w; 
        align_scores_j_r   <= align_scores_j_w; 
        counter_i_r        <= counter_i_w;
        counter_j_r        <= counter_j_w;
	end 
end
    

endmodule

/*
logic [$clog2(`READ_MAX_LENGTH):0] align_scores_i_r, align_scores_i_w; 
logic [$clog2(`READ_MAX_LENGTH):0] align_scores_j_r, align_scores_j_w; 

logic [`DP_SW_SCORE_BITWIDTH-1:0]  align_scores_i_score;
logic [`DP_SW_SCORE_BITWIDTH-1:0]  align_scores_o_score;


logic [7:0] counter_i_r, counter_i_w;
logic [7:0] counter_j_r, counter_j_w;


*/