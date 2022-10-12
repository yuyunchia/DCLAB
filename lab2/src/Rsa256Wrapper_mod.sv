module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest,
	 output [3:0]	state_o
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

// Feel free to design your own FSM!
localparam S_WAIT_KEY = 0;
localparam S_READ_KEY = 1;
localparam S_WAIT_DATA = 2;
localparam S_READ_DATA = 3;
localparam S_WAIT_CALCULATE = 4;
localparam S_WAIT_SEND = 5;
localparam S_SEND_DATA = 6;
//localparam S_KEY_BUFF = 7;
//localparam S_DATA_BUFF = 8;

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
logic [3:0] state_r, state_w;
logic [7:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;
logic NorD_r, NorD_w;
logic core_finished_r, core_finished_w;
logic [27:0] rst_counter_r, rst_counter_w;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8];
//assign avm_writedata = dec_r[255-:8];
assign state_o = state_r;

Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),
    .i_d(d_r),
    .i_n(n_r),
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
);

task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask

task StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask

task DoNothing;
    begin
        avm_read_w = avm_read_r;
        avm_write_w = avm_write_r;
        avm_address_w = avm_address_r;
    end
endtask

///////////////////////////////////////////////////////////////////////
always_comb begin  // state_w
    case(state_r)

        S_WAIT_KEY: begin
            if(!avm_waitrequest && avm_readdata[RX_OK_BIT]) begin
                state_w = S_READ_KEY;
            end
        end

        S_READ_KEY: begin
            if(!avm_waitrequest) begin
                if(!NorD_r) begin
                    state_w = S_WAIT_KEY;
                end
            end
            else begin 
                if(bytes_counter_r == 7) begin
                    state_w = S_WAIT_DATA;
                end
                else begin
                    state_w = S_WAIT_KEY;
                end
            end
        end

        S_WAIT_DATA: begin
            if(!avm_waitrequest && avm_readdata[RX_OK_BIT]) begin
                state_w = S_READ_DATA;
            end
            if(rst_counter_r == 28'hFFFFFFF) begin
                state_w <= S_WAIT_KEY;
            end
        end

        S_READ_DATA: begin
            if(!avm_waitrequest) begin
                if(bytes_counter_r == 7) begin
                    state_w = S_WAIT_CALCULATE;
                end
            end
            else begin
                state_w = S_WAIT_DATA;
            end
        end

        S_WAIT_CALCULATE: begin
            if (!avm_waitrequest && core_finished_r == 1) begin
                state_w = S_WAIT_SEND;
            end
        end

        S_WAIT_SEND: begin
            if(!avm_waitrequest && avm_readdata[TX_OK_BIT]) begin
                state_w = S_SEND_DATA;
            end
        end

        S_SEND_DATA: begin
            if(!avm_waitrequest) begin
                if(bytes_counter_r == 15) begin
                    state_w = S_WAIT_DATA;
                end
                else begin
                    state_w = S_WAIT_SEND;
                end
            end
        end

        default: state_w = state_r;
    endcase
end

always_comb begin  // StartRead, StartWrite
    case(state_r)

        S_WAIT_KEY: begin
            StartRead(STATUS_BASE);
            if(!avm_waitrequest && avm_readdata[RX_OK_BIT]) begin
                StartRead(RX_BASE);
            end
        end

        S_READ_KEY: begin
            if(!avm_waitrequest) begin
                if(!NorD_r) begin
                    StartRead(STATUS_BASE);
                end
                else begin
                    if(bytes_counter_r == 7) begin
                        StartRead(STATUS_BASE);
                    end
                    else begin
                        StartRead(STATUS_BASE);
                    end
                end
            end
        end

        S_WAIT_DATA: begin
            StartRead(STATUS_BASE);
            if(!avm_waitrequest && avm_readdata[RX_OK_BIT]) begin
                StartRead(RX_BASE);
            end
            if(rst_counter_r == 28'hFFFFFFF) begin 
                avm_address_w <= STATUS_BASE;
                avm_read_w <= 1;
                avm_write_w <= 0;
            end
        end

        S_READ_DATA: begin
            if(!avm_waitrequest) begin
                enc_w[bytes_counter_r-:8] = avm_readdata[7:0];
                if(bytes_counter_r == 7) begin
                    avm_address_w = avm_address_r;
        			avm_write_w = avm_write_r;
                    avm_read_w = 0;
                end
                else begin
                    StartRead(STATUS_BASE);
                end
            end
        end

        S_WAIT_CALCULATE: begin
            if (rsa_finished) begin
                StartRead(STATUS_BASE);
            end
            if (!avm_waitrequest && core_finished_r == 1) begin
                    StartRead(STATUS_BASE);
            end
        end

        S_WAIT_SEND: begin
            StartRead(STATUS_BASE);
            if(!avm_waitrequest && avm_readdata[TX_OK_BIT]) begin
                StartWrite(TX_BASE);
            end
        end

        S_SEND_DATA: begin
            if(!avm_waitrequest) begin
                avm_write_w = 0;
                if(bytes_counter_r == 15) begin
                    StartRead(STATUS_BASE);
                end
                else begin
                    StartRead(STATUS_BASE);
                end
            end
        end

        default: DoNothing()
    endcase
end

always_comb begin  // n_w
    case(state_r)

        S_READ_KEY: begin
            if(!avm_waitrequest) begin
				if(!NorD_r) begin
                    n_w[bytes_counter_r-:8] = avm_readdata[7:0];
                end
            end
        end

        S_WAIT_DATA: begin
            if(rst_counter_r == 28'hFFFFFFF) begin 
                n_w <= 0;
            end
        end

        default: n_w = n_r;
    endcase
end

always_comb begin  // NorD_w
    case(state_r)

        S_READ_KEY: begin   // TODO: Need else???
            if(!avm_waitrequest) begin
                if(!NorD_r) begin
                    if(bytes_counter_r == 7) begin
                        NorD_w = 1'b1;
                    end
                end
            end
        end

        S_WAIT_DATA: begin
            if(rst_counter_r == 28'hFFFFFFF) begin 
                NorD_w <= 0;
            end
        end

        default: NorD_w = NorD_r;
        
    endcase
end

always_comb begin  // d_w
    case(state_r)

        S_READ_KEY: begin
			if(!avm_waitrequest) begin
                if(!NorD_r) begin
                    d_w = d_r; // TODO: ?????
                end
                else begin
                    d_w[bytes_counter_r-:8] = avm_readdata[7:0];
                end
            end
        end

        S_WAIT_DATA: begin
            if(rst_counter_r == 28'hFFFFFFF) begin 
                d_w <= 0;
            end
        end

        default: d_w = d_r;
    endcase
end

always_comb begin // rst_counter_w
    case(state_r)

        S_READ_KEY: begin
            if(!avm_waitrequest) begin
                if(!NorD_r) begin
                    rst_counter_w = rst_counter_r; // TODO: ?????
                end
                else begin
                    if(bytes_counter_r == 7) begin
                        rst_counter_w = 0;
                    end  // Need else?
                end
            end
        end

        S_WAIT_DATA: begin					 
            rst_counter_w = rst_counter_r + 1;
            if(rst_counter_r == 28'hFFFFFFF) begin
                rst_counter_w <= 0; 
            end
        end

        S_SEND_DATA: begin
            if(!avm_waitrequest) begin
                if(bytes_counter_r == 15) begin
                    rst_counter_w = 28'b0;
                end  // Need else?
            end
        end

        default: rst_counter_w = rst_counter_r;
end

always_comb begin // bytes_counter_w
    case(state_r)
     
        S_READ_KEY: begin
            if(!avm_waitrequest) begin
                bytes_counter_w = bytes_counter_r - 8'd8;
            end
        end

        S_WAIT_DATA: begin
            if(rst_counter_r == 28'hFFFFFFF) begin 
                bytes_counter_w <= 8'd255;
            end
        end

        S_READ_DATA: begin
            if(!avm_waitrequest) begin
                bytes_counter_w = bytes_counter_r - 8'd8;
            end
        end

        S_SEND_DATA: begin
            if(!avm_waitrequest) begin
                if(bytes_counter_r == 15) begin
                    bytes_counter_w = bytes_counter_r - 8'd16;
                end
                else begin
                    bytes_counter_w = bytes_counter_r - 8'd8;
                end
            end
        end

        default: bytes_counter_w = bytes_counter_r;
end

always_comb begin  // enc_w
    case(state_r)

        S_WAIT_DATA: begin
            if(rst_counter_r == 28'hFFFFFFF) begin 
                enc_w <= 0;
            end
        end

        S_READ_DATA: begin
            if(!avm_waitrequest) begin
                enc_w[bytes_counter_r-:8] = avm_readdata[7:0];
            end  // need else??
        end

        default: enc_w = enc_r;
end

always_comb begin  // dec_w
    case(state_r)

        S_WAIT_DATA: begin
            if(rst_counter_r == 28'hFFFFFFF) begin 
                dec_w <= 0;
            end  // need else?
        end

        S_WAIT_CALCULATE: begin
            if (rsa_finished) begin
                dec_w = rsa_dec;
            end  // need else?
        end

        S_SEND_DATA: begin
            if(!avm_waitrequest) begin
                if(bytes_counter_r == 15) begin
                    dec_w = dec_r;  // TODO: ??????
                end
                else begin
                    dec_w = dec_r << 8;
                end
            end
        end

        default: dec_w = dec_r;
end

always_comb begin  // rsa_start_w
    case(state_r)

        S_WAIT_DATA: begin
            if(rst_counter_r == 28'hFFFFFFF) begin 
                rsa_start_w <= 0;
            end
        end

        S_READ_DATA: begin
            if(!avm_waitrequest) begin
                if(bytes_counter_r == 7) begin
                    rsa_start_w = 1;
                end
            end
        end

        S_WAIT_CALCULATE: begin
            rsa_start_w = 0;
        end

        default: rsa_start_w = rsa_start_r;
end

always_comb begin  // core_finished_w
    case(state_r)

        S_WAIT_DATA: begin
            if(rst_counter_r == 28'hFFFFFFF) begin 
                core_finished_w <= 0;
            end
        end

        S_WAIT_CALCULATE: begin
            if (rsa_finished) begin
                core_finished_w = 1;
            end
            if (!avm_waitrequest && core_finished_r == 1) begin
                core_finished_w = 0;
            end
        end

        default: core_finished_w = core_finished_r;
end

///////////////////////////////////////////////////////////////////////


always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_WAIT_KEY;
        bytes_counter_r <= 8'd255;
        rsa_start_r <= 0;
			NorD_r <= 0;
			core_finished_r <= 0;
			rst_counter_r <= 0;
    end else begin
        n_r <= n_w;
        d_r <= d_w;
        enc_r <= enc_w;
        dec_r <= dec_w;
        avm_address_r <= avm_address_w;
        avm_read_r <= avm_read_w;
        avm_write_r <= avm_write_w;
        state_r <= state_w;
        bytes_counter_r <= bytes_counter_w;
        rsa_start_r <= rsa_start_w;
		NorD_r <= NorD_w;
		core_finished_r <= core_finished_w;
		rst_counter_r <= rst_counter_w;
    end
end
 
endmodule
