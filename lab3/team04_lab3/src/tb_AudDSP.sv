`timescale 1ns/100ps


module tb;
	localparam CLK = 10;
	localparam HCLK = CLK/2;
    localparam H_AUD_CLK = 50*CLK/2;

    logic clk, rst_n; // i_AUD_BCLK
    logic i_start;
    logic i_pause;
    logic i_stop;
    logic [3:0] i_speed;
    logic i_fast_slow;
    logic i_slow_mode;
    logic AUD_lrc; // i_AUD_DACLRCK   // cycle: 50
    logic signed [15:0] i_sram_data;
	logic signed [15:0] o_dac_data;
    logic [19:0] o_sram_addr;


    // AudPlayer player0(
    //     .i_rst_n(rst_n), 
    //     .i_clk(clk),
    //     .i_lrc(AUD_lrc),
    //     .i_en(1'd1),
    //     .i_dac_data(data_play),
    //     .o_aud_dacdat(AUD_data)
    // );

    AudDSP AudDSP0(
    .i_rst_n(rst_n),
    .i_clk(clk),
    .i_start(i_start),
    .i_pause(i_pause),
    .i_stop(i_stop),
    .i_speed(i_speed),
    .i_fast_slow(i_fast_slow),
    .i_slow_mode(i_slow_mode),
    .i_daclrck(AUD_lrc),
    .i_sram_data(i_sram_data),
	.o_dac_data(o_dac_data),
    .o_sram_addr(o_sram_addr)
    );

    initial clk = 0;
	always #HCLK clk = ~clk;

    initial AUD_lrc = 0;
    always #H_AUD_CLK AUD_lrc = ~AUD_lrc;

    always begin
        @(posedge clk);
        i_sram_data = o_sram_addr[15:0] * 10;
    end

    initial begin
        $fsdbDumpfile("AudDSP.fsdb");
		$fsdbDumpvars;
        
        $display("DSP set input");
        i_start     <= 0;
        i_pause     <= 0;
        i_stop      <= 0;
        i_speed     <= 4;
        i_fast_slow <= 0;
        i_slow_mode <= 1;
        // reset AudPlayer
        
        $display("DSP reset");
        rst_n = 0;
        #(2*CLK)
        rst_n = 1;
        for (int j = 0; j < 10; j++) begin
            @(posedge clk);
        end

        $display("DSP start");
        // start
        i_start     <= 1;
        @(posedge clk);
        i_start     <= 0;

        $display("Loop start");
        for (int i = 0; i < 30; i++) begin
            $display("iteration: %d", i);
            @(negedge AUD_lrc);
            $display("DSP o_dac_data: %05d", o_dac_data);
        end
        
        // for (int i = 0; i < 1000; i++) begin // i is data to be sent
        //     @(negedge AUD_lrc); // update dayaplay when AUD_CLK fall
        //     data_play <= i;
        //     // @(posedge clk);     // wait a cycle
        // end

        $finish;
    end



    initial begin
		#(3000*CLK)
		$display("Too slow, abort.");
		$finish;
	end

endmodule



