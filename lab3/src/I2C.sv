module I2cInitializer(
    input i_rst_n,
    input i_clk,
    input i_start,
    output o_finished,
    output o_sclk,
    output o_sdat,
    output o_oen
);

// ===== Parameters definition ===== 
localparam S_IDLE = 4'd0;
localparam S_STRT = 4'd1;
localparam S_TRAN = 4'd2;
localparam S_SAMP = 4'd3;
localparam S_ENBL = 4'd4;
localparam S_STOP = 4'd5;

localparam [4:0] data_pt = 5'd24; // instruction: 24 bit
logic [3:0] state_r, state_w;
logic [2:0] insc_counter_r, insc_counter_w;
logic [4:0] data_counter_r, data_counter_w;
logic o_finished_r, o_finished_w;
logic o_sclk_r, o_sclk_w;
logic o_sdat_r, o_sdat_w;
logic o_oen_r, o_oen_w;

localparam [23:0]data[6:0] = 
{
    24'b1000_0000_0_1001_000_0010_1100,
    24'b1001_1000_0_0001_000_0010_1100,
    24'b0100_0010_0_1110_000_0010_1100,
    24'b0000_0000_0_0110_000_0010_1100,
    24'b0000_0000_0_1010_000_0010_1100,
    24'b1010_1000_0_0010_000_0010_1100,
    24'b0000_0000_0_1111_000_0010_1100
};
// ===== testing parameters =====
logic [15:0] counter_test_r, counter_test_w;

// ===== Output buffers =====
assign o_finished = o_finished_r;
assign o_sclk = o_sclk_r;
assign o_sdat = o_sdat_r;
assign o_oen = o_oen_r;

// ===== Testing Combinational Blocks =====
always_comb begin //counter_test
    case(state_r)
        S_IDLE: begin
            counter_test_w = 16'd0;
        end
        default: counter_test_w = counter_test_r +1;
    endcase
end

always_ff @( posedge i_clk or negedge i_rst_n) begin 
    if(!i_rst_n) counter_test_r <= 16'd0;
    else counter_test_r <= counter_test_w;  
end

// ===== Combinational blocks =====
always_comb begin //state
    if(i_start) state_w = S_IDLE;
    else begin
    case(state_r)
        S_IDLE: begin
            state_w = S_STRT;
        end

        S_STRT: begin
            state_w = S_TRAN;
        end

        S_TRAN: begin
            state_w = S_SAMP;
        end

        S_SAMP: begin
            state_w = (data_counter_r == 5'd7 || (data_counter_r == 5'd15 || data_counter_r == 5'd23)) ? S_ENBL : S_TRAN;
        end

        S_ENBL: begin
            state_w = (data_counter_r >= 5'd23) ? S_STOP : S_TRAN;
        end

        S_STOP: begin
            if(o_sclk_r == 1'b1 && o_sdat_r == 1'b1) begin
                state_w = (insc_counter_r == 3'd7) ? state_r : S_STRT;
            end
            else state_w = state_r;
        end
        default: state_w = state_r;
    endcase
    end
end

always_comb begin // data_counter
    case(state_r)
        S_STRT: begin
            data_counter_w = 5'd0;
        end

        S_SAMP: begin
            data_counter_w = data_counter_r + 1;
        end

        default: data_counter_w = data_counter_r;
    endcase
end

always_comb begin // insc_counter
    case(state_r)
        S_IDLE: begin
            insc_counter_w = 3'd0;
        end

        S_STOP: begin
            insc_counter_w = (o_sclk_r == 1'b1 && o_sdat_r == 1'b1) ? insc_counter_r +1 : insc_counter_r;
        end
        default: insc_counter_w = insc_counter_r;
    endcase
end

always_comb begin //o_sdat, o_sclk
    case(state_r)
        S_IDLE: begin
            o_sdat_w = 1'b1;
            o_sclk_w = 1'b1;
        end

        S_STRT: begin
            o_sdat_w = 1'b0;
            o_sclk_w = (o_sdat_r == 1'b0) ? 1'b0 : o_sclk_r;
        end

        S_TRAN: begin
            o_sclk_w = 1'b1;
            o_sdat_w = data[insc_counter_r][data_counter_r];
        end

        S_SAMP: begin
            o_sclk_w = 1'b0;
            o_sdat_w = o_sdat_r;
        end

        S_ENBL: begin
            o_sdat_w = 1'bz;
            o_sclk_w = o_sclk_r;
        end

        S_STOP: begin
            o_sclk_w = 1'b1;
            o_sdat_w = (o_sclk_r == 1'b1) ? 1'b1 : 1'b0;
        end

        default: begin 
            o_sdat_w = o_sdat_r;
            o_sclk_w = o_sclk_r;
        end
    endcase
end

always_comb begin //o_oen
    case(state_r)
        S_IDLE: begin
            o_oen_w = 1'b1;
        end

        S_ENBL: begin
            o_oen_w = 1'b0;
        end
        default: o_oen_w = 1'b1;
    endcase
end

always_comb begin //o_finished
    case(state_r)
        S_IDLE: begin
            o_finished_w = 1'b0;
        end

        S_STOP: begin
            o_finished_w = (insc_counter_r == 3'd7) ? 1'b1 : 1'b0;
        end
        default: o_finished_w = o_finished_r;
    endcase
end


// ===== Sequential blocks =====
always_ff @( posedge i_clk or negedge i_rst_n ) begin 
    if(!i_rst_n) begin
        state_r         <= S_IDLE;
        data_counter_r  <= 5'd0;
        insc_counter_r  <= 3'd0;
        o_sclk_r        <= 1'b1;
        o_sdat_r        <= 1'b1;
        o_oen_r         <= 1'b1;
        o_finished_r    <= 1'b0;
    end
    else begin
        state_r         <= state_w;
        data_counter_r  <= data_counter_w;
        insc_counter_r  <= insc_counter_w;
        o_sclk_r        <= o_sclk_w;
        o_sdat_r        <= o_sdat_w;
        o_oen_r         <= o_oen_w;
        o_finished_r    <= o_finished_w;
    end
end
endmodule
