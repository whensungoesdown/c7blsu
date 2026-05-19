`timescale 1ns/1ns

`include "c7blsu_defs.v"

module top_tb();

reg clk;
reg resetn;

// ECL Interface
reg ecl_lsu_valid_e;
reg [6:0] ecl_lsu_op_e;
reg [31:0] ecl_lsu_base_e;
reg [31:0] ecl_lsu_offset_e;
reg [31:0] ecl_lsu_wdata_e;

// LSU Outputs
wire lsu_ecl_data_valid_ls3;
wire [31:0] lsu_ecl_data_ls3;
wire lsu_ecl_wr_fin_ls3;
wire lsu_ecl_except_ale_ls1;
wire [31:0] lsu_ecl_except_badv_ls1;
wire lsu_ecl_except_buserr_ls3;
wire lsu_ecl_except_ecc_ls3;
wire [31:0] lsu_ecl_except_buserr_badv_ls3;

// BIU Interface
wire lsu_biu_rd_req_ls2;
wire [31:0] lsu_biu_rd_addr_ls2;
reg biu_lsu_rd_ack_ls2;
reg biu_lsu_data_valid_ls3;
reg [63:0] biu_lsu_data_ls3;
reg biu_lsu_fault_ls3;
reg [1:0] biu_lsu_fault_code_ls3;

wire lsu_biu_wr_req_ls2;
wire [31:0] lsu_biu_wr_addr_ls2;
wire [63:0] lsu_biu_wr_data_ls2;
wire [7:0] lsu_biu_wr_strb_ls2;
reg biu_lsu_wr_ack_ls2;
reg biu_lsu_wr_fin_ls3;
reg biu_lsu_wr_fault_ls3;
reg [1:0] biu_lsu_wr_fault_code_ls3;

// Test variables
reg [31:0] expected_data;
reg [31:0] expected_addr;
integer test_num;
integer error_count;

// Clock generation
always #5 clk = ~clk;

// Instantiate DUT
c7blsu dut (
    .clk(clk),
    .resetn(resetn),
    
    // ECL Interface
    .ecl_lsu_valid_e(ecl_lsu_valid_e),
    .ecl_lsu_op_e(ecl_lsu_op_e),
    .ecl_lsu_base_e(ecl_lsu_base_e),
    .ecl_lsu_offset_e(ecl_lsu_offset_e),
    .ecl_lsu_wdata_e(ecl_lsu_wdata_e),
    
    .lsu_ecl_data_valid_ls3(lsu_ecl_data_valid_ls3),
    .lsu_ecl_data_ls3(lsu_ecl_data_ls3),
    .lsu_ecl_wr_fin_ls3(lsu_ecl_wr_fin_ls3),
    .lsu_ecl_except_ale_ls1(lsu_ecl_except_ale_ls1),
    .lsu_ecl_except_ale_badv_ls1(lsu_ecl_except_badv_ls1),
    .lsu_ecl_except_buserr_ls3(lsu_ecl_except_buserr_ls3),
    .lsu_ecl_except_ecc_ls3(lsu_ecl_except_ecc_ls3),
    .lsu_ecl_except_buserr_badv_ls3(lsu_ecl_except_buserr_badv_ls3),
    
    // BIU Interface
    .lsu_biu_rd_req_ls2(lsu_biu_rd_req_ls2),
    .lsu_biu_rd_addr_ls2(lsu_biu_rd_addr_ls2),
    .biu_lsu_rd_ack_ls2(biu_lsu_rd_ack_ls2),
    .biu_lsu_data_valid_ls3(biu_lsu_data_valid_ls3),
    .biu_lsu_data_ls3(biu_lsu_data_ls3),
    .biu_lsu_fault_ls3(biu_lsu_fault_ls3),
    .biu_lsu_fault_code_ls3(biu_lsu_fault_code_ls3),
    
    .lsu_biu_wr_req_ls2(lsu_biu_wr_req_ls2),
    .lsu_biu_wr_addr_ls2(lsu_biu_wr_addr_ls2),
    .lsu_biu_wr_data_ls2(lsu_biu_wr_data_ls2),
    .lsu_biu_wr_strb_ls2(lsu_biu_wr_strb_ls2),
    .biu_lsu_wr_ack_ls2(biu_lsu_wr_ack_ls2),
    .biu_lsu_wr_fin_ls3(biu_lsu_wr_fin_ls3),
    .biu_lsu_wr_fault_ls3(biu_lsu_wr_fault_ls3),
    .biu_lsu_wr_fault_code_ls3(biu_lsu_wr_fault_code_ls3)
);

// Initialize signals
task initialize;
begin
    clk = 0;
    resetn = 0;
    ecl_lsu_valid_e = 0;
    ecl_lsu_op_e = 0;
    ecl_lsu_base_e = 0;
    ecl_lsu_offset_e = 0;
    ecl_lsu_wdata_e = 0;
    biu_lsu_rd_ack_ls2 = 0;
    biu_lsu_data_valid_ls3 = 0;
    biu_lsu_data_ls3 = 0;
    biu_lsu_fault_ls3 = 0;
    biu_lsu_fault_code_ls3 = 0;
    biu_lsu_wr_ack_ls2 = 0;
    biu_lsu_wr_fin_ls3 = 0;
    biu_lsu_wr_fault_ls3 = 0;
    biu_lsu_wr_fault_code_ls3 = 0;
    expected_addr = 0;
    expected_data = 0;
    test_num = 0;
    error_count = 0;
    
    #20;
    resetn = 1;
    #20;
end
endtask

// Check BIU request address (now expects the exact effective address)
task check_biu_request;
input [31:0] expected_address;
begin
    // Wait for BIU request to be asserted
    @(posedge clk);
    while (!lsu_biu_rd_req_ls2) @(posedge clk);
    
    $display("Test %0d: BIU request detected at address 0x%h", test_num, lsu_biu_rd_addr_ls2);
    
    // Check that the address is correct
    if (lsu_biu_rd_addr_ls2 === expected_address) begin
        $display("Test %0d: BIU request address correct", test_num);
    end else begin
        $display("Test %0d ERROR: BIU request address incorrect. Expected=0x%h, Actual=0x%h", 
                 test_num, expected_address, lsu_biu_rd_addr_ls2);
        error_count = error_count + 1;
    end
end
endtask

// Acknowledge BIU request
task ack_biu_request;
begin
    // Acknowledge request in the next cycle
    @(posedge clk);
    biu_lsu_rd_ack_ls2 = 1;
    $display("Test %0d: BIU request acknowledged", test_num);
    
    // Hold acknowledge for one cycle
    @(posedge clk);
    biu_lsu_rd_ack_ls2 = 0;
end
endtask

// Send BIU response with proper timing
task send_biu_response;
input [63:0] data;
begin
    // Wait for 1 cycle after acknowledgment (LS3 stage)
    // Timing: E -> LS1 -> LS2 -> LS3
    // Request in LS2, data response in LS3
    @(posedge clk);
    
    // Send response in LS3 stage
    biu_lsu_data_valid_ls3 = 1;
    biu_lsu_data_ls3 = data;
    $display("Test %0d: BIU data response sent: 0x%h", test_num, data);
    
    @(posedge clk);
    biu_lsu_data_valid_ls3 = 0;
    biu_lsu_data_ls3 = 64'h0;
end
endtask

// Check LSU data output
task check_lsu_output;
input [31:0] expected;
begin
    // Check if data is available in the same cycle as biu_lsu_data_valid_ls3
    // This depends on the design - some designs may output in same cycle
    if (lsu_ecl_data_valid_ls3) begin
        $display("Test %0d: LSU data output valid in same cycle as BIU response", test_num);
        check_result(expected, lsu_ecl_data_ls3);
    end else begin
        // If not available in same cycle, wait one more cycle
        $display("Test %0d: Waiting one more cycle for LSU data output", test_num);
        @(posedge clk);
        if (lsu_ecl_data_valid_ls3) begin
            check_result(expected, lsu_ecl_data_ls3);
        end else begin
            $display("Test %0d ERROR: lsu_ecl_data_valid_ls3 not asserted after BIU response", test_num);
            error_count = error_count + 1;
        end
    end
    
    // Cleanup
    @(posedge clk); // Wait one more cycle for cleanup
end
endtask

// Combined task: send response and check (without checking/acking request)
task send_response_and_check;
input [63:0] data;
input [31:0] expected_data_val;
begin
    // Step 1: Send BIU response
    send_biu_response(data);
    
    // Step 2: Check LSU output
    check_lsu_output(expected_data_val);
end
endtask

// Check result
task check_result;
input [31:0] expected;
input [31:0] actual;
begin
    if (expected === actual) begin
        $display("Test %0d PASSED: Expected=0x%h, Actual=0x%h", 
                 test_num, expected, actual);
    end else begin
        $display("Test %0d FAILED: Expected=0x%h, Actual=0x%h", 
                 test_num, expected, actual);
        error_count = error_count + 1;
    end
end
endtask

// ========================
// Test cases
// ========================

// Test 1: LD.W (aligned) - address 0x1000
task test_ld_w_aligned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.W (aligned) - address 0x1000 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_W;
    ecl_lsu_base_e = 32'h1000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Expected address = 0x1000 (aligned)
    check_biu_request(32'h1000);
    ack_biu_request();
    send_response_and_check(64'hA5A5_A5A5_1234_5678, 32'h12345678);
end
endtask

// Test 2: LD.W (unaligned) - address 0x1001 (should trigger ALE)
task test_ld_w_unaligned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.W (unaligned) - address 0x1001 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_W;
    ecl_lsu_base_e = 32'h1000;
    ecl_lsu_offset_e = 32'h1;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Check ALE in LS1 stage
    if (lsu_ecl_except_ale_ls1) begin
        $display("Test %0d PASSED: ALE exception triggered", test_num);
        $display("Bad address: 0x%h", lsu_ecl_except_badv_ls1);
        if (lsu_ecl_except_badv_ls1 === 32'h1001) begin
            $display("Test %0d: Bad address correct", test_num);
        end else begin
            $display("Test %0d ERROR: Bad address incorrect. Expected=0x1001, Actual=0x%h", 
                     test_num, lsu_ecl_except_badv_ls1);
            error_count = error_count + 1;
        end
    end else begin
        $display("Test %0d FAILED: No ALE exception", test_num);
        error_count = error_count + 1;
    end
    
    @(posedge clk);
    if (lsu_biu_rd_req_ls2) begin
        $display("Test %0d ERROR: BIU request issued for unaligned access", test_num);
        error_count = error_count + 1;
    end
    
    repeat(3) @(posedge clk);
end
endtask

// Test 3: LD.B signed - address 0x2002 (byte 2)
task test_ld_b_signed;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2002 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h2;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h2002);
    ack_biu_request();
    send_response_and_check(64'hFF00_FF00_FF80_FF00, 32'hFFFFFF80);
end
endtask

// Test 4: LD.B signed - address 0x2000 (byte 0)
task test_ld_b_signed_byte0;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2000 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h2000);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_0000_00FF, 32'hFFFFFFFF);
end
endtask

// Test 5: LD.B signed - address 0x2001 (byte 1)
task test_ld_b_signed_byte1;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2001 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h1;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h2001);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_0000_7F00, 32'h0000007F);
end
endtask

// Test 6: LD.B signed - address 0x2003 (byte 3)
task test_ld_b_signed_byte3;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2003 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h3;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h2003);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_8000_0000, 32'hFFFFFF80);
end
endtask

// Test 7: LD.B signed - address 0x2004 (high 32-bit byte 0)
task test_ld_b_signed_high32;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2004 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h4;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h2004);
    ack_biu_request();
    send_response_and_check(64'h0000_0090_0000_0000, 32'hFFFFFF90);
end
endtask

// Test 8: LD.BU unsigned - address 0x3001 (byte 1)
task test_ld_bu_unsigned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3001 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h1;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h3001);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_0000_0080, 32'h00000000);
end
endtask

// Test 9: LD.BU unsigned - address 0x3000 (byte 0)
task test_ld_bu_unsigned_byte0;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3000 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h3000);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_0000_0080, 32'h00000080);
end
endtask

// Test 10: LD.BU unsigned - address 0x3002 (byte 2)
task test_ld_bu_unsigned_byte2;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3002 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h2;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h3002);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_00FF_0000, 32'h000000FF);
end
endtask

// Test 11: LD.BU unsigned - address 0x3003 (byte 3)
task test_ld_bu_unsigned_byte3;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3003 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h3;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h3003);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_5500_0000, 32'h00000055);
end
endtask

// Test 12: LD.BU unsigned - address 0x3004 (high 32-bit byte 0)
task test_ld_bu_unsigned_high32;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3004 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h4;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h3004);
    ack_biu_request();
    send_response_and_check(64'h0000_00AA_0000_0000, 32'h000000AA);
end
endtask

// Test 13: LD.H signed - address 0x4002 (halfword at bytes 2-3)
task test_ld_h_signed;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4002 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h2;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h4002);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_ABCD_8000, 32'hFFFFABCD);
end
endtask

// Test 14: LD.H signed - address 0x4000 (halfword at bytes 0-1)
task test_ld_h_signed_half0;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4000 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h4000);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_ABCD_8000, 32'hFFFF8000);
end
endtask

// Test 15: LD.H signed - address 0x4100 (positive value)
task test_ld_h_signed_positive;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4100 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4100;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h4100);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_0000_7FFF, 32'h00007FFF);
end
endtask

// Test 16: LD.H signed - address 0x4004 (high 32-bit halfword 0)
task test_ld_h_signed_high32;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4004 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h4;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h4004);
    ack_biu_request();
    send_response_and_check(64'h1234_5678_0000_0000, 32'h00005678);
end
endtask

// Test 17: LD.H signed - address 0x4006 (high 32-bit halfword 1, negative)
task test_ld_h_signed_high32_neg;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4006 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h6;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h4006);
    ack_biu_request();
    send_response_and_check(64'h8000_1234_0000_0000, 32'hFFFF8000);
end
endtask

// Test 18: LD.H signed - address 0x4006 (positive value)
task test_ld_h_signed_high32_bytes67;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4006 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h6;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h4006);
    ack_biu_request();
    send_response_and_check(64'h1234_ABCD_0000_0000, 32'h00001234);
end
endtask

// Test 19: LD.H signed - address 0x4000 (little-endian check)
task test_ld_h_signed_understanding;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4000 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h4000);
    ack_biu_request();
    send_response_and_check(64'h1234_5678_ABCD_EF01, 32'hFFFFEF01);
end
endtask

// Test 20: LD.H signed - address 0x4002 (little-endian check)
task test_ld_h_signed_address2;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4002 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h2;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h4002);
    ack_biu_request();
    send_response_and_check(64'h1234_5678_ABCD_EF01, 32'hFFFFABCD);
end
endtask

// Test 21: LD.HU unsigned - address 0x5002
task test_ld_hu_unsigned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5002 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5000;
    ecl_lsu_offset_e = 32'h2;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h5002);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_0000_8000, 32'h00000000);
end
endtask

// Test 22: LD.HU unsigned - address 0x5000
task test_ld_hu_unsigned_half0;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5000 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h5000);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_0000_8000, 32'h00008000);
end
endtask

// Test 23: LD.HU unsigned - address 0x5102
task test_ld_hu_unsigned_nonzero;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5102 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5100;
    ecl_lsu_offset_e = 32'h2;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h5102);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_1234_5678, 32'h00001234);
end
endtask

// Test 24: LD.HU unsigned - address 0x5204 (high 32-bit halfword 0)
task test_ld_hu_unsigned_high32;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5204 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5200;
    ecl_lsu_offset_e = 32'h4;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h5204);
    ack_biu_request();
    send_response_and_check(64'hABCD_1234_0000_0000, 32'h00001234);
end
endtask

// Test 25: LD.HU unsigned - address 0x5206 (high 32-bit halfword 1)
task test_ld_hu_unsigned_high32_half1;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5206 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5200;
    ecl_lsu_offset_e = 32'h6;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h5206);
    ack_biu_request();
    send_response_and_check(64'hABCD_1234_0000_0000, 32'h0000ABCD);
end
endtask

// Test 26: LD.HU unsigned - address 0x5300 (max value)
task test_ld_hu_unsigned_max;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5300 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5300;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h5300);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_0000_FFFF, 32'h0000FFFF);
end
endtask

// Test 27: LD.WU unsigned - address 0x8000
task test_ld_wu_unsigned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.WU (unsigned) - address 0x8000 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_WU;
    ecl_lsu_base_e = 32'h8000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h8000);
    ack_biu_request();
    send_response_and_check(64'h0000_0000_8000_0000, 32'h80000000);
end
endtask

// Test 28: LD.W with offset 0x4 - address 0x9004
task test_ld_w_offset4;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.W with offset 0x4 - address 0x9004 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_W;
    ecl_lsu_base_e = 32'h9000;
    ecl_lsu_offset_e = 32'h4;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    check_biu_request(32'h9004);
    ack_biu_request();
    send_response_and_check(64'hAAAABBBBCCCCDDDD, 32'hAAAABBBB);
end
endtask

// Test 29: LD.H unaligned (should trigger ALE)
task test_ld_h_unaligned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (unaligned) - address 0xC001 ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'hC000;
    ecl_lsu_offset_e = 32'h1;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    if (lsu_ecl_except_ale_ls1) begin
        $display("Test %0d PASSED: ALE exception triggered for unaligned halfword", test_num);
        $display("Bad address: 0x%h", lsu_ecl_except_badv_ls1);
        if (lsu_ecl_except_badv_ls1 === 32'hC001) begin
            $display("Test %0d: Bad address correct", test_num);
        end else begin
            $display("Test %0d ERROR: Bad address incorrect. Expected=0xC001, Actual=0x%h", 
                     test_num, lsu_ecl_except_badv_ls1);
            error_count = error_count + 1;
        end
    end else begin
        $display("Test %0d FAILED: No ALE exception for unaligned halfword", test_num);
        error_count = error_count + 1;
    end
    
    @(posedge clk);
    if (lsu_biu_rd_req_ls2) begin
        $display("Test %0d ERROR: BIU request issued for unaligned halfword access", test_num);
        error_count = error_count + 1;
    end
    
    repeat(3) @(posedge clk);
end
endtask

// Main test sequence
initial begin
    $display("=========================================");
    $display("Starting c7blsu Load Instruction Tests");
    $display("=========================================");
    
    initialize;
    
    test_ld_w_aligned;
    test_ld_w_unaligned;
    
    test_ld_b_signed;
    test_ld_b_signed_byte0;
    test_ld_b_signed_byte1;
    test_ld_b_signed_byte3;
    test_ld_b_signed_high32;
    
    test_ld_bu_unsigned;
    test_ld_bu_unsigned_byte0;
    test_ld_bu_unsigned_byte2;
    test_ld_bu_unsigned_byte3;
    test_ld_bu_unsigned_high32;
    
    test_ld_h_signed;
    test_ld_h_signed_half0;
    test_ld_h_signed_positive;
    test_ld_h_signed_high32;
    test_ld_h_signed_high32_neg;
    test_ld_h_signed_high32_bytes67;
    test_ld_h_signed_understanding;
    test_ld_h_signed_address2;
    
    test_ld_hu_unsigned;
    test_ld_hu_unsigned_half0;
    test_ld_hu_unsigned_nonzero;
    test_ld_hu_unsigned_high32;
    test_ld_hu_unsigned_high32_half1;
    test_ld_hu_unsigned_max;
    
    test_ld_wu_unsigned;
    test_ld_w_offset4;
    test_ld_h_unaligned;
    
    // Summary
    $display("\n=========================================");
    $display("Test Summary:");
    $display("  Total tests: %0d", test_num);
    $display("  Errors: %0d", error_count);
    
    if (error_count == 0) begin
        $display("  Result: ALL TESTS PASSED!");
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
        $display("  Result: %0d TEST(S) FAILED!", error_count);
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
    $display("=========================================");
    
    #100;
    $finish;
end

// Monitor for debugging
always @(posedge clk) begin
    if (ecl_lsu_valid_e) begin
        $display("[%0t] ECL: Valid=1, Op=0x%h, Base=0x%h, Offset=0x%h, TotalAddr=0x%h",
                 $time, ecl_lsu_op_e, ecl_lsu_base_e, ecl_lsu_offset_e, 
                 ecl_lsu_base_e + ecl_lsu_offset_e);
    end
    
    if (lsu_biu_rd_req_ls2) begin
        $display("[%0t] BIU RD Request: Addr=0x%h",
                 $time, lsu_biu_rd_addr_ls2);
    end
    
    if (biu_lsu_rd_ack_ls2) begin
        $display("[%0t] BIU RD Acknowledge", $time);
    end
    
    if (biu_lsu_data_valid_ls3) begin
        $display("[%0t] BIU Data Response: Data=0x%h",
                 $time, biu_lsu_data_ls3);
    end
    
    if (lsu_ecl_data_valid_ls3) begin
        $display("[%0t] LSU Data Output: Valid=1, Data=0x%h",
                 $time, lsu_ecl_data_ls3);
    end
    
    if (lsu_ecl_except_ale_ls1) begin
        $display("[%0t] ALE Exception Triggered, BadAddr=0x%h", 
                 $time, lsu_ecl_except_badv_ls1);
    end
end

endmodule
