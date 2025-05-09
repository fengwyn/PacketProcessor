`timescale 1ns / 100ps

/*

		16-bit source port			16-bit destination port
_________________________________________________________________________________________________
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
_________________________________________________________________________________________________
		16-bit length				16-bit checksum
_________________________________________________________________________________________________
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 | 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
_________________________________________________________________________________________________
					       data
_________________________________________________________________________________________________
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
..	..	..	..	..	..	..	..	..	..	..	..
 ..		 ..		 ..		 ..		  ..		 ..


wire [15:0] src_port = 16'b0111; // src port: 7
wire [15:0] dst_port = 16'b0010; // dst port: 2

wire [15:0] length = 16'b111111; // packet length: 63 bits
wire [15:0] checksum = 16'hF00F; // F + 0 + 0 + ~F = FFFF -> -0

// We'll write a 64-bit packet
reg [63:0] packet = {src_port, dst_port, length, checksum};
*/


module PacketProcessor_tb;
    // --------------------------------------------------------------------
    // Parameters & signals
    // --------------------------------------------------------------------
    localparam CLK_PERIOD      = 10;
    localparam DATA_WIDTH      = 16;
    localparam FIFO_DEPTH      = 64;
    localparam UDP_HDR_OFFSET  = 0;

    reg               clk;
    reg               rst;
    reg               i_udp_data;

    wire              data_out;
    wire              data_out_valid;
    wire              flush_requested;
    wire              eth_available;

    reg [DATA_WIDTH-1:0] out_words [0:15];
    integer             out_idx, i;

    // Packet fields
    parameter [15:0] src_port = 16'b0111;
    parameter [15:0] dst_port = 16'b0010;
    parameter [15:0] length   = 16'b0100;
    parameter [15:0] checksum = 16'h724D;

    // Construct packet header (64 bits total)
    reg [63:0] packet = {src_port, dst_port, length, checksum};

    // --------------------------------------------------------------------
    // DUT instantiation
    // --------------------------------------------------------------------
    PacketProcessor #(
        .DATA_WIDTH     (DATA_WIDTH),
        .FIFO_DEPTH     (FIFO_DEPTH),
        .UDP_HDR_OFFSET (UDP_HDR_OFFSET)
    ) dut (
        .i_clk           (clk),
        .i_rst           (rst),
        .i_spi_miso      (1'b0),
        .i_spi_clk       (1'b0),
        .i_w5500_int     (1'b0),
        .data_out        (data_out),
        .data_out_valid  (data_out_valid),
        .flush_requested (flush_requested),
        .eth_available   (eth_available),
        .i_udp_data      (i_udp_data)
    );

    // --------------------------------------------------------------------
    // Clock
    // --------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --------------------------------------------------------------------
    // Stimulus: reset -> shift in bits -> wait for processing
    // --------------------------------------------------------------------
    integer word, bit;
    initial begin
        rst = 1;
        i_udp_data = 0;
        out_idx = 0;
        #(CLK_PERIOD*3);

        rst = 0;
        #(CLK_PERIOD);

        // Send all bits of the 64-bit packet (LSB first)
        for (word = 0; word < 4; word = word + 1) begin
            for (bit = 0; bit < 16; bit = bit + 1) begin
                i_udp_data = packet[word*16 + bit];
                #(CLK_PERIOD);
            end
        end

        // Wait for packet processing to complete
        #(CLK_PERIOD*20);
        $display("Finished sending packet bits.");

        // ---------------------------------------------------------------
        // Check data_out from W5500 readout interface
        // ---------------------------------------------------------------
        wait (data_out_valid);
        forever begin
            if (data_out_valid) begin
                out_words[out_idx] = data_out;
                $display("Output word %0d: %b", out_idx, data_out);
                out_idx = out_idx + 1;
            end
            #(CLK_PERIOD);
            if (out_idx == 4) begin
                $display("All output words captured.");
            end
        end

        // Final display
        $display("===== Final Output Words =====");
                
        for (i = 0; i < out_idx; i = i + 1) begin
            $display("Word[%0d] = 0x%h", i, out_words[i]);
        end

        $finish;
    end

endmodule
