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


`timescale 1ns / 100ps

module PacketProcessor_tb;
    // --------------------------------------------------------------------
    // Parameters & signals
    // --------------------------------------------------------------------
    localparam CLK_PERIOD      = 10;
    localparam DATA_WIDTH      = 16;
    localparam FIFO_DEPTH      = 16;
    // override UDP_HDR_OFFSET to 0 so header starts immediately
    localparam UDP_HDR_OFFSET  = 0;

    reg               clk;
    reg               rst;
    // serial bit in
    reg               i_udp_data;
    // tie off unused SPI/int signals
    wire              data_out;
    wire              data_out_valid;
    wire              flush_requested;
    wire              eth_available;

    // we'll collect output words here
    reg [DATA_WIDTH-1:0] out_words [0:3];
    integer             out_idx;

    // --------------------------------------------------------------------
    // The 4-word “packet”: src=7, dst=2, len=2, checksum=0xA
    // Negative-zero condition: 5+3+2 + ~A (0xF5) = 0xFFFF
    // Each 16-bit word will be shifted LSB-first.
    // --------------------------------------------------------------------
    
    parameter [15:0] src_port = 16'b0111; // src port: 7
    parameter [15:0] dst_port = 16'b0010; // dst port: 2

    parameter [15:0] length = 16'b0100; // packet length: this packet wont carry data, only header (4 bytes total)
    parameter [15:0] checksum = 16'h724D; // 7 + 2 + 4 + ~D = FFFF -> -0
    
    reg [63:0] packet = {
        src_port,   // source port
        dst_port,   // dest port
        length,   // length
        checksum    // checksum
    };

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
    // Apply reset, then pump bits
    // --------------------------------------------------------------------
    integer word, bit;
    initial begin
        // initialize
        rst = 1;
        i_udp_data = 0;
        out_idx = 0;
        #(CLK_PERIOD*3);

        // release reset
        rst = 0;
        #(CLK_PERIOD);

        // feed each 16-bit word LSB-first
        for (word = 0; word < 4; word = word + 1) begin
            for (bit = 0; bit < DATA_WIDTH; bit = bit + 1) begin
                i_udp_data = packet[word*16 + bit];
                #(CLK_PERIOD);
            end
        end

        // after last bit, give a few cycles for DUT to process
        #(CLK_PERIOD*10);

        // done
        $display("TB completed.");
        $finish;
    end

endmodule
