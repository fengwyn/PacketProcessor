`timescale 1ns / 1ps

module FIFO_RAM_tb();

    // Parameters
    localparam CLK_PERIOD = 10;
    localparam WIDTH = 8;
    localparam DEPTH = 16;
    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    // Test signals
    reg                    tb_clk;
    reg                    tb_rst_n;
    reg  [WIDTH-1:0]      tb_wr_data;
    reg                    tb_wr_en;
    reg                    tb_rd_en;
    wire [WIDTH-1:0]      tb_rd_data;
    wire                   tb_empty;
    wire                   tb_full;
    wire [ADDR_WIDTH:0]   tb_count;
    
    integer error_count = 0;
    
    // DUT instantiation
    FIFO_RAM #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) DUT (
        .i_clk(tb_clk),
        .i_rst(tb_rst_n),
        .i_wr_data(tb_wr_data),
        .i_wr_en(tb_wr_en),
        .i_rd_en(tb_rd_en),
        .o_rd_data(tb_rd_data),
        .o_empty(tb_empty),
        .o_full(tb_full),
        .o_count(tb_count)
    );
    
    // Clock generation
    initial begin
        tb_clk = 0;
        forever #(CLK_PERIOD/2) tb_clk = ~tb_clk;
    end
    
    // Test stimulus
    initial begin
        $display("Starting FIFO RAM Testbench...");
        
        // Initialize
        tb_rst_n = 1;
        tb_wr_en = 0;
        tb_rd_en = 0;
        tb_wr_data = 0;
        
        // Reset
        #(CLK_PERIOD);
        tb_rst_n = 0;
        #(CLK_PERIOD*2);
        tb_rst_n = 1;
        #(CLK_PERIOD);
        
        // Test 1: Write until full
        $display("Test 1: Writing data...");
        write_sequence();
        
        // Test 2: Read until empty
        $display("Test 2: Reading data...");
        read_sequence();
        
        // Test 3: Alternating read/write
        $display("Test 3: Alternating read/write...");
        alternating_test();
        
        // Report results
        $display("Tests completed with %0d errors", error_count);
        $finish;
    end
    
    // Write sequence
    task write_sequence;
        integer i;
        begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                @(negedge tb_clk);
                tb_wr_data <= i;
                tb_wr_en <= 1;
                @(posedge tb_clk);
                if (tb_count != i + 1) begin
                    $display("Count mismatch during write. Expected %0d, got %0d", i + 1, tb_count);
                    error_count = error_count + 1;
                end
            end
            @(negedge tb_clk);
            tb_wr_en <= 0;
            @(posedge tb_clk);
            
            if (!tb_full) begin
                $display("FIFO should be full");
                error_count = error_count + 1;
            end
        end
    endtask
    
    // Read sequence
    task read_sequence;
        integer i;
        begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                @(negedge tb_clk);
                tb_rd_en <= 1;
                @(posedge tb_clk);
                if (tb_rd_data !== i) begin
                    $display("Data mismatch. Expected %0h, got %0h", i, tb_rd_data);
                    error_count = error_count + 1;
                end
            end
            @(negedge tb_clk);
            tb_rd_en <= 0;
            @(posedge tb_clk);
            
            if (!tb_empty) begin
                $display("FIFO should be empty");
                error_count = error_count + 1;
            end
        end
    endtask
    
    // Alternating read/write test
    task alternating_test;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                // Write
                @(negedge tb_clk);
                tb_wr_data <= i;
                tb_wr_en <= 1;
                tb_rd_en <= 0;
                @(posedge tb_clk);
                @(negedge tb_clk);
                tb_wr_en <= 0;
                
                // Read
                @(negedge tb_clk);
                tb_rd_en <= 1;
                @(posedge tb_clk);
                if (tb_rd_data !== i) begin
                    $display("Alternating test data mismatch. Expected %0h, got %0h", i, tb_rd_data);
                    error_count = error_count + 1;
                end
                @(negedge tb_clk);
                tb_rd_en <= 0;
            end
        end
    endtask

    // Waveform dump
    initial begin
        $dumpfile("fifo_ram_tb.vcd");
        $dumpvars(0, FIFO_RAM_tb);
    end

endmodule