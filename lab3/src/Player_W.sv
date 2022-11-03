module AudPlayer (
	input i_rst_n,
	input i_bclk,
	input i_daclrck, //left:1, right:0
	input i_en, // enable AudPlayer only when playing audio, work with AudDSP
	input [15:0] i_dac_data, //dac_data
	output o_aud_dacdat
);
localparam IDLE = 0;
localparam WAIT = 1;
localparam PROC = 2;
logic [1:0] state_w, state_r;
logic result_w, result_r, channel_w, channel_r;
logic [3:0] counter_w, counter_r;
assign o_aud_dacdat = result_r;
always_comb begin
	// design your control here
	state_w = state_r;
	result_w = result_r;
	channel_w = i_daclrck;
	counter_w = counter_r;
	case(state_r)
		IDLE: begin
			state_w = PROC;
		end
		WAIT: begin
			if (channel_r != i_daclrck) begin
				state_w = PROC;
				result_w = i_dac_data[counter_r];
			end
			else begin
				state_w = WAIT;
			end
		end
		PROC: begin
			if (counter_r == 4'd0) begin
				state_w = WAIT;
				counter_w = 4'd15;
			end
			else begin
				state_w = PROC;
				counter_w = counter_r - 4'd1;
			end
			result_w = i_dac_data[counter_r];
		end
	endcase // state_r
end

always_ff @(posedge i_bclk or negedge i_rst_n) begin
	//reset
	if (!i_rst_n) begin
		state_r <= IDLE;
		channel_r <= i_daclrck;
		counter_r <= 4'd15;
	end
	else begin
		state_r <= state_w;
		result_r <= result_w;
		channel_r <= channel_w;
		counter_r <= counter_w;
	end
end
endmodule