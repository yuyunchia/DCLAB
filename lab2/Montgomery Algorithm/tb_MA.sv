`timescale 1ns/100ps
// `define CLCYE_TIME 10.0
// You can modify NUM_DATA and MAX_DELAY
// `define NUM_DATA 10
// `define MAX_DELAY 3

module MA_tb;

    localparam CLK = 10;
	localparam HCLK = CLK/2;

	logic clk, rst, MA_start, MA_end;
    logic [255:0] n, MA_a, MA_b, MA_o, golden;
	initial clk = 0;
	always #HCLK clk = ~clk;
	integer fp_MA_a, fp_MA_b, fp_n, fp_MA_o;
	


    MontAlg MontAlg0(
		.i_clk(clk),
		.i_rst(rst),
		.i_MA_start(MA_start),
		.i_n(n),
		.i_MA_a(MA_a),
		.i_MA_b(MA_b),
		.o_MA_o(MA_o),
		.o_MA_end(MA_end)
	);
    initial begin
		$fsdbDumpfile("MA.fsdb");
		$fsdbDumpvars;
		// $fsdbDumpvars(0, MA_test, "+all");
		fp_MA_a = $fopen("./golden/MA_a.txt", "r");
		fp_MA_b = $fopen("./golden/MA_b.txt", "r");
		fp_n    = $fopen("./golden/n.txt", "r");
		fp_MA_o = $fopen("./golden/MA_o.txt", "r");
		rst = 1;
		#(2*CLK)
		rst = 0;
		for (int i = 0; i < 3; i++) begin
            MA_start = 1'd1;
            // MA_a = 256'd97;
            // MA_b = 256'd57;
			// n    = 256'd1731;
			$fscanf(fp_MA_a, "%d\n", MA_a); 
			$fscanf(fp_MA_b, "%d\n", MA_b); 
			$fscanf(fp_n,    "%d\n", n); 
			$fscanf(fp_MA_o, "%d\n", golden); 
            for (int j = 0; j < 256; j++) begin
				@(posedge clk);
			end
			$display("=====================================");
			$display("MA_a = %4d", MA_a);
			$display("MA_b = %4d", MA_b);
			$display("n    = %4d", n);
			$display("================");
			MA_start <= 1;
			@(posedge clk)
			// encrypted_data <= 'x;
			MA_start <= 0;
			@(posedge MA_end)
			$display("================");
			$display("MA_o = %4d", MA_o);
			$display("gold = %4d", golden);
			$display("=====================================");
		end
		$finish;
	end

  
endmodule













// module inverse_tb;






// reg clk, reset, valid;
// wire finish;
// reg     [162:0] data_a;
// wire    [162:0] data_out_inv;
// initial clk = 1'b0;
// always #(`CLCYE_TIME*0.5) clk = ~clk;
// inverse u1(.clk_p_i(clk), .reset(reset), .data_a(data_a), .data_o(data_out_inv),.valid(valid),.finish(finish));
// initial begin
//     $fsdbDumpfile("inverse.fsdb");
//     $fsdbDumpvars(0, "+mda");
// end
// initial begin
//   #0 reset = 1'b0;
//   #`CLCYE_TIME reset = 1'b1;
//   #(`CLCYE_TIME*2) reset = 1'b0;
// end
// initial begin
//     data_a = 163'h58efc9fddedc2cccccdd230ff201392ffcfddda;
//     // data_a = 163'h3;
// end

// always @(*) begin
//     if (finish) begin
//         if (data_out_inv == 163'h3a58a5eaaa5e156cf85e0f50a84820a75cbd9a852) begin
//             $display("\tsuccess");
//         end
//         else begin
//             $display("\tGot answer: %21h", data_out_inv);
//         end
//     end
// end


// initial begin
//     #(`CLCYE_TIME*1200) $finish();
// end
// initial begin
//     #(`CLCYE_TIME*3) valid = 1'b1;
//     #(`CLCYE_TIME)   valid = 1'b0;
// end
// endmodule



