module AudPlayer(
    input         i_rst_n, 
    input         i_clk,   // i_AUD_BCLK
    input         i_lrc,   // i_AUD_ADCLRCK
    input         i_en,
    input  [15:0] i_dac_data,  // i_AUD_ADCDAT
    output        o_aud_dacdat     // data_record
);

// design the FSM and states as you like
localparam S_IDLE      = 0;
localparam S_PLAY      = 1;
localparam S_PAUSE     = 2;




// ===== Registers & Wires =====
logic        lrc_r, lrc_w;
logic [3:0]  state_r, state_w;
logic [7:0]  counter_r, counter_w;
// logic [15:0] data_r, data_w;


logic o_aud_dacdat_r, o_aud_dacdat_w; 




// ===== Combinational Circuits =====
assign lrc_w = i_lrc;
assign o_aud_dacdat = o_aud_dacdat_r;

always_comb begin // state
    case(state_r)
    S_IDLE:  state_w = (i_en) ? S_PLAY : S_PAUSE;
    S_PLAY:  state_w = (i_en) ? S_PLAY : S_PAUSE;
    S_PAUSE: state_w = (i_en) ? S_PLAY : S_PAUSE;
    endcase
end

always_comb begin // counter
    case(state_r)
    S_PLAY: begin
        if ( lrc_r != i_lrc) counter_w = 8'd16;
        else if (counter_r == 8'd0) counter_w = 8'd0;
        else counter_w = counter_r - 8'd1;
    end
    default: counter_w = 8'd16;
    endcase
end


always_comb begin // o_aud_dacdat 
    case(state_r)   
    S_PLAY:  o_aud_dacdat_w = (counter_r > 8'd0) ? i_dac_data[counter_r - 8'd1] : o_aud_dacdat_r;
    default: o_aud_dacdat_w = o_aud_dacdat_r;
    endcase
end








// ===== Sequential Circuits =====
always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
        lrc_r     <= 1'd0;
        state_r   <= S_IDLE;
        counter_r <= 8'd16; 
        o_aud_dacdat_r <= 1'd0; 
	end
	else begin
        lrc_r     <= lrc_w;
        state_r   <= state_w;
        counter_r <= counter_w;
        o_aud_dacdat_r <= o_aud_dacdat_w;
	end
end



// // ===== Sequential Circuits =====
// always_ff @(posedge i_clk or posedge i_rst_n) begin
// 	if (i_rst_n) begin
//         lrc_r     <= 1'd0;
//         state_r   <= S_IDLE;
//         counter_r <= 8'd16; 
//         o_aud_dacdat_r <= 1'd0; 
// 	end
// 	else begin
//         lrc_r     <= lrc_w;
//         state_r   <= state_w;
//         counter_r <= counter_w;
//         o_aud_dacdat_r <= o_aud_dacdat_w;
// 	end
// end



endmodule

