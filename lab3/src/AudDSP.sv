module AudDSP(
    input i_rst_n,
    input i_clk,
    input i_start,
    input i_pause,
    input i_stop,
    input [3:0] i_speed,
    input i_fast_slow,
    input i_slow_mode,
    input i_daclrck,
    input [15:0] i_sram_data,
	output [15:0] o_dac_data,
    output [19:0] o_sram_addr
);

parameter S_IDLE = 0;
parameter S_FAST = 1;
parameter S_SLOW_INIT = 2;
parameter S_SLOW_0 = 3;
parameter S_SLOW_1 = 4;
parameter S_PAUSE = 5;

logic [2:0] state_r, state_w;
logic [4:0] speed_r, speed_w;
logic [4:0] frag_count_r, frag_count_w;
logic daclrck_delay_r, daclrck_delay_w;
logic signed [17:0] last_data_r, last_data_w;
logic signed [17:0] cur_data_r, cur_data_w;
logic signed [17:0] mid_data_r, mid_data_w;
logic signed [17:0] frag_r, frag_w;
logic [19:0] sram_addr_r, sram_addr_w;



always_comb begin
    state_w = state_r;
    speed_w = speed_r;
    frag_count_w = frag_count_r;
    daclrck_delay_w = daclrck_delay_r;
    last_data_w = $signed(last_data_r);
    cur_data_w = $signed(i_sram_data);
    mid_data_w = $signed(mid_data_r);
    frag_w = frag_r;
    sram_addr_w = sram_addr_r;

    if (i_pause) begin
        state_w = S_PAUSE;
    end
    else if (i_stop) begin
        state_w = S_IDLE;
    end
    else begin
        case(state_r)
            S_IDLE: begin
                if (i_start) begin
                    if (i_fast_slow) begin // fast
                        state_w = S_FAST;
                    end
                    else begin
                        state_w = S_SLOW_INIT;
                    end
                end
            end
            
            S_FAST: begin
                if (~i_fast_slow) begin // slow
                    state_w = S_SLOW_INIT;
                end
                else begin
                    speed_w = i_speed + 1;
                    o_dac_data = $signed(last_data_r);
                    if (~i_daclrck & daclrck_delay_r) begin // i_daclrck negedge
                        last_data_w = $signed(cur_data_r);
                        sram_addr_w = sram_addr_r + speed_r;
                    end
                end
            end
            
            S_SLOW_INIT: begin
                if (i_fast_slow) begin // fast
                    state_w = S_FAST;
                end
                else begin // slow
                    else if (i_slow_mode) begin // slow_1 mode
                        state_w = S_SLOW_1;
                        frag_w = ($signed(cur_data_r) + $signed(last_data_r)) / speed_r;
                        mid_data_w = $signed(last_data_r);
                        frag_count_w = 1;
                        sram_addr_w = sram_addr_r + 1;
                    end
                    else begin // slow_0 mode
                        state_w = S_SLOW_0;
                        mid_data_w = $signed(last_data_r);
                        frag_count_w = 1;
                        sram_addr_w = sram_addr_r + 1;
                    end
                end
            end
            
            S_SLOW_0: begin
                if (frag_count_r == speed_r) begin
                    state_w = S_SLOW_INIT;
                end
                else begin
                    dac_data = $signed(mid_data_r);
                    if (~i_daclrck & daclrck_delay_r) begin // i_daclrck negedge
                        frag_count_w = frag_count_r + 1;
                    end
                end
            end
            
            S_SLOW_1: begin
                if (frag_count_r == speed_r) begin
                    state_w = S_SLOW_INIT;
                end
                else begin
                    dac_data = $signed(mid_data_r);
                    if (~i_daclrck & daclrck_delay_r) begin // i_daclrck negedge
                        frag_count_w = frag_count_r + 1;
                        mid_data_w = $signed(mid_data_w) + $signed(frag_r)
                    end
                end
            end
            
            S_PAUSE: begin
                if (i_start) begin
                    if (i_fast_slow) begin // fast
                        state_w = S_FAST;
                    end
                    else begin
                        state_w = S_SLOW_INIT;
                    end
                end
            end

            default: begin
            end
        endcase
    end
end

always_ff @(posedge i_clk or posedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r = S_IDLE;
        speed_r = 1;
        frag_count_r = 0;
        daclrck_delay_r = 0;
        last_data_r = 0;
        cur_data_r = 0;
        mid_data_r = 0;
        frag_w = 0;
        sram_addr_w = 0;
	end
	else begin
		state_r = state_w;
        speed_r = speed_w;
        frag_count_r = frag_count_w;
        daclrck_delay_r = daclrck_delay_w;
        last_data_r = $signed(last_data_w);
        cur_data_r =  $signed(cur_data_w);
        mid_data_r =  $signed(mid_data_w);
        frag_r = frag_w;
        sram_addr_r = sram_addr_w;
	end
end