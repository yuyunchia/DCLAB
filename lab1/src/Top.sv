module Top(
	input        i_clk,
	input        i_rst_n,
	input        i_start,
    input        i_start_2,
	output [3:0] o_random_out,
    output [3:0] o_random_out_2
);

// ===== States =====
localparam S_IDLE   = 4'd0;
localparam S_WAIT   = 4'd1;
localparam S_INIT   = 4'd2;
localparam S_RUN    = 4'd3;
localparam S_CHANGE = 4'd4;

localparam FREQ = 50000000;
//localparam CYCLE = 7;   // FREQ/5;   
localparam CYCLE = FREQ/50; 

// ===== Output Buffers =====
logic [3:0] o_random_out_r, o_random_out_w;
logic [3:0] o_random_out_2_r, o_random_out_2_w;

// ===== Registers & Wires =====
logic [63:0] counter_r, counter_w;
logic [3:0] state_r, state_w;
logic [3:0] LFSR_r,  LFSR_w;
logic [7:0] P_counter_r, P_counter_w;
logic [7:0] D_counter_r, D_counter_w;
logic [7:0] PERIOD_r, PERIOD_w;
logic [7:0] DNUM_r, DNUM_w;

// ===== Output Assignments =====
assign o_random_out   = o_random_out_r;
assign o_random_out_2 = o_random_out_2_r;



// ===== Combinational Circuits =====

always_comb begin // o_random_out_2
    // if (i_start_2) o_random_out_2_w = (o_random_out_2_r == 4'b1111) ? 4'd0 : o_random_out_2_r + 4'd1;
    if (i_start_2) o_random_out_2_w = o_random_out_r;
    else o_random_out_2_w = o_random_out_2_r;
end

always_comb begin // counter
    if (i_start) counter_w = 64'd0;
    else counter_w = (counter_r == CYCLE-1) ? 64'd0 : counter_r + 64'd1;
end

always_comb begin // LFSR
    // liberate insert 0000 into cycle 
    // 0110 -> 1100 to 0110 -> 0000 -> 1100
    if (counter_r == CYCLE-1) begin 
        if (LFSR_r == 4'b0110) LFSR_w[3:0] = 4'b0000;
        else if (LFSR_r == 4'b0000) LFSR_w[3:0] = 4'b1100;
        else begin
            LFSR_w[3] = LFSR_r[2];
            LFSR_w[2] = LFSR_r[1];
            LFSR_w[1] = LFSR_r[0] ^ LFSR_r[3]; // xor 
            LFSR_w[0] = LFSR_r[3];
        end
    end
    else LFSR_w[3:0] = LFSR_r[3:0];
end

always_comb begin // state
	case(state_r)
    S_IDLE: begin
        if (counter_r == CYCLE-1)  state_w = S_WAIT;
        else state_w = state_r;
    end

    S_WAIT: begin
        if (i_start) state_w = S_INIT;
        else state_w = state_r;
    end

    S_INIT: begin
        if (i_start) state_w = S_INIT;
        else begin
            if (counter_r == CYCLE-1)  state_w = S_RUN;
            else state_w = state_r;
        end
    end

    S_RUN:  begin
        if (i_start) state_w = S_INIT;
        else begin
            if (counter_r == CYCLE-1) begin
                if (P_counter_r == PERIOD_r) state_w = S_CHANGE;
                else state_w = S_RUN;
            end
            else state_w = state_r;
        end
    end

    S_CHANGE: begin 
        if (i_start) state_w = S_INIT;
        else begin
            if (counter_r == CYCLE-1) begin
                if (DNUM_r == 8'd1) state_w = S_WAIT;
                else state_w = S_RUN;
            end
            else state_w = state_r;
        end
    end

    default: begin
        state_w = state_r;
    end

    endcase

end





always_comb begin // DNUM, PERIOD

    case(state_r)
	S_INIT: begin
        DNUM_w = 8'd16;
        PERIOD_w = 8'd1;
    end

    S_CHANGE: begin
        if (counter_r == CYCLE-1) begin
            if (D_counter_r == DNUM_r) begin
                DNUM_w = DNUM_r >> 1;
                PERIOD_w = PERIOD_r << 1;
            end
            else begin
                DNUM_w = DNUM_r;
                PERIOD_w = PERIOD_r;
            end
        end
        else begin
            DNUM_w = DNUM_r;
            PERIOD_w = PERIOD_r;
        end

    end
    default: begin
        DNUM_w = DNUM_r;
        PERIOD_w = PERIOD_r;
    end

    endcase
end

always_comb begin // P_counter

    case(state_r)   
	S_INIT:   P_counter_w = 8'd0;
    S_RUN :   P_counter_w = (counter_r == CYCLE-1) ? P_counter_r + 8'd1 : P_counter_r;
    S_CHANGE: P_counter_w = 8'd0;
    default:  P_counter_w = P_counter_r;
    endcase

end

always_comb begin // D_counter

    case(state_r)
	S_INIT:   D_counter_w = 8'd0;
    S_CHANGE: begin
        if (counter_r == CYCLE-1) begin
            if (D_counter_r == DNUM_r) D_counter_w = 8'd0;
            else D_counter_w = D_counter_r + 8'd1;
        end
        else D_counter_w = D_counter_r;
    end
    default:  D_counter_w = D_counter_r;
    endcase

end


always_comb begin // o_random_out
    case(state_r)
    S_CHANGE: o_random_out_w = (counter_r == CYCLE-1) ? LFSR_r : o_random_out_r;
    default:  o_random_out_w = o_random_out_r;
    endcase
end




// ===== Sequential Circuits =====
always_ff @(posedge i_clk or negedge i_rst_n) begin
	// reset
	if (!i_rst_n) begin
		o_random_out_r   <= 4'd0;
        o_random_out_2_r <= 4'd0;
		state_r          <= S_IDLE;
        counter_r        <= 64'd0;
        LFSR_r           <= 4'd0;
        P_counter_r      <= 8'd0;
        D_counter_r      <= 8'd0;
        PERIOD_r         <= 8'd0;
        DNUM_r           <= 8'd0;
	end
	else begin
		o_random_out_r <= o_random_out_w;
        o_random_out_2_r <= o_random_out_2_w;
		state_r        <= state_w;
        counter_r      <= counter_w;
        LFSR_r         <= LFSR_w;
        P_counter_r    <= P_counter_w;
        D_counter_r    <= D_counter_w;
        PERIOD_r       <= PERIOD_w;
        DNUM_r         <= DNUM_w;


	end
end

endmodule

