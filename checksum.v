`timescale 1ns / 100ps

// UDP Checksum Verification Module
// This module verifies the UDP checksum by:
// 1. Receiving 16-bit buffer containing 4 bytes
// 2. Extracting and summing the 4 bytes
// 3. Verifying if the result equals FFFF (-0) (valid checksum)

module checksum #(
    parameter WORD_COUNT = 0    // This can be useful if we know how many words will be input
    )(
    
    input wire i_clk,                    // Clock input
    input wire i_rst,                    // Reset input
    
    input wire [15:0] i_checksum_buffer, // 16-bit checksum buffer input
    input wire i_start,                  // Start signal to begin checksum calculation
    output reg o_checksum_valid          // Checksum validation result
);

    // Internal registers
    reg [7:0] byte1, byte2, byte3, byte4;  // Individual bytes
    reg [31:0] checksum_sum;               // 32-bit sum to handle overflow
    
    
    // Extract bytes from buffer
    always @(*) begin

        // NOTE: Technically, they're halfwords --- keeping as byte
        byte1 = i_checksum_buffer[3:0];    // First byte
        byte2 = i_checksum_buffer[7:4];    // Second byte
        byte3 = i_checksum_buffer[11:8];   // Third byte
        byte4 = i_checksum_buffer[15:12];  // Fourth byte

    end
    
    // Main checksum logic
    always @(posedge i_clk) begin
        if (i_rst) begin
            checksum_sum <= 32'h0000;
            o_checksum_valid <= 1'b0;

        end else if (i_start) begin

            // Sum all bytes
            checksum_sum <= byte1 + byte2 + byte3 + byte4;
            // Check if sum equals to negative 0 (valid checksum  0xFF FF FF FF)
            o_checksum_valid <= ((byte1 + byte2 + byte3 + ~byte4));

        end
    end

endmodule
