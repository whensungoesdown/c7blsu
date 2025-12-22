`timescale 1ns/1ps

module top_tb();

// Global signals
reg clk;
reg resetn;

// ECL interface signals
reg ecl_lsu_valid_e;
reg [6:0] ecl_lsu_op_e;
reg [31:0] ecl_lsu_base_e;
reg [31:0] ecl_lsu_offset_e;
reg [31:0] ecl_lsu_wdata_e;

// LSU output signals
wire lsu_ecl_data_valid_ls3;
wire [31:0] lsu_ecl_data_ls3;
wire lsu_ecl_wr_fin_ls3;  // 新增信号
wire lsu_ecl_except_ale_ls1;
wire [31:0] lsu_csr_except_badv_ls1;
wire lsu_ecl_except_buserr_ls3;
wire lsu_ecl_except_ecc_ls3;

// BIU interface
wire lsu_biu_rd_req_ls2;
wire [31:0] lsu_biu_rd_addr_ls2;
reg biu_lsu_rd_ack_ls2;
reg biu_lsu_data_valid_ls3;
reg [63:0] biu_lsu_data_ls3;

wire lsu_biu_wr_req_ls2;
wire [31:0] lsu_biu_wr_addr_ls2;
wire [63:0] lsu_biu_wr_data_ls2;
wire [7:0] lsu_biu_wr_strb_ls2;

reg biu_lsu_wr_ack_ls2;
reg biu_lsu_wr_fin_ls3;  // 信号名更新

// DUT instantiation
c7blsu uut (
    .clk(clk),
    .resetn(resetn),
    
    // ECL interface
    .ecl_lsu_valid_e(ecl_lsu_valid_e),
    .ecl_lsu_op_e(ecl_lsu_op_e),
    .ecl_lsu_base_e(ecl_lsu_base_e),
    .ecl_lsu_offset_e(ecl_lsu_offset_e),
    .ecl_lsu_wdata_e(ecl_lsu_wdata_e),
    
    .lsu_ecl_data_valid_ls3(lsu_ecl_data_valid_ls3),
    .lsu_ecl_data_ls3(lsu_ecl_data_ls3),
    .lsu_ecl_wr_fin_ls3(lsu_ecl_wr_fin_ls3),  // 新增连接
    .lsu_ecl_except_ale_ls1(lsu_ecl_except_ale_ls1),
    .lsu_csr_except_badv_ls1(lsu_csr_except_badv_ls1),
    .lsu_ecl_except_buserr_ls3(lsu_ecl_except_buserr_ls3),
    .lsu_ecl_except_ecc_ls3(lsu_ecl_except_ecc_ls3),
    
    // BIU interface
    .lsu_biu_rd_req_ls2(lsu_biu_rd_req_ls2),
    .lsu_biu_rd_addr_ls2(lsu_biu_rd_addr_ls2),
    .biu_lsu_rd_ack_ls2(biu_lsu_rd_ack_ls2),
    .biu_lsu_data_valid_ls3(biu_lsu_data_valid_ls3),
    .biu_lsu_data_ls3(biu_lsu_data_ls3),
    
    .lsu_biu_wr_req_ls2(lsu_biu_wr_req_ls2),
    .lsu_biu_wr_addr_ls2(lsu_biu_wr_addr_ls2),
    .lsu_biu_wr_data_ls2(lsu_biu_wr_data_ls2),
    .lsu_biu_wr_strb_ls2(lsu_biu_wr_strb_ls2),
    
    .biu_lsu_wr_ack_ls2(biu_lsu_wr_ack_ls2),
    .biu_lsu_wr_fin_ls3(biu_lsu_wr_fin_ls3)  // 信号名更新
);

// Clock generation
always #5 clk = ~clk;

// Test case parameters
reg [31:0] expected_addr;
reg [63:0] expected_data;
reg [7:0]  expected_strb;
integer test_count;
integer error_count;

integer ale_exception;

// Test summary variables
integer test_passed;
integer test_failed;

// Monitor for wr_fin signals
integer wr_fin_monitor_count;
integer wr_fin_check_error;

// Initialization
initial begin
    clk = 0;
    resetn = 0;
    
    // Initialize all inputs
    ecl_lsu_valid_e = 0;
    ecl_lsu_op_e = 0;
    ecl_lsu_base_e = 0;
    ecl_lsu_offset_e = 0;
    ecl_lsu_wdata_e = 0;
    
    biu_lsu_rd_ack_ls2 = 0;
    biu_lsu_data_valid_ls3 = 0;
    biu_lsu_data_ls3 = 0;
    
    biu_lsu_wr_ack_ls2 = 0;
    biu_lsu_wr_fin_ls3 = 0;  // 初始化
    
    test_count = 0;
    error_count = 0;
    test_passed = 0;
    test_failed = 0;
    
    ale_exception = 0;
    wr_fin_monitor_count = 0;
    wr_fin_check_error = 0;
    
    // Reset sequence
    #20 resetn = 1;
    @(posedge clk);
    
    $display("\n========================================");
    $display("Starting Store Operation Test with WSTRB-Data Relationship");
    $display("========================================\n");
    $display("Testing with updated c7blsu.v interface");
    $display("biu_lsu_wr_fin_ls3 (WR_FIN) signal test included");
    $display("lsu_ecl_wr_fin_ls3 ERROR will cause test FAIL");
    $display("========================================\n");
    
    // Test Group 1: WSTRB for All Byte Positions
    test_all_byte_positions();
    
    // Test Group 2: Data Replication Patterns
    //test_data_replication_patterns();
    
    // Test Group 3: WSTRB and Data Relationship
    test_wstrb_data_relationship_examples();
    
    // Test Group 4: Different Store Types WSTRB
    test_different_store_types();
    
    // Test Group 5: Boundary Cases and Special Addresses
    test_boundary_cases_examples();
    
    // Special test for wr_fin signal
    test_wr_fin_signal();
    
    // Test summary
    $display("\n========================================");
    $display("Test Complete");
    $display("Total Tests Executed: %0d", test_count);
    $display("Tests Passed: %0d", test_passed);
    $display("Tests Failed: %0d", test_failed);
    $display("WR_FIN Signals Monitored: %0d", wr_fin_monitor_count);
    $display("WR_FIN Check Errors: %0d", wr_fin_check_error);
    
    if (test_failed == 0 && wr_fin_check_error == 0) begin
        $display("All Tests Passed!\n");
        $display("\nPASS!\n");
        $display("\033[0;32m");
        $display("**************************************************");
        $display("*                                                *");
        $display("*      * * *       *        * * *     * * *      *");
        $display("*      *    *     * *      *         *           *");
        $display("*      * * *     *   *      * * *     * * *      *");
        $display("*      *        * * * *          *         *     *");
        $display("*      *       *       *    * * *     * * *      *");
        $display("*                                                *");
        $display("**************************************************");
        $display("\n");
        $display("\033[0m");
    end else begin
        $display("Some Tests Failed!\n");
        $display("\nFAIL!\n");
        $display("\033[0;31m");
        $display("**************************************************");
        $display("*                                                *");
        $display("*      * * *       *         ***      *          *");
        $display("*      *          * *         *       *          *");
        $display("*      * * *     *   *        *       *          *");
        $display("*      *        * * * *       *       *          *");
        $display("*      *       *       *     ***      * * *      *");
        $display("*                                                *");
        $display("**************************************************");
        $display("\n");
        $display("\033[0m");
    end
    $display("========================================\n");

    #100;
    $finish;
end

// ========================================
// Test Group 1: WSTRB for All Byte Positions
// ========================================

task test_all_byte_positions;
    begin
        $display("\n========================================");
        $display("Test Group 1: WSTRB for All Byte Positions");
        $display("========================================\n");
        
        // Test Byte Position 0
        test_byte_position_0();
        
        // Test Byte Position 1
        test_byte_position_1();
        
        // Test Byte Position 2
        test_byte_position_2();
        
        // Test Byte Position 3
        test_byte_position_3();
        
        // Test Byte Position 4
        test_byte_position_4();
        
        // Test Byte Position 5
        test_byte_position_5();
        
        // Test Byte Position 6
        test_byte_position_6();
        
        // Test Byte Position 7
        test_byte_position_7();
        
        $display("\n========================================");
        $display("Test Group 1 Completed: 8 tests");
        $display("========================================\n");
    end
endtask

task test_byte_position_0;
    reg [31:0] test_addr;
    reg [7:0]  test_data;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h1000;
        test_data = 8'hA0;
        
        $display("\n[Test %0d] Store Byte at Address 0x%h (Byte Position 0)", 
                 test_count, test_addr);
        $display("  Base: 0x1000, Offset: 0x0, Data: 0x%h", test_data);
        
        // Send store byte request
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h1000;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = {24'h0, test_data};
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        // Wait for LS2 stage
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 0)", lsu_biu_wr_addr_ls2[2:0]);
        
        // Expected wstrb for position 0
        expected_strb = 8'b00000001;
        
        local_error = verify_wstrb_and_check_data(test_data, 0);
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_byte_position_1;
    reg [31:0] test_addr;
    reg [7:0]  test_data;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h1001;
        test_data = 8'hA1;
        
        $display("\n[Test %0d] Store Byte at Address 0x%h (Byte Position 1)", 
                 test_count, test_addr);
        $display("  Base: 0x1000, Offset: 0x1, Data: 0x%h", test_data);
        
        // Send store byte request
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h1000;
        ecl_lsu_offset_e = 32'h1;
        ecl_lsu_wdata_e = {24'h0, test_data};
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        // Wait for LS2 stage
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 1)", lsu_biu_wr_addr_ls2[2:0]);
        
        // Expected wstrb for position 1
        expected_strb = 8'b00000010;
        
        local_error = verify_wstrb_and_check_data(test_data, 1);
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_byte_position_2;
    reg [31:0] test_addr;
    reg [7:0]  test_data;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h1002;
        test_data = 8'hA2;
        
        $display("\n[Test %0d] Store Byte at Address 0x%h (Byte Position 2)", 
                 test_count, test_addr);
        $display("  Base: 0x1000, Offset: 0x2, Data: 0x%h", test_data);
        
        // Send store byte request
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h1000;
        ecl_lsu_offset_e = 32'h2;
        ecl_lsu_wdata_e = {24'h0, test_data};
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        // Wait for LS2 stage
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 2)", lsu_biu_wr_addr_ls2[2:0]);
        
        // Expected wstrb for position 2
        expected_strb = 8'b00000100;
        
        local_error = verify_wstrb_and_check_data(test_data, 2);
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_byte_position_3;
    reg [31:0] test_addr;
    reg [7:0]  test_data;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h1003;
        test_data = 8'hA3;
        
        $display("\n[Test %0d] Store Byte at Address 0x%h (Byte Position 3)", 
                 test_count, test_addr);
        $display("  Base: 0x1000, Offset: 0x3, Data: 0x%h", test_data);
        
        // Send store byte request
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h1000;
        ecl_lsu_offset_e = 32'h3;
        ecl_lsu_wdata_e = {24'h0, test_data};
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        // Wait for LS2 stage
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 3)", lsu_biu_wr_addr_ls2[2:0]);
        
        // Expected wstrb for position 3
        expected_strb = 8'b00001000;
        
        local_error = verify_wstrb_and_check_data(test_data, 3);
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_byte_position_4;
    reg [31:0] test_addr;
    reg [7:0]  test_data;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h1004;
        test_data = 8'hA4;
        
        $display("\n[Test %0d] Store Byte at Address 0x%h (Byte Position 4)", 
                 test_count, test_addr);
        $display("  Base: 0x1000, Offset: 0x4, Data: 0x%h", test_data);
        
        // Send store byte request
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h1000;
        ecl_lsu_offset_e = 32'h4;
        ecl_lsu_wdata_e = {24'h0, test_data};
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        // Wait for LS2 stage
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 4)", lsu_biu_wr_addr_ls2[2:0]);
        
        // Expected wstrb for position 4
        expected_strb = 8'b00010000;
        
        local_error = verify_wstrb_and_check_data(test_data, 4);
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_byte_position_5;
    reg [31:0] test_addr;
    reg [7:0]  test_data;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h1005;
        test_data = 8'hA5;
        
        $display("\n[Test %0d] Store Byte at Address 0x%h (Byte Position 5)", 
                 test_count, test_addr);
        $display("  Base: 0x1000, Offset: 0x5, Data: 0x%h", test_data);
        
        // Send store byte request
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h1000;
        ecl_lsu_offset_e = 32'h5;
        ecl_lsu_wdata_e = {24'h0, test_data};
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        // Wait for LS2 stage
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 5)", lsu_biu_wr_addr_ls2[2:0]);
        
        // Expected wstrb for position 5
        expected_strb = 8'b00100000;
        
        local_error = verify_wstrb_and_check_data(test_data, 5);
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_byte_position_6;
    reg [31:0] test_addr;
    reg [7:0]  test_data;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h1006;
        test_data = 8'hA6;
        
        $display("\n[Test %0d] Store Byte at Address 0x%h (Byte Position 6)", 
                 test_count, test_addr);
        $display("  Base: 0x1000, Offset: 0x6, Data: 0x%h", test_data);
        
        // Send store byte request
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h1000;
        ecl_lsu_offset_e = 32'h6;
        ecl_lsu_wdata_e = {24'h0, test_data};
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        // Wait for LS2 stage
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 6)", lsu_biu_wr_addr_ls2[2:0]);
        
        // Expected wstrb for position 6
        expected_strb = 8'b01000000;
        
        local_error = verify_wstrb_and_check_data(test_data, 6);
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_byte_position_7;
    reg [31:0] test_addr;
    reg [7:0]  test_data;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h1007;
        test_data = 8'hA7;
        
        $display("\n[Test %0d] Store Byte at Address 0x%h (Byte Position 7)", 
                 test_count, test_addr);
        $display("  Base: 0x1000, Offset: 0x7, Data: 0x%h", test_data);
        
        // Send store byte request
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h1000;
        ecl_lsu_offset_e = 32'h7;
        ecl_lsu_wdata_e = {24'h0, test_data};
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        // Wait for LS2 stage
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 7)", lsu_biu_wr_addr_ls2[2:0]);
        
        // Expected wstrb for position 7
        expected_strb = 8'b10000000;
        
        local_error = verify_wstrb_and_check_data(test_data, 7);
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

// ========================================
// Test Group 3: WSTRB and Data Relationship
// ========================================

task test_wstrb_data_relationship_examples;
    begin
        $display("\n========================================");
        $display("Test Group 3: WSTRB and Data Relationship");
        $display("========================================\n");
        
        // Example 1: SB at unaligned address
        test_sb_unaligned_example();
        
        // Example 2: SH at unaligned address
        test_sh_unaligned_example();
        
        // Example 3: SW at unaligned address
        test_sw_unaligned_example();
        
        $display("\n========================================");
        $display("Test Group 3 Completed: 3 tests");
        $display("========================================\n");
    end
endtask

task test_sb_unaligned_example;
    reg [31:0] test_addr;
    reg [31:0] test_wdata;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h3003;
        test_wdata = 32'h00000077;
        
        $display("\n[Test %0d] Store Byte (SB) at Unaligned Address 0x%h (Offset 3)", 
                 test_count, test_addr);
        $display("  Data: 0x%h", test_wdata);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h3000;
        ecl_lsu_offset_e = 32'h3;
        ecl_lsu_wdata_e = test_wdata;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 3)", lsu_biu_wr_addr_ls2[2:0]);
        
        expected_strb = 8'b00001000;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_sh_unaligned_example;
    reg [31:0] test_addr;
    reg [31:0] test_wdata;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h3002;
        test_wdata = 32'h00000077;
        
        $display("\n[Test %0d] Store Halfword (SH) at Unaligned Address 0x%h (Offset 2)", 
                 test_count, test_addr);
        $display("  Data: 0x%h", test_wdata);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_H;
        ecl_lsu_base_e = 32'h3000;
        ecl_lsu_offset_e = 32'h2;
        ecl_lsu_wdata_e = test_wdata;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 2-3)", lsu_biu_wr_addr_ls2[2:0]);
        
        expected_strb = 8'b00001100;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_sw_unaligned_example;
    reg [31:0] test_addr;
    reg [31:0] test_wdata;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h3001;
        test_wdata = 32'h00000077;
        
        $display("\n[Test %0d] Store Word (SW) at Unaligned Address 0x%h (Offset 1)", 
                 test_count, test_addr);
        $display("  Data: 0x%h", test_wdata);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_W;
        ecl_lsu_base_e = 32'h3000;
        ecl_lsu_offset_e = 32'h1;
        ecl_lsu_wdata_e = test_wdata;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Print address information
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 1-3)", lsu_biu_wr_addr_ls2[2:0]);
        
        expected_strb = 8'b00001110;
        
        if (ale_exception !== 1) begin
            $display("  ERROR: ALE exception should be triggered!");
            local_error = 1;
        end    
        
        ale_exception = 0;
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

// ========================================
// Test Group 4: Different Store Types WSTRB
// ========================================

task test_different_store_types;
    begin
        $display("\n========================================");
        $display("Test Group 4: Different Store Types WSTRB");
        $display("========================================\n");
        
        // Test SB at different alignments
        test_sb_aligned_0();
        test_sb_aligned_4();
        
        // Test SH at different alignments
        test_sh_aligned_0();
        test_sh_aligned_2();
        
        // Test SW at different alignments
        test_sw_aligned_0();
        test_sw_aligned_4();
        
        $display("\n========================================");
        $display("Test Group 4 Completed: 7 tests");
        $display("========================================\n");
    end
endtask

task test_sb_aligned_0;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h4000;
        
        $display("\n[Test %0d] Store Byte (SB) Aligned at Address 0x%h", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h4000;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = 32'h11223344;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 0)", lsu_biu_wr_addr_ls2[2:0]);
        
        expected_strb = 8'b00000001;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_sb_aligned_4;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h4004;
        
        $display("\n[Test %0d] Store Byte (SB) at Address 0x%h (Upper 32-bit region)", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h4000;
        ecl_lsu_offset_e = 32'h4;
        ecl_lsu_wdata_e = 32'h11223344;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 4)", lsu_biu_wr_addr_ls2[2:0]);
        $display("  Note: Crossing to upper 32-bit region");
        
        expected_strb = 8'b00010000;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_sh_aligned_0;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h4100;
        
        $display("\n[Test %0d] Store Halfword (SH) Aligned at Address 0x%h", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_H;
        ecl_lsu_base_e = 32'h4100;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = 32'h11223344;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 0-1)", lsu_biu_wr_addr_ls2[2:0]);
        
        expected_strb = 8'b00000011;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_sh_aligned_2;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h4102;
        
        $display("\n[Test %0d] Store Halfword (SH) at Address 0x%h (Unaligned)", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_H;
        ecl_lsu_base_e = 32'h4100;
        ecl_lsu_offset_e = 32'h2;
        ecl_lsu_wdata_e = 32'h11223344;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 2-3)", lsu_biu_wr_addr_ls2[2:0]);
        
        expected_strb = 8'b00001100;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_sw_aligned_0;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h4200;
        
        $display("\n[Test %0d] Store Word (SW) Aligned at Address 0x%h", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_W;
        ecl_lsu_base_e = 32'h4200;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = 32'h11223344;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 0-3)", lsu_biu_wr_addr_ls2[2:0]);
        
        expected_strb = 8'b00001111;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_sw_aligned_4;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h4204;
        
        $display("\n[Test %0d] Store Word (SW) at Address 0x%h (Unaligned)", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_W;
        ecl_lsu_base_e = 32'h4200;
        ecl_lsu_offset_e = 32'h4;
        ecl_lsu_wdata_e = 32'h11223344;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 4-7)", lsu_biu_wr_addr_ls2[2:0]);
        
        expected_strb = 8'b11110000;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

// ========================================
// Test Group 5: Boundary Cases and Special Addresses
// ========================================

task test_boundary_cases_examples;
    begin
        $display("\n========================================");
        $display("Test Group 5: Boundary Cases and Special Addresses");
        $display("========================================\n");
        
        // Test 1: 32-bit boundary
        test_32bit_boundary();
        
        // Test 2: Crossing 32-bit boundary
        test_cross_32bit_boundary();
        
        // Test 3: High address test
        test_high_address();
        
        $display("\n========================================");
        $display("Test Group 5 Completed: 3 tests");
        $display("========================================\n");
    end
endtask

task test_32bit_boundary;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h5003;
        
        $display("\n[Test %0d] Store Byte at 32-bit Boundary Address 0x%h", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h5000;
        ecl_lsu_offset_e = 32'h3;
        ecl_lsu_wdata_e = 32'h000000AA;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 3)", lsu_biu_wr_addr_ls2[2:0]);
        $display("  This is the last byte of lower 32-bit region");
        
        expected_strb = 8'b00001000;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_cross_32bit_boundary;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'h5004;
        
        $display("\n[Test %0d] Store Byte crossing 32-bit Boundary at Address 0x%h", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h5000;
        ecl_lsu_offset_e = 32'h4;
        ecl_lsu_wdata_e = 32'h000000BB;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 4)", lsu_biu_wr_addr_ls2[2:0]);
        $display("  This is the first byte of upper 32-bit region");
        
        expected_strb = 8'b00010000;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

task test_high_address;
    reg [31:0] test_addr;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        test_addr = 32'hFFFF_FFFC;
        
        $display("\n[Test %0d] Store Word at High Address 0x%h", 
                 test_count, test_addr);
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_W;
        ecl_lsu_base_e = 32'hFFFF_FFFC;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = 32'hDEADBEEF;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        $display("  Generated Address (LS2): 0x%h", lsu_biu_wr_addr_ls2);
        $display("  Address[2:0] = 3'b%b (Position 0-3)", lsu_biu_wr_addr_ls2[2:0]);
        $display("  Testing near maximum 32-bit address");
        
        expected_strb = 8'b11110000;
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end
        
        print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
        send_biu_response_with_wr_fin();
        
        // Display test result
        if (local_error == 0 && wr_fin_check_error == 0) begin
            $display("  [Test %0d] PASS", test_count);
            test_passed = test_passed + 1;
        end else begin
            $display("  [Test %0d] FAIL", test_count);
            test_failed = test_failed + 1;
        end
    end
endtask

// ========================================
// Special Test for WR_FIN signal
// ========================================

task test_wr_fin_signal;
    integer local_error;
    
    begin
        local_error = 0;
        test_count = test_count + 1;
        
        $display("\n[Test %0d] Testing WR_FIN signal propagation", test_count);
        $display("  Testing lsu_ecl_wr_fin_ls3 output from biu_lsu_wr_fin_ls3");
        
        // Simple store operation to trigger wr_fin
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h6000;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = 32'h000000FF;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Send BIU response with wr_fin
        @(posedge clk);
        biu_lsu_wr_ack_ls2 = 1;
        @(posedge clk);
        biu_lsu_wr_ack_ls2 = 0;
        
        // Check if lsu_ecl_wr_fin_ls3 is low before wr_fin
        if (lsu_ecl_wr_fin_ls3 !== 1'b0) begin
            $display("  ERROR: lsu_ecl_wr_fin_ls3 should be 0 before biu_lsu_wr_fin_ls3");
            local_error = 1;
        end
        
        // Trigger wr_fin
        @(posedge clk);
        biu_lsu_wr_fin_ls3 = 1;
        @(posedge clk);
        
        // Check if lsu_ecl_wr_fin_ls3 is high when wr_fin is asserted
        if (lsu_ecl_wr_fin_ls3 !== 1'b1) begin
            $display("  ERROR: lsu_ecl_wr_fin_ls3 should be 1 when biu_lsu_wr_fin_ls3=1");
            $display("    Expected: 1, Actual: %b", lsu_ecl_wr_fin_ls3);
            local_error = 1;
        end
        
        biu_lsu_wr_fin_ls3 = 0;
        @(posedge clk);
        
        // Check if lsu_ecl_wr_fin_ls3 goes back to low
        if (lsu_ecl_wr_fin_ls3 !== 1'b0) begin
            $display("  ERROR: lsu_ecl_wr_fin_ls3 should return to 0 after biu_lsu_wr_fin_ls3=0");
            local_error = 1;
        end
        
        if (local_error == 0) begin
            $display("  WR_FIN signal test PASS");
            $display("  lsu_ecl_wr_fin_ls3 correctly follows biu_lsu_wr_fin_ls3");
            test_passed = test_passed + 1;
        end else begin
            $display("  WR_FIN signal test FAIL");
            test_failed = test_failed + 1;
        end
    end
endtask

// ========================================
// Helper Tasks
// ========================================

function integer verify_wstrb_and_check_data;
    input [7:0]  test_data;
    input integer position;
    
    integer local_error;
    begin
        local_error = 0;
        
        $display("  Expected wstrb: 0b%b (0x%h)", expected_strb, expected_strb);
        $display("  Actual wstrb:   0b%b (0x%h)", lsu_biu_wr_strb_ls2, lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            local_error = 1;
        end else begin
            $display("  WSTRB correct!");
        end
        
        // Check data at the specific position
        case (position)
            0: if (lsu_biu_wr_data_ls2[7:0] !== test_data) begin
                $display("  ERROR: Data at position 0 incorrect!");
                local_error = 1;
            end
            1: if (lsu_biu_wr_data_ls2[15:8] !== test_data) begin
                $display("  ERROR: Data at position 1 incorrect!");
                local_error = 1;
            end
            2: if (lsu_biu_wr_data_ls2[23:16] !== test_data) begin
                $display("  ERROR: Data at position 2 incorrect!");
                local_error = 1;
            end
            3: if (lsu_biu_wr_data_ls2[31:24] !== test_data) begin
                $display("  ERROR: Data at position 3 incorrect!");
                local_error = 1;
            end
            4: if (lsu_biu_wr_data_ls2[39:32] !== test_data) begin
                $display("  ERROR: Data at position 4 incorrect!");
                local_error = 1;
            end
            5: if (lsu_biu_wr_data_ls2[47:40] !== test_data) begin
                $display("  ERROR: Data at position 5 incorrect!");
                local_error = 1;
            end
            6: if (lsu_biu_wr_data_ls2[55:48] !== test_data) begin
                $display("  ERROR: Data at position 6 incorrect!");
                local_error = 1;
            end
            7: if (lsu_biu_wr_data_ls2[63:56] !== test_data) begin
                $display("  ERROR: Data at position 7 incorrect!");
                local_error = 1;
            end
        endcase
        
        verify_wstrb_and_check_data = local_error;
    end
endfunction

task send_biu_response_with_wr_fin;
    begin
        @(posedge clk);
        biu_lsu_wr_ack_ls2 = 1;
        @(posedge clk);
        biu_lsu_wr_ack_ls2 = 0;
        
        // Wait a few cycles for write completion
        repeat(2) @(posedge clk);
        
        // Assert wr_fin signal
        @(posedge clk);
        biu_lsu_wr_fin_ls3 = 1;
        wr_fin_monitor_count = wr_fin_monitor_count + 1;
        $display("  [WR_FIN] biu_lsu_wr_fin_ls3 asserted at time %0t", $time);
       
        // 等待一个时钟周期，让信号传播	
        @(posedge clk);
        // Check if lsu_ecl_wr_fin_ls3 follows
        if (lsu_ecl_wr_fin_ls3 !== 1'b1) begin
            $display("  [WR_FIN ERROR] lsu_ecl_wr_fin_ls3 not asserted!");
            $display("    Expected: 1, Actual: %b", lsu_ecl_wr_fin_ls3);
            wr_fin_check_error = wr_fin_check_error + 1;
            // lsu_ecl_wr_fin_ls3 ERROR导致测试失败
            test_failed = test_failed + 1;
        end else begin
            $display("  [WR_FIN OK] lsu_ecl_wr_fin_ls3 correctly asserted");
        end
        
        @(posedge clk);
        biu_lsu_wr_fin_ls3 = 0;
        
        // Check if lsu_ecl_wr_fin_ls3 deasserts
        @(posedge clk);
        if (lsu_ecl_wr_fin_ls3 !== 1'b0) begin
            $display("  [WR_FIN ERROR] lsu_ecl_wr_fin_ls3 not deasserted!");
            $display("    Expected: 0, Actual: %b", lsu_ecl_wr_fin_ls3);
            wr_fin_check_error = wr_fin_check_error + 1;
            // lsu_ecl_wr_fin_ls3 ERROR导致测试失败
            test_failed = test_failed + 1;
        end else begin
            $display("  [WR_FIN OK] lsu_ecl_wr_fin_ls3 correctly deasserted");
        end
        
        repeat(2) @(posedge clk);
    end
endtask

task verify_wstrb_data_combination;
    input [7:0] wstrb;
    input [63:0] data;
    
    reg [63:0] combined_result;
    integer j;
    
    begin
        $display("  Verifying wstrb-data combination:");
        
        // Simulate what BIU does: for each byte, if wstrb=1, use data; if wstrb=0, ignore
        combined_result = 64'h0;
        for (j = 0; j < 8; j = j + 1) begin
            if (wstrb[j]) begin
                combined_result[j*8+:8] = data[j*8+:8];
            end
        end
        
        $display("    Combined result (wstrb ORed with data): 0x%h", combined_result);
        $display("    Note: BIU will write only bytes where wstrb=1");
    end
endtask

task print_byte_analysis;
    input [7:0] wstrb;
    input [63:0] data;
    
    integer k;
    
    begin
        $display("  Byte-by-byte analysis:");
        for (k = 0; k < 8; k = k + 1) begin
            $display("    Byte %0d: wstrb=%b, data=0x%h, %s", 
                     k, wstrb[k], data[k*8+:8],
                     wstrb[k] ? "ENABLED (will be written)" : "DISABLED (ignored)");
        end
    end
endtask

// Monitor outputs
always @(posedge clk) begin
    // Monitor exception signals
    if (lsu_ecl_except_ale_ls1) begin
        $display("[%0t] ALE Exception at Address: 0x%h", $time, lsu_csr_except_badv_ls1);
        ale_exception = 1;
    end
    
    if (lsu_ecl_except_buserr_ls3) begin
        $display("[%0t] Bus Error Exception", $time);
    end
    
    if (lsu_ecl_except_ecc_ls3) begin
        $display("[%0t] ECC Error Exception", $time);
    end
    
    // Monitor load data return (if any)
    if (lsu_ecl_data_valid_ls3) begin
        $display("[%0t] Load Data Return: data=0x%h", $time, lsu_ecl_data_ls3);
    end
    
    // Monitor wr_fin signal - 检查错误
    if (lsu_ecl_wr_fin_ls3 && !biu_lsu_wr_fin_ls3) begin
        $display("[%0t] WR_FIN ERROR: lsu_ecl_wr_fin_ls3=1 but biu_lsu_wr_fin_ls3=0", $time);
        wr_fin_check_error = wr_fin_check_error + 1;
    end
    
    if (biu_lsu_wr_fin_ls3 && !lsu_ecl_wr_fin_ls3) begin
        $display("[%0t] WR_FIN ERROR: biu_lsu_wr_fin_ls3=1 but lsu_ecl_wr_fin_ls3=0", $time);
        wr_fin_check_error = wr_fin_check_error + 1;
    end
end

endmodule
