`timescale 1ns/100ps


module tb;
	localparam CLK = 10;
	localparam HCLK = CLK/2;
    localparam H_AUD_CLK = 50*CLK/2;

    logic clk, rst_n; // i_AUD_BCLK
    logic AUD_lrc; // i_AUD_DACLRCK   // cycle: 50
    logic AUD_data; // o_AUD_DACDAT
    logic [15:0] data_play;

    AudPlayer player0(
        .i_rst_n(rst_n), 
        .i_bclk(clk),
        .i_daclrck(AUD_lrc),
        .i_en(1'd1),
        .i_dac_data(data_play),
        .o_aud_dacdat(AUD_data)
    );

    initial clk = 0;
	always #HCLK clk = ~clk;

    initial AUD_lrc = 0;
    always #H_AUD_CLK AUD_lrc = ~AUD_lrc;



    initial begin
        $fsdbDumpfile("AudPlayer.fsdb");
		$fsdbDumpvars;


        data_play <= 0;

        
        // reset AudPlayer
        rst_n = 0;
        #(2*CLK)
        rst_n = 1;

        for (int j = 0; j < 10; j++) begin
            @(posedge clk);
        end

        // // init sendata
        // send_data <= 0;

        
        for (int i = 0; i < 1000; i++) begin // i is data to be sent

            
            @(negedge AUD_lrc); // update dayaplay when AUD_CLK fall
            data_play <= i;
            // @(posedge clk);     // wait a cycle
        end

        $finish;
    end



    initial begin
		#(3000*CLK)
		$display("Too slow, abort.");
		$finish;
	end

endmodule



