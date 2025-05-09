`timescale 1ns / 100ps

// Future me -- No need to update or revise, it's working properly albeit R/W is to be done exclusive!


// A First-In First-Out RAM implementation, based on Getting Started with FPGAs provided examples
// Infers a Dual Port RAM (DPRAM) Based FIFO using a single clock
// Uses a Dual Port RAM but automatically handles read/write addresses.
// Parameters: 
// WIDTH     - Width of the FIFO
// DEPTH     - Max number of items able to be stored in the FIFO
//
// This FIFO cannot be used to cross clock domains, because in order to keep count
// correctly it would need to handle all metastability issues. 
// If crossing clock domains is required, use FIFO primitives directly from the vendor.
module FIFO_RAM #(
    parameter WIDTH = 16,
    parameter DEPTH = 4096,
    parameter ADDR_WIDTH = $clog2(DEPTH)
)(
    input  wire                  i_clk,
    input  wire                  i_rst,
    input  wire [WIDTH-1:0]      i_wr_data,
    input  wire                  i_wr_en,
    input  wire                  i_rd_en,
    output reg  [WIDTH-1:0]      o_rd_data,
    output wire                  o_empty,
    output wire                  o_full,
    output wire [ADDR_WIDTH:0]   o_count
);

    // Parameter validation
    initial begin
        if ((DEPTH & (DEPTH-1)) != 0) begin
            $error("FIFO_RAM: DEPTH must be a power of 2");
            $finish;
        end
    end

    // Memory array
    reg [WIDTH-1:0] ram [0:DEPTH-1];
    
    // Pointers
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count;

    // Empty and full flags
    assign o_empty = (count == 0);
    assign o_full  = (count == DEPTH);
    assign o_count = count;

    // Write pointer and data
    always @(posedge i_clk) begin
        
        if (i_rst) begin
            wr_ptr <= 0;

        end else if (i_wr_en && !o_full) begin
            ram[wr_ptr] <= i_wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read pointer and data
    always @(posedge i_clk) begin
        
        if (i_rst) begin
            rd_ptr <= 0;
            o_rd_data <= 0;
        end else if (i_rd_en && !o_empty) begin
            o_rd_data <= ram[rd_ptr];
            rd_ptr <= rd_ptr + 1;
        end
    end

    // Count tracking
    always @(posedge i_clk) begin

        if (i_rst) begin
            count <= 0;
        end else begin
            case ({i_wr_en && !o_full, i_rd_en && !o_empty})
                2'b10: count <= count + 1;
                2'b01: count <= count - 1;
                default: count <= count;
            endcase
        end
    end

endmodule

 
 // Example instantiation

 /*
FIFO_RAM #(
    .WIDTH(8),
    .DEPTH(256),
    .REG_OUTPUTS(1),
    .ALMOST_FULL(192),    // 75% of depth
    .ALMOST_EMPTY(64)     // 25% of depth
) fifo_inst (
    .i_clk(clk),
    .i_rst(rst),
    .i_wr_data(wr_data),
    .i_wr_en(wr_en),
    .i_rd_en(rd_en),
    .o_rd_data(rd_data),
    .o_empty(empty),
    .o_full(full),
    .o_almost_empty(almost_empty),
    .o_almost_full(almost_full),
    .o_count(count)
);
*/