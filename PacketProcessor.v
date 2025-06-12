`timescale 1ns / 100ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: 
// 
// Create Date: 05/07/2025 12:38:22 PM
// Design Name: SYN-UDP
// Module Name: PacketProcessor
// Project Name: 
// Target Devices: Basys-3 Artix 7
// Tool Versions: 
// Description: UDP Packet Processor with Checksum Verification
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



/*
________________________________________________________________________________________
W5500 Port Connections on Basys 3:

	MOSI -> JA1	    JA[0]
 	MISO -> JA2	    JA[1]
	SCLK -> JA3	    JA[2]
	CS   -> JA4     JA[3]
		
    VCC  -> JA6
    GND  -> JA5
	
	RST  -> JA7	    JA[4]
	INT  -> JA8	    JA[5]
	
________________________________________________________________________________________
*/


module PacketProcessor #(
    parameter DATA_WIDTH    = 16,   // 16-bit width
    parameter FIFO_DEPTH    = 4096, // 4096-bit depth, a total of 16 * 4096 = 65536 total bits
    // Ethernet(14) + IPv4 header (assumed fixed 20) = byte offset where UDP header starts
    parameter HDR_OFFSET = 0   // Since we're now formatting the UDP into bytes, we'll know the chekcsum offset (4th in buffer)
)(

    // FPGA Clock and Reset
    input i_clk,
    input i_rst,

    // In/outs from JBA -> Ethernet Module
    input i_spi_miso,
    input i_spi_clk,
    input i_w5500_int,
    output data_out,
    output data_out_valid,
    output flush_requested,
    output eth_available,    // output eth_available this signal is controlled internally by the w5500 module itself

    // Input from JB
    input i_udp_data
    );

    // State machine states for serial data reading
    localparam IDLE = 3'b000;
    localparam READ_BYTE = 3'b001;
    localparam WRITE_FIFO = 3'b010;
    localparam CHECK_CHECKSUM = 3'b011;
    localparam SEND_TO_W5500 = 3'b100;
    localparam DROP_PACKET = 3'b101;

    // Registers for serial data reading
    reg [2:0] state = IDLE;
    reg [7:0] byte_buffer = 8'b0;
    reg [2:0] bit_count = 3'b0;
    reg [15:0] checksum_buffer = 16'b0; // This'll be the captured UDP checksum word
    reg [5:0] byte_count = 16'b0;  // Count bytes to track UDP header position (byte indext in frame)

    // FIFO control signals
    wire [DATA_WIDTH-1:0] fifo_data_out;
    wire fifo_empty;
    wire fifo_full;
    reg fifo_wr_en = 1'b0;
    reg fifo_rd_en = 1'b0;
    reg [DATA_WIDTH-1:0] fifo_data_in = 16'b0;

    // W5500 control signals
    reg [47:0] w5500_data = 48'b0;
    reg w5500_data_valid = 1'b0;
    reg w5500_flush = 1'b0;

    // Instantiate FIFO RAM
    FIFO_RAM #(
        .WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) udp_fifo (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_wr_data(fifo_data_in),
        .i_wr_en(fifo_wr_en),
        .i_rd_en(fifo_rd_en),
        .o_rd_data(fifo_data_out),
        .o_empty(fifo_empty),
        .o_full(fifo_full),
        .o_count()
    );

    // Instantiate W5500 Driver
    W5500Driver w5500_driver (
        .clk(i_clk),
        .miso(i_spi_miso),
        .data_input_valid(w5500_data_valid),
        .data_input(w5500_data),
        .flush_requested(w5500_flush),
        .is_available(eth_available)
    );

    // Instantiate Checksum Verifier
    wire checksum_valid;
    
    checksum checksum_verifier (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_checksum_buffer(checksum_buffer),
        .i_start(state == CHECK_CHECKSUM),
        .o_checksum_valid(checksum_valid)
    );

    // Main state machine for packet processing
    always @(posedge i_clk) begin

        if (i_rst) begin
            // These are for the asynchronous reset of all control signals
            state <= IDLE;
            byte_buffer <= 8'b0;
            bit_count <= 3'b0;
            byte_count <= 16'b0;
            fifo_wr_en <= 1'b0;
            fifo_rd_en <= 1'b0;
            fifo_data_in <= {DATA_WIDTH{1'b0}};
            w5500_data_valid <= 1'b0;
            w5500_flush <= 1'b0;

        end else begin

            case (state)

                // IDLE: We're going to wait for the first serial bit of packet to arrive
                IDLE: begin

                    if (i_udp_data) begin  // Start of packet
                        state <= READ_BYTE;
                        bit_count <= 3'b0;
                        byte_count <= 16'b0;
                    end
                end

                // READ_BYTE: Here we'll shift the bits until a full byte is assembled
                READ_BYTE: begin

                    byte_buffer <= {byte_buffer[6:0], i_udp_data};
                    bit_count <= bit_count + 1'b1;
                    
                    // Finally our byte is complete
                    if (bit_count == 3'b111) begin
                        state <= WRITE_FIFO;
                        byte_count <= byte_count + 1'b1;    // We'll be tracking the byte counts such as to make sure we read full UDP packet
                    end
                end

                // WRITE_FIFO: Now we'll write the assembled byte into FIFO or capture the checksum
                WRITE_FIFO: begin

                    if (byte_count == (HDR_OFFSET + 4)) begin  // Reached checksum field
                        // The UDP offset must be at the buffer index 4 and 5
                        // So we'll we'll read out the currently last buffered FIFO byte as well as the current byte placed in buffer
                        checksum_buffer <= {byte_buffer, fifo_data_out[7:0]};
                        state <= CHECK_CHECKSUM;
                    end else begin
                        // Now we'll push the byte into FIFO
                        fifo_data_in <= {fifo_data_in[7:0], byte_buffer};
                        fifo_wr_en <= 1'b1;
                        state <= READ_BYTE;
                    end
                end

                // CHECK_CHECKSUM: We'll wait 1 cycle for checksum valid to update
                CHECK_CHECKSUM: begin

                    if (checksum_valid) begin
                        state <= SEND_TO_W5500;
                    end else begin
                        state <= DROP_PACKET;
                    end

                end

                // SEND_TO_W5500: Read and forward the FIFO contents when W5500 is ready (clear to send!)
                SEND_TO_W5500: begin

                    if (!fifo_empty && eth_available) begin
                        fifo_rd_en <= 1'b1;
                        w5500_data <= {w5500_data[39:0], fifo_data_out};
                        w5500_data_valid <= 1'b1;
                        state <= SEND_TO_W5500; // Stay in this state whilst content in buffer :3
                    end else if (fifo_empty) begin
                        w5500_flush <= 1'b1; // Okay done let's flush the w5500 buffer
                        state <= IDLE;
                    end
                end

                // DROP_PACKET: Invalid packet :< , we'll discard the FIFO contents and go back home :(
                DROP_PACKET: begin

                    // Reset FIFO and return to IDLE
                    fifo_wr_en <= 1'b0;
                    fifo_rd_en <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;

            endcase
        end
    end

    // Output assignments
    assign data_out = w5500_data;
    assign data_out_valid = w5500_data_valid;
    assign flush_requested = w5500_flush;

endmodule
