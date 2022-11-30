`timescale 1us/1us

module tb_I2C;
	localparam CLK = 10;
	localparam HCLK = CLK/2;
    localparam HHHCLK = HCLK + CLK;

	logic rst, clk, start_cal, fin, sclk, sdat, oen;
	initial clk = 0;
	always #HCLK clk = ~clk;


	I2cInitializer i2c(
        .i_rst_n(rst),
		.i_clk(clk),
		.i_start(start_cal),
		.o_finished(fin),
        .o_sclk(sclk),
        .o_sdat(sdat),
        .o_oen(oen)
	);

	initial begin
		$fsdbDumpfile("i2c.fsdb");
		$fsdbDumpvars;
        // reset & start_call
		rst = 1'b0;
        start_cal = 1'b0;
		#(2*CLK)
		rst = 1'b1;
        start_cal = 1'b1;
        #(CLK)
        start_cal = 1'b0;

		for (int i = 0; i < 5000; i++) begin
				@(posedge clk);
			end
        $finish;
    end
	initial begin
		#(50000*CLK)
		$display(".A.B.O.R.T.");
		$finish;
	end

endmodule
