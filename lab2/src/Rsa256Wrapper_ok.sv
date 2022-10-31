// `include "Rsa256Core.sv"
module Rsa256Wrapper (
    input         avm_rst,
    input         avm_clk,
    output  [4:0] avm_address, 
    output        avm_read,   //read contrl bit
    input  [31:0] avm_readdata, //read data
    output        avm_write,  //write control bit
    output [31:0] avm_writedata, //write data
    input         avm_waitrequest //wait control bit 
);

localparam RX_BASE     = 0*4;
localparam TX_BASE     = 1*4;
localparam STATUS_BASE = 2*4;
localparam TX_OK_BIT   = 6;
localparam RX_OK_BIT   = 7;

// Feel free to design your own FSM!
// localparam S_IDLE = 0;
// localparam S_GET_N = 1;
// localparam S_GET_D = 2;
// localparam S_GET_DATA = 3;
localparam S_READ_IDLE = 0;
localparam S_READ_KEY = 1;
localparam S_READ_DATA = 2;
localparam S_WAIT_CALCULATE = 3;
localparam S_WRITE_IDLE = 4;
localparam S_WRITE = 5;
localparam S_END_IDLE = 6;

logic [255:0] n_r, n_w, d_r, d_w, enc_r, enc_w, dec_r, dec_w;
logic [2:0] state_r, state_w;
logic [6:0] bytes_counter_r, bytes_counter_w;
logic [4:0] avm_address_r, avm_address_w;
logic avm_read_r, avm_read_w, avm_write_r, avm_write_w;
logic       get_bite_r, get_bite_w;
logic [15:0] time_counter_r, time_counter_w;

logic rsa_start_r, rsa_start_w;
logic rsa_finished;
logic [255:0] rsa_dec;

// debug

logic [255:0] cnt_r, cnt_w ;

assign avm_address = avm_address_r;
assign avm_read = avm_read_r;
assign avm_write = avm_write_r;
assign avm_writedata = dec_r[247-:8];

Rsa256Core rsa256_core(
    .i_clk(avm_clk),
    .i_rst(avm_rst),
    .i_start(rsa_start_r),
    .i_a(enc_r),    //text: 256bit
    .i_d(d_r),      // key: 256bit
    .i_n(n_r),      //   N: 256bit
    .o_a_pow_d(rsa_dec),
    .o_finished(rsa_finished)
);
//Read
task StartRead;
    input [4:0] addr;
    begin
        avm_read_w = 1;
        avm_write_w = 0;
        avm_address_w = addr;
    end
endtask

task EndRead;
    begin
        avm_read_w = 0;
    end
endtask

//Write
task StartWrite;
    input [4:0] addr;
    begin
        avm_read_w = 0;
        avm_write_w = 1;
        avm_address_w = addr;
    end
endtask

task EndWrite;
    begin
       avm_write_w = 0; 
    end
endtask

always_comb begin

    n_w = n_r;
    d_w = d_r;
    enc_w = enc_r;
    dec_w = dec_r;
    avm_address_w = avm_address_r;
    avm_read_w = avm_read_r;
    avm_write_w = avm_write_r;
    bytes_counter_w = bytes_counter_r;
    rsa_start_w = rsa_start_r;
    get_bite_w = get_bite_r;
    time_counter_w = time_counter_r;
    //$display("state_r = %d", state_r);
    //$display("avm_waitrequest = %d", avm_waitrequest);
    case(state_r) 
        S_READ_IDLE : begin //0
            StartRead(STATUS_BASE);
            if(!avm_waitrequest) begin
                if(avm_readdata[RX_OK_BIT]) begin
                    StartRead(RX_BASE);

                    if(!get_bite_r) begin
                        state_w = S_READ_KEY;
                    end
                    else state_w = S_READ_DATA;
                end
                else begin
                    state_w = S_READ_IDLE;
                end
            end
            else begin
                state_w = S_READ_IDLE;
            end
        end
        
        // Eat Readdata into array 
        S_READ_KEY : begin //1
            if(!avm_waitrequest) begin
                StartRead(STATUS_BASE);
                if(!bytes_counter_r[5]) begin
                    n_w = n_r << 8;
                    n_w[7:0] = avm_readdata[7:0];
                    bytes_counter_w = bytes_counter_r + 1'b1 ;
                    state_w = S_READ_IDLE;
                end
                else begin
                    d_w = d_r << 8;
                    d_w[7:0] = avm_readdata[7:0];
                    bytes_counter_w = bytes_counter_r + 1'b1 ;
                    state_w = S_READ_IDLE;
                end

                // if(bytes_counter_w[6] == 1) begin//////////////////////////////
                //     bytes_counter_w = 0;
                //     get_bite_w = get_bite_r + 1'b1;
                // end
                // else begin
                //     get_bite_w = get_bite_r;
                // end
                if(bytes_counter_w == 7'd64) begin//////////////////////////////
                    bytes_counter_w = 0;
                    get_bite_w = get_bite_r + 1'b1;
                end
                else begin
                    get_bite_w = get_bite_r;
                end
            end
            else begin
                bytes_counter_w = bytes_counter_r;
                state_w = state_r;
            end
            
        end

        S_READ_DATA : begin
            if(!avm_waitrequest) begin
                StartRead(STATUS_BASE);
                enc_w = enc_r << 8;
                enc_w[7:0] = avm_readdata[7:0];
                bytes_counter_w = bytes_counter_r + 1'b1 ;
                if(bytes_counter_r == 31) begin
                    bytes_counter_w = 1;
                    get_bite_w = 0;
                    rsa_start_w = 1'b1;
                    EndRead();
                    state_w = S_WAIT_CALCULATE;

                end
                else begin
                    get_bite_w = get_bite_r;
                    state_w = S_READ_IDLE;
                end
                
            end
            else begin
                bytes_counter_w = bytes_counter_r;
                state_w = state_r;
            end
        end


        S_WAIT_CALCULATE : begin //2
            rsa_start_w = 1'b0;
            if(rsa_finished) begin
                dec_w = rsa_dec;
                $display("test = %h", rsa_dec);
                //StartRead(STATUS_BASE);
                state_w = S_WRITE_IDLE; //next state
            end
            else begin
                state_w = state_r;
            end
        end
/*
        S_SEND_DATA : begin //5
            if(!avm_waitrequest) begin
                if(avm_readdata[TX_OK_BIT] && bytes_counter_r[6] == 1'b0) begin
                    StartWrite(TX_BASE);
                    get_n_send_w = 3;
                    state_w = S_WRITE;
                end
                else if (bytes_counter_r[6] == 1'b1) begin
                    EndWrite();
                    get_n_send_w = 2;  // return to S_GET_DATA
                    bytes_counter_w = 0;
                    enc_w = 0;  ///////////////////////////////////////////////////////???????????????????
                    state_w = S_IDLE;  // changeable //next state
                end
                else begin
                    state_w = state_r;
                end
            end
            else begin
                state_w = state_r;
            end
        end
*/
        S_WRITE_IDLE : begin //3
            StartRead(STATUS_BASE);
            if(!avm_waitrequest) begin
                if(avm_readdata[TX_OK_BIT]) begin
                    StartWrite(TX_BASE);
                    state_w = S_WRITE;
                end
                else begin
                    state_w = S_WRITE_IDLE;
                end
            end
            else begin
                state_w = S_WRITE_IDLE;
            end
        end

        S_WRITE : begin //4
            if(!avm_waitrequest) begin
                StartRead(STATUS_BASE);
                dec_w = {dec_r[247:0], 8'b0};  //dec_w = dec_r << 8;
                
                if(bytes_counter_r == 31) begin
                    EndWrite();
                    get_bite_w = 1;  //continuous reading
                    bytes_counter_w = 0;
                    enc_w = 0;
                    dec_w = 0;
                    state_w = S_END_IDLE;
                end
                else begin
                    bytes_counter_w = bytes_counter_r + 1'b1 ;
                    state_w = S_WRITE_IDLE;
                end
            end
            else begin
                bytes_counter_w = bytes_counter_r;
                state_w = state_r;
            end
        end

        S_END_IDLE : begin
            StartRead(STATUS_BASE);
            if(time_counter_r < 16'hfffc)begin
                // time_counter_w = time_counter_r + 1'b1;
                //state_w = S_END_IDLE;
                if(!avm_waitrequest) begin
                    if(avm_readdata[RX_OK_BIT]) begin
                        StartRead(RX_BASE);
                        state_w = S_READ_DATA;
                        time_counter_w = 0;
                    end
                    else begin
                        time_counter_w = time_counter_r + 1'b1;
                        state_w = S_END_IDLE;
                    end
                end
                else begin
                    time_counter_w = time_counter_r + 1'b1;
                    state_w = S_END_IDLE;
                end
            end
            else begin
                n_w = 0;
                d_w = 0;
                enc_w = 0;
                dec_w = 0;
                avm_address_w = STATUS_BASE;
                avm_read_w = 0;
                avm_write_w = 0;
                state_w = S_READ_IDLE;  ////important
                bytes_counter_w = 0; // Origin : 63
                rsa_start_w = 0;
                get_bite_w = 0;
                time_counter_w = 0;
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
        avm_read_r <= 0;
        avm_write_r <= 0;
        state_r <= S_READ_IDLE;
        bytes_counter_r <= 0; // Origin : 63
        rsa_start_r <= 0;
        get_bite_r <= 0;
        time_counter_r <= 0;
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
        get_bite_r <= get_bite_w;
        time_counter_r <= time_counter_w;
    end
end

endmodule