module Top (
	input i_rst_n,
	input i_clk,
	input i_key_0, // start
	input i_key_1, // stop
	input i_key_2, // pause
	input [3:0] i_speed, // design how user can decide mode on your own

	// input i_fast_slow,
	// input i_slow_mode, // constant interpolation
	input i_sw_17,  //0:record 1:play
	input i_sw_4, //fast
	input i_sw_5, //slow 0
	input i_sw_6, //slow 1
	
	// AudDSP and SRAM
	output [19:0] o_SRAM_ADDR,
	inout  [15:0] io_SRAM_DQ,
	output        o_SRAM_WE_N,
	output        o_SRAM_CE_N,
	output        o_SRAM_OE_N,
	output        o_SRAM_LB_N,
	output        o_SRAM_UB_N,
	
	// I2C
	input  i_clk_100k,
	output o_I2C_SCLK,
	inout  io_I2C_SDAT,
	
	// AudPlayer
	input  i_AUD_ADCDAT,
	inout  i_AUD_ADCLRCK,
	inout  i_AUD_BCLK,
	inout  i_AUD_DACLRCK,
	output o_AUD_DACDAT,

	// SEVENDECODER (optional display)
	// output [5:0] o_record_time,
	output [1:0] o_play_time

	// LCD (optional display)
	// input        i_clk_800k,
	// inout  [7:0] o_LCD_DATA,
	// output       o_LCD_EN,
	// output       o_LCD_RS,
	// output       o_LCD_RW,
	// output       o_LCD_ON,
	// output       o_LCD_BLON,

	// LED
	// output  [8:0] o_ledg,
	// output [17:0] o_ledr
);

// design the FSM and states as you like
localparam S_IDLE       = 0;
localparam S_I2C        = 1;
localparam S_RECD       = 2;
// parameter S_RECD_PAUSE = 3;
localparam S_PLAY       = 3;
// parameter S_PLAY_PAUSE = 5;

logic i2c_oen, i2c_sdat, i2c_finished;
logic [19:0] addr_record, addr_play;
logic [15:0] data_record, data_play, dac_data;

//////// self add wire & register
logic [3:0] state_w, state_r;
logic i2c_start_w, i2c_start_r;

logic recorder_start_w, recorder_start_r;
logic recorder_pause_w, recorder_pause_r;
logic recorder_stop_w, recorder_stop_r;
logic recorder_rst_w, recorder_rst_r;

logic player_start_w, player_start_r;
logic player_pause_w, player_pause_r;
logic player_stop_w, player_stop_r;
logic player_rst_w, player_rst_r;

logic switch_w, switch_r; // switch for RECD:0/PLAY:1


logic player_en; 

/////////////////////////////////////

assign switch_w = i_sw_17;

assign o_play_time[1:0] = state_r;

assign io_I2C_SDAT = (i2c_oen) ? i2c_sdat : 1'bz;

assign o_SRAM_ADDR = (state_r == S_RECD) ? addr_record : addr_play[19:0];
assign io_SRAM_DQ  = (state_r == S_RECD) ? data_record : 16'dz; // sram_dq as output
assign data_play   = (state_r != S_RECD) ? io_SRAM_DQ : 16'd0; // sram_dq as input

assign o_SRAM_WE_N = (state_r == S_RECD) ? 1'b0 : 1'b1;
assign o_SRAM_CE_N = 1'b0;
assign o_SRAM_OE_N = 1'b0;
assign o_SRAM_LB_N = 1'b0;
assign o_SRAM_UB_N = 1'b0;

assign player_en  = state_r == S_PLAY;

// below is a simple example for module division
// you can design these as you like

// === I2cInitializer ===
// sequentially sent out settings to initialize WM8731 with I2C protocal
I2cInitializer init0(
	.i_rst_n(i_rst_n),
	.i_clk(i_clk_100k),
	.i_start(i2c_start_r),
	.o_finished(i2c_finished),
	.o_sclk(o_I2C_SCLK),
	.o_sdat(i2c_sdat),
	.o_oen(i2c_oen) // you are outputing (you are not outputing only when you are "ack"ing.)
);

// === AudDSP ===
// responsible for DSP operations including fast play and slow play at different speed
// in other words, determine which data addr to be fetch for player 
AudDSP dsp0(
	.i_rst_n(player_rst_r),
	.i_clk(i_clk),
	.i_start(player_start_r),
	.i_pause(player_pause_r),
	.i_stop(player_stop_r),
	.i_speed(i_speed),
	.i_fast_slow(i_sw_4),
	.i_slow_mode(i_sw_5), // constant interpolation
	.i_daclrck(i_AUD_DACLRCK),
	.i_sram_data(data_play),
	.o_dac_data(dac_data),
	.o_sram_addr(addr_play)
);



// === AudPlayer ===
// receive data address from DSP and fetch data to sent to WM8731 with I2S protocal
AudPlayer player0(
	.i_rst_n(player_rst_r),
	.i_clk(i_AUD_BCLK),
	.i_lrc(i_AUD_DACLRCK),
	.i_en(1), // enable AudPlayer only when playing audio, work with AudDSP
	.i_dac_data(dac_data), //dac_data
	.o_aud_dacdat(o_AUD_DACDAT)
);

// === AudRecorder ===
// receive data from WM8731 with I2S protocal and save to SRAM
AudRecorder recorder0(
	.i_rst_n(recorder_rst_r), 
	.i_clk(i_AUD_BCLK),
	.i_lrc(i_AUD_ADCLRCK),
	.i_start(recorder_start_r),
	.i_pause(recorder_pause_r),
	.i_stop(recorder_stop_r),
	.i_data(i_AUD_ADCDAT),
	.o_address(addr_record),
	.o_data(data_record)
);

//////////////////////////////////// Combinational logic //////////////////////////

always_comb begin // state
	state_w = state_r;
    case(state_r)
    S_IDLE: state_w = S_I2C;
    S_I2C: begin
        if(i2c_finished == 1'd1) begin
			if(switch_r) state_w = S_PLAY;
			else state_w = S_RECD;
		end
    end
    S_RECD: begin
		if(switch_r) state_w = S_PLAY;
		else state_w = S_RECD;
	end
	S_PLAY: begin
		if(switch_r) state_w = S_PLAY;
		else state_w = S_RECD;
	end
    default: state_w = state_r;
    endcase
end


always_comb begin // i2c_start
	case(state_r)
	S_IDLE: i2c_start_w = 1'd1;
	S_I2C: i2c_start_w = 1'd0;
	default: i2c_start_w = 1'd0;
	endcase
end

always_comb begin // control for RECD (switch_r == 0)
	recorder_start_w = 1'b0;
	recorder_pause_w = 1'b0;
	recorder_stop_w  = 1'b0;
	recorder_rst_w   = recorder_rst_r;
	case(state_r)
	S_IDLE: recorder_rst_w = 1'b0;
	S_RECD: begin
		if(recorder_rst_r) recorder_rst_w = 1'd0;
		else if(i_key_0) recorder_start_w = 1'd1;
		else if(i_key_1) recorder_stop_w = 1'd1;
		else if(i_key_2) recorder_pause_w = 1'd1;
	end
	S_PLAY: if(!switch_r) recorder_rst_w = 1'd1; 
	endcase
end


always_comb begin // control for PLAY (switch_r == 1)
	player_start_w = 1'b0;
	player_pause_w = 1'b0;
	player_stop_w  = 1'b0;
	player_rst_w   = player_rst_r;
	case(state_r)
	S_IDLE: player_rst_w = 1'b0;
	S_PLAY: begin
		if(player_rst_r) player_rst_w = 1'd0;
		else if(i_key_0)  player_start_w = 1'd1;
		else if(i_key_1)  player_stop_w = 1'd1;
		else if(i_key_2)  player_pause_w = 1'd1;
	end
	S_RECD: if(switch_r) player_rst_w = 1'd1; 
	endcase
end







//////////////////////////////////// Sequential logic //////////////////////////

always_ff @(posedge i_clk or negedge i_rst_n) begin
	if (!i_rst_n) begin
		state_r          <= S_IDLE;
		i2c_start_r      <= 0;
		recorder_start_r <= 0;
		recorder_pause_r <= 0;
		recorder_stop_r  <= 0;
		recorder_rst_r   <= 1;

		player_start_r   <= 0;
		player_pause_r   <= 0;
		player_stop_r    <= 0;
		player_rst_r     <= 1;
		switch_r         <= 0;
		
	end
	else begin
		state_r          <= state_w;
		i2c_start_r      <= i2c_start_w;
		recorder_start_r <= recorder_start_w;
		recorder_pause_r <= recorder_pause_w;
		recorder_stop_r  <= recorder_stop_w;
		recorder_rst_r   <= recorder_rst_w;

		player_start_r   <= player_start_w;
		player_pause_r   <= player_pause_w;
		player_stop_r    <= player_stop_w;
		player_rst_r     <= player_rst_w;
		switch_r         <= switch_w;
	end
end

endmodule
