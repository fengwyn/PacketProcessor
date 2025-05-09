`timescale 1ns / 100ps

// Testbench for the checksum module
module checksum_tb;

    // Parameters
    localparam CLK_PERIOD = 10;

    // DUT I/O
    reg         tb_clk;
    reg         tb_rst;
    reg  [15:0] tb_checksum_buffer;
    reg         tb_start;
    wire        tb_checksum_valid;

    // Instantiate the Device Under Test
    checksum #(
        .WORD_COUNT(0)
    ) dut (
        .i_clk(tb_clk),
        .i_rst(tb_rst),
        .i_checksum_buffer(tb_checksum_buffer),
        .i_start(tb_start),
        .o_checksum_valid(tb_checksum_valid)
    );

    // Clock generation ticks
    initial begin
        tb_clk = 0;
        forever #(CLK_PERIOD/2) tb_clk = ~tb_clk;
    end

    // VCD dump for the waveform viewing
    initial begin
        $dumpfile("checksum_tb.vcd");
        $dumpvars(0, checksum_tb);
    end

    // Test stimulus
    initial begin
        // Apply reset
        tb_rst = 1;
        tb_start = 0;
        tb_checksum_buffer = 16'h0000;
        #(CLK_PERIOD*2);
        tb_rst = 0;
        #(CLK_PERIOD*2);

        // Test vectors
        // 1) Valid: all zero => sum=~nib4=~0=FF => valid
        tb_checksum_buffer = 16'h0000;
        tb_start = 1;
        #(CLK_PERIOD);
        tb_start = 0;
        #(CLK_PERIOD);
        $display("%0t: buffer=0x%04h valid=%b (expected 1)", $time, tb_checksum_buffer, tb_checksum_valid);

        // 2) Invalid: 1234
        tb_checksum_buffer = 16'h1234;
        tb_start = 1; #(CLK_PERIOD); tb_start = 0; #(CLK_PERIOD);
        $display("%0t: buffer=0x%04h valid=%b (expected 0)", $time, tb_checksum_buffer, tb_checksum_valid);

        // 3) Valid: F00F
        tb_checksum_buffer = 16'hF00F;
        tb_start = 1; #(CLK_PERIOD); tb_start = 0; #(CLK_PERIOD);
        $display("%0t: buffer=0x%04h valid=%b (expected 1)", $time, tb_checksum_buffer, tb_checksum_valid);

        // 4) Invalid: 0FF1
        tb_checksum_buffer = 16'h0FF1;
        tb_start = 1; #(CLK_PERIOD); tb_start = 0; #(CLK_PERIOD);
        $display("%0t: buffer=0x%04h valid=%b (expected 0)", $time, tb_checksum_buffer, tb_checksum_valid);

        // 5) Invalid: 5555
        tb_checksum_buffer = 16'h5555;
        tb_start = 1; #(CLK_PERIOD); tb_start = 0; #(CLK_PERIOD);
        $display("%0t: buffer=0x%04h valid=%b (expected 0)", $time, tb_checksum_buffer, tb_checksum_valid);

        $display("Testbench completed.");
        $finish;
        
    end
endmodule
