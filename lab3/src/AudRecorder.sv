module AudRecorder (
    input i_rst_n, 
    input i_clk,   // i_AUD_BCLK
    input i_lrc,   // i_AUD_ADCLRCK
    input i_start,
    input i_pause, 
    input i_stop,
    input i_data,  // i_AUD_ADCDAT
    output [19:0] o_address,  // addr_record
    output [15:0] o_data      // data_record
);

// design the FSM and states as you like
localparam S_IDLE       = 0;
localparam S_WRITE      = 1;
localparam S_PAUSE      = 2;


// ===== Registers & Wires =====
logic        pause_r, pause_w;
logic        lrc_r, lrc_w;
logic [3:0]  state_r, state_w;
logic [7:0]  counter_r, counter_w;
logic [19:0] address_r, address_w;
logic [15:0] data_r, data_w;

// ===== Output Assignments =====
assign o_data    = data_r;
assign o_address = address_r;
assign pause_w   = i_pause;
assign lrc_w     = i_lrc;


// ===== Combinational Circuits =====

always_comb begin // state
    case(state_r)
    S_IDLE: begin
        if(i_start) state_w = S_WRITE;
        else state_w = state_r;
    end
    S_WRITE: begin
        // if(i_start)           state_w = S_WRITE;
        if (i_stop) state_w = S_IDLE;
        else if (pause_r == 1'd0 && pause_w == 1'd1) state_w = S_PAUSE;
        else if (address_r == 20'd1048575) state_w = S_IDLE; // SRAM full !
        else state_w = state_r;
    end
    S_PAUSE: begin
        // if(i_start)           state_w = S_WRITE;
        if (i_stop) state_w = S_IDLE;
        else if (pause_r == 1'd0 && pause_w == 1'd1) state_w = S_WRITE;
        else state_w = state_r;
    end
    default: state_w = state_r;
    endcase
end

always_comb begin // address [19:0]  
    case(state_r)
    S_IDLE:  address_w = 20'd0;
    S_WRITE: begin
        if (lrc_r == 1'd0 && lrc_w == 1'd1) address_w = address_r + 20'd1;
        else address_w = address_r;
    end
    default: address_w = address_r;
    endcase
end

always_comb begin // counter [7:0]
    case(state_r)
    S_IDLE: counter_w = 8'd0;
    S_WRITE: begin
        if (lrc_r == 1'd0 && lrc_w == 1'd1) counter_w = 8'd16;
        else if (counter_r == 8'd0) counter_w = 8'd0;
        else counter_w = counter_r - 8'd1;
    end
    default: counter_w = 8'd0;
    endcase
end

always_comb begin // data [15:0]
    data_w = data_r; // important don't forget
    case(state_r)
    S_IDLE: data_w = 16'd0;
    S_WRITE: begin
        if(counter_r > 8'd0) data_w[counter_r - 8'd1] = i_data;
        else data_w = data_r;
    end
    default: data_w = 16'd0;
    endcase
end



// // ===== Sequential Circuits =====
// always_ff @(posedge i_clk or negedge i_rst_n) begin
// 	if (!i_rst_n) begin
//         pause_r   <= 1'd0;
//         lrc_r     <= 1'd0;
//         state_r   <= S_IDLE;
//         counter_r <= 8'd0;
//         address_r <= 20'd0;
//         data_r    <= 16'd0;
// 	end
// 	else begin
//         pause_r   <= pause_w;
// 		lrc_r     <= lrc_w;
//         state_r   <= state_w;
//         counter_r <= counter_w;
//         address_r <= address_w;
//         data_r    <= data_w;
// 	end
// end


always_ff @(posedge i_clk or posedge i_rst_n) begin
	if (i_rst_n) begin
        pause_r   <= 1'd0;
        lrc_r     <= 1'd0;
        state_r   <= S_IDLE;
        counter_r <= 8'd0;
        address_r <= 20'd0;
        data_r    <= 16'd0;
	end
	else begin
        pause_r   <= pause_w;
		lrc_r     <= lrc_w;
        state_r   <= state_w;
        counter_r <= counter_w;
        address_r <= address_w;
        data_r    <= data_w;
	end
end



endmodule










