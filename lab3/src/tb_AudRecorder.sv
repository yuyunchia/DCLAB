`timescale 1ns/100ps


module tb;
	localparam CLK = 10;
	localparam HCLK = CLK/2;
    localparam H_AUD_CLK = 50*CLK/2;

    logic clk, rst_n; // i_AUD_BCLK
    logic start, pause, stop;
    logic AUD_lrc; // i_AUD_ADCLRCK   // cycle: 50
    logic AUD_data; // i_AUD_ADCDAT
    logic [19:0] addr_record;
    logic [15:0] data_record;

    logic [15:0] send_data;

    AudRecorder recorder0(
        .i_rst_n(rst_n), 
        .i_clk(clk),
        .i_lrc(AUD_lrc),
        .i_start(start),
        .i_pause(pause),
        .i_stop(stop),
        .i_data(AUD_data),
        .o_address(addr_record),
        .o_data(data_record)
    );

    initial clk = 0;
	always #HCLK clk = ~clk;

    initial AUD_lrc = 0;
    always #H_AUD_CLK AUD_lrc = ~AUD_lrc;



    initial begin
        $fsdbDumpfile("AudRecorder.fsdb");
		$fsdbDumpvars;
        // may be read data here...


        // Init control signal
        start <= 0;
        pause <= 0;
        stop  <= 0;

        // reset AudRecorder
        rst_n = 0;
        #(2*CLK)
        rst_n = 1;

        for (int j = 0; j < 10; j++) begin
            @(posedge clk);
        end

        // // init sendata
        // send_data <= 0;


        // press start button
        start <= 1;
        @(posedge clk)
        start <= 0;

        // 
        for (int i = 0; i < 1000; i++) begin // i is data to be sent


            if (i == 20) pause <= 1; // press pause button
            else if (i == 40) pause <= 1; // press pause button again
            else if (i == 60) stop <= 1;  // press stop button
            else if (i == 80) start <= 1; // press stop button
            else  begin  //if (i == 21 || i == 41 || i == 61 || i == 81)begin
                start <= 0;
                pause <= 0;
                stop  <= 0;
            end

            @(posedge clk);
            start <= 0;
            pause <= 0;
            stop  <= 0;






            send_data <= i;
            AUD_data  <= 0;
            @(posedge AUD_lrc); // wait AUD_CLK rise
            @(posedge clk);     // wait a cycle
			for (int j = 15; j > -1; j--) begin
                AUD_data <= send_data[j];
				@(posedge clk);
			end

            @(negedge AUD_lrc)
            AUD_data <= 0;
        end

        $finish;
    end



    initial begin
		#(10000*CLK)
		$display("Too slow, abort.");
		$finish;
	end

endmodule



