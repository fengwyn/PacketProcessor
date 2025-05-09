`timescale 1ns / 100ps


module W5500Driver_tb;
    // Parameters
    localparam CLK_PERIOD = 10;
    localparam DATA_READ_SIZE = 8;

    reg                clk;
    reg                rst;
    reg                miso;

    reg                data_input_valid;
    reg  [47:0]        data_input;
    reg                flush_requested;

    wire               mosi;
    wire               spi_clk;
    wire               spi_chip_select_n;
    wire [DATA_READ_SIZE-1:0] data_read;
    wire               is_available;
    
    wire               instr_valid = 1'b0;
    wire [31:0]        instr_data  = 32'd0;


    W5500Driver #(
        .DATA_READ_SIZE(DATA_READ_SIZE)
    ) dut (
        .clk(clk),
        .miso(miso),
        .data_input_valid(data_input_valid),
        .data_input(data_input),
        .flush_requested(flush_requested),
        .mosi(mosi),
        .spi_clk(spi_clk),
        .spi_chip_select_n(spi_chip_select_n),
        .data_read(data_read),
        .data_read_valid(),
        .is_available(is_available)
    );

    // the clock
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // input data
    initial begin
        // Initialize
        rst = 1;
        miso = 0;
        data_input_valid = 0;
        data_input = 48'hDEADBEEF_CAFE; // 0xBACA105
        flush_requested = 0;
        #(CLK_PERIOD*3);

        // Release reset
        rst = 0;
        #(CLK_PERIOD*2);

        // Check availability
        $display("%0t: is_available = %b", $time, is_available);

        // We'll send a single 48-bit word
        data_input_valid = 1;
        #(CLK_PERIOD);
        data_input_valid = 0;

        // Wait and then request flush
        #(CLK_PERIOD*5);
        flush_requested = 1;
        #(CLK_PERIOD);
        flush_requested = 0;

        // We'll drive MISO with dummy data during command phase
        // and simulate 32 bits of response (pattern 0xA5)
        repeat(32) begin
            @(posedge spi_clk);
            miso = 1'b1; // A5 bits are 1010_0101...
        end

        // Observe read
        #(CLK_PERIOD*5);
        $display("%0t: data_read = 0x%02h", $time, data_read);

        $display("Testbench complete");
        $finish;
    end

    // read-out
    initial begin
        $dumpfile("W5500Driver_tb.vcd");
        $dumpvars(0, W5500Driver_tb);
    end

endmodule
