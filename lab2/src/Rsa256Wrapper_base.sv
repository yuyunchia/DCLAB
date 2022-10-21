module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address,
    output        avm_read,
    input  [31:0] avm_readdata,
    output        avm_write,
    output [31:0] avm_writedata,
    input         avm_waitrequest
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

// Feel free to design your own FSM!
// localparam S_GET_KEY = 0;
// localparam S_GET_DATA = 1;
// localparam S_WAIT_CALCULATE = 2;
// localparam S_SEND_DATA = 3;
localparam S_QUERY_RX = 0;  // Idle
localparam S_QUERY_TX = 1;
localparam S_READ_KEY = 2;
localparam S_READ_DATA = 3;
localparam S_WRITE = 4;
localparam S_WAIT_CALC = 5;

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
logic [2:0] state_r, state_w;
logic [6:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;

// New defined parameter
logic got_key_r, got_key_w;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8];

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

task EndIO;
    begin
        avm_read_w = 0;
        avm_write_w = 0;
    end
endtask

always_comb begin
    // TODO
    state_w = state_r;
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    avm_address_w = avm_address_r;
    got_key_w = got_key_r;
    bytes_counter_w = bytes_counter_r;
    d_w = d_r;
    n_w = n_r;
    enc_w = enc_r;
    dec_w = dec_r;
    rsa_start_w = rsa_start_r;

    case(state_r)
        S_QUERY_RX: begin
            StartRead(STATUS_BASE);
            if (avm_waitrequest) begin
                state_w = S_QUERY_RX;
            end
            else begin
                if (avm_readdata[RX_OK_BIT]) begin
                    StartRead(RX_BASE);  // Prepare for reading data or key
                    if (got_key_r) begin
                        state_w = S_READ_DATA;  // State change
                    end
                    else begin
                        state_w = S_READ_KEY;  // State change
                    end
                end
                else begin
                    state_w = S_QUERY_RX;  // For readability
                end
            end
        end

        S_READ_KEY: begin
            if (avm_waitrequest) begin
                state_w = S_READ_KEY;
            end
            else begin
                StartRead(STATUS_BASE);  // Prepare for S_QUERY_RX state
                state_w = S_QUERY_RX;  // State change
                // !!! This would be the 65th cycle !!!
                // if (bytes_counter_r[6]) begin  // Read 64 bytes (N and d)
                //     got_key_w = 1'b1;
                //     bytes_counter_w = 0;
                // end
                // else 
                if (bytes_counter_r[5]) begin  // Read D (Cycle 33 - 64)
                    d_w = d_r << 8;
                    d_w[7:0] = avm_readdata[7:0];
                    bytes_counter_w = bytes_counter_r + 1'b1; 
                end
                else begin  // Read N (Cycle 1 - 32)
                    n_w = n_r << 8;
                    n_w[7:0] = avm_readdata[7:0];
                    bytes_counter_w = bytes_counter_r + 1'b1;
                end

                if (bytes_counter_w[6]) begin  // Read 64 bytes (N and d) (Cycle 64)
                    got_key_w = 1'b1;
                    bytes_counter_w = 0;
                end
            end
        end

        S_READ_DATA: begin
            if (avm_waitrequest) begin
                state_w = S_READ_DATA;
            end
            else begin
                StartRead(STATUS_BASE);  // Prepare for S_QUERY_RX or S_QUERY_RX state
                state_w = S_QUERY_RX;  // State change
                enc_w = enc_r << 8;
                enc_w[7:0] = avm_readdata[7:0];
                bytes_counter_w = bytes_counter_r + 1'b1;
                if (bytes_counter_w[5]) begin  // (Cycle 32)
                    EndIO();
                    bytes_counter_w = 0;
                    rsa_start_w = 1;  // Start decoding
                    state_w = S_WAIT_CALC;  // State change
                end
            end
        end

        S_WAIT_CALC: begin
            rsa_start_w = 0;
            if (rsa_finished) begin
                dec_w = rsa_dec;
                state_w = S_QUERY_TX;  // State change
            end
            else begin
                state_w = state_r;  // For readability
            end
        end

        S_QUERY_TX: begin
            StartRead(STATUS_BASE);
            if (avm_waitrequest) begin
                state_w = S_QUERY_TX;
            end
            else begin
                if (avm_readdata[TX_OK_BIT]) begin
                    StartWrite(TX_BASE);  // Prepare for writing data
                    state_w = S_WRITE;  // State change
                end
                else begin
                    state_w = S_QUERY_TX;  // For readability
                end
            end
        end

        S_WRITE: begin
            if (avm_waitrequest) begin
                state_w = S_WRITE;
            end
            else begin
                StartRead(STATUS_BASE);  // Prepare for S_QUERY_TX state
                state_w = S_QUERY_TX;  // State change
                dec_w = dec_r << 8;  // "Line 46: assign avm_writedata = dec_r[247-:8];"
                bytes_counter_w = bytes_counter_r + 1'b1;
                if (bytes_counter_w == 31) begin  // (Cycle 31)
                    EndIO();
                    bytes_counter_w = 0;
                    state_w = S_QUERY_RX;  // State change
                    // TODO: Decide whether to reset enc_w, dec_w
                end
            end
        end
    endcase
end

always_ff @(posedge avm_clk or posedge avm_rst) begin
    if (avm_rst) begin
        n_r <= 0;
        d_r <= 0;
        enc_r <= 0;
        dec_r <= 0;
        avm_address_r <= STATUS_BASE;
        avm_read_r <= 1;
        avm_write_r <= 0;
        state_r <= S_QUERY_RX;
        // bytes_counter_r <= 63;
        bytes_counter_r <= 0;
        rsa_start_r <= 0;
        got_key_r <= 0;  // New
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
        got_key_r <= got_key_w;  // New
    end
end

endmodule