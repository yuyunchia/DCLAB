`timescale 1ns/100ps
// `define CLCYE_TIME 10.0
// You can modify NUM_DATA and MAX_DELAY
// `define NUM_DATA 10
// `define MAX_DELAY 3

module MP_tb;

    localparam CLK = 10;
	localparam HCLK = CLK/2;

	logic clk, rst, MP_start, MP_end;
    logic [255:0] n,  golden;
    logic [269:0] MP_a, MP_o;
	initial clk = 0;
	always #HCLK clk = ~clk;
	integer fp_MP_a, fp_n, fp_MP_o;
	



    ModProd mp0(
        .i_clk(clk),
        .i_rst(rst),
        .i_MP_start(MP_start),
        .i_n(n),
        .i_MP_a(MP_a),
        .o_MP_a(MP_o),
        .o_MP_end(MP_end)
    );
    initial begin
		$fsdbDumpfile("MP.fsdb");
		$fsdbDumpvars;
		// $fsdbDumpvars(0, MP_test, "+all");
		fp_MP_a = $fopen("./golden/MP_a.txt", "r");
		fp_n    = $fopen("./golden/MP_n.txt", "r");
		fp_MP_o = $fopen("./golden/MP_o.txt", "r");
		rst = 1;
		#(2*CLK)
		rst = 0;
		for (int i = 0; i < 4; i++) begin
            
            MP_start = 1'd1;
			$fscanf(fp_MP_a, "%d\n", MP_a); 
			$fscanf(fp_n,    "%d\n", n); 
			$fscanf(fp_MP_o, "%d\n", golden); 

			@(posedge clk);
			$display("=====================================");
			$display("MP_a = %4d", MP_a);
			$display("n    = %4d", n);
			$display("================");
			MP_start <= 1;
			@(posedge clk)
			MP_start <= 0;
			@(posedge MP_end)
			$display("================");
			$display("MP_o = %4d", MP_o);
			$display("gold = %4d", golden);
			$display("=====================================");

            for (int j = 0; j < 0; j++) begin
				@(posedge clk);
			end
		end
		$finish;
	end

  
endmodule







