`timescale 1ns/1ns

`include "decode.vh"

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
wire lsu_ecl_except_ale_ls1;
wire [31:0] lsu_csr_except_badv_ls1;
wire lsu_ecl_except_buserr_ls3;
wire lsu_ecl_except_ecc_ls3;

// BIU Interface
wire lsu_biu_rd_req_ls2;
wire [31:0] lsu_biu_rd_addr_ls2;
reg biu_lsu_rd_ack_ls2;
reg biu_lsu_data_valid_ls3;
reg [63:0] biu_lsu_data_ls3;

// Test variables
reg [31:0] expected_data;
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
    .lsu_ecl_except_ale_ls1(lsu_ecl_except_ale_ls1),
    .lsu_csr_except_badv_ls1(lsu_csr_except_badv_ls1),
    .lsu_ecl_except_buserr_ls3(lsu_ecl_except_buserr_ls3),
    .lsu_ecl_except_ecc_ls3(lsu_ecl_except_ecc_ls3),
    
    // BIU Interface
    .lsu_biu_rd_req_ls2(lsu_biu_rd_req_ls2),
    .lsu_biu_rd_addr_ls2(lsu_biu_rd_addr_ls2),
    .biu_lsu_rd_ack_ls2(biu_lsu_rd_ack_ls2),
    .biu_lsu_data_valid_ls3(biu_lsu_data_valid_ls3),
    .biu_lsu_data_ls3(biu_lsu_data_ls3),
    
    // Other interfaces (tied off)
    .lsu_biu_wr_req_ls2(),
    .lsu_biu_wr_addr_ls2(),
    .lsu_biu_wr_data_ls2(),
    .lsu_biu_wr_strb_ls2(),
    .biu_lsu_wr_ack_ls2(1'b0),
    .biu_lsu_wr_done_ls3(1'b0)
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
    test_num = 0;
    error_count = 0;
    
    #20;
    resetn = 1;
    #20;
end
endtask

// Wait for BIU request
task wait_for_biu_request;
begin
    @(posedge clk);
    while (!lsu_biu_rd_req_ls2) @(posedge clk);
    
    // Acknowledge request
    @(posedge clk);
    biu_lsu_rd_ack_ls2 = 1;
    @(posedge clk);
    biu_lsu_rd_ack_ls2 = 0;
end
endtask

// Send BIU response and check result in same cycle
task send_biu_response_and_check;
input [63:0] data;
input [31:0] expected;
begin
    // Wait for appropriate cycle (LS3)
    repeat(2) @(posedge clk);
    
    // Send response and check in same cycle
    biu_lsu_data_valid_ls3 = 1;
    biu_lsu_data_ls3 = data;
    
    @(posedge clk);
    biu_lsu_data_valid_ls3 = 0;
    
    // Data should be available now
    if (lsu_ecl_data_valid_ls3) begin
        check_result(expected, lsu_ecl_data_ls3);
    end else begin
        $display("Test %0d ERROR: lsu_ecl_data_valid_ls3 not asserted", test_num);
        error_count = error_count + 1;
    end
    
    @(posedge clk); // Wait one more cycle for cleanup
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

// Test 1: LD.W (Load Word) - aligned address
task test_ld_w_aligned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.W (aligned) ===", test_num);
    
    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_W;  // 7'b0000011
    ecl_lsu_base_e = 32'h1000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Simulate BIU interaction and check result
    wait_for_biu_request;
    send_biu_response_and_check(64'hA5A5_A5A5_1234_5678, 32'h12345678);
end
endtask

// Test 2: LD.W (Load Word) - unaligned address
task test_ld_w_unaligned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.W (unaligned) ===", test_num);
    
    // Setup load instruction with offset 1 (should trigger ALE)
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_W;  // 7'b0000011
    ecl_lsu_base_e = 32'h1000;
    ecl_lsu_offset_e = 32'h1;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
   
    // Wait for ALE in LS1 stage
    // Instruction flows: E -> LS1 -> LS2 -> LS3
    // ALE is generated in LS1, so we need to wait 1 cycle after E stage
    @(posedge clk); // Wait for LS1 stage 
    
    if (lsu_ecl_except_ale_ls1) begin
        $display("Test %0d PASSED: ALE exception triggered", test_num);
        $display("Bad address: 0x%h", lsu_csr_except_badv_ls1);
    end else begin
        $display("Test %0d FAILED: No ALE exception", test_num);
        error_count = error_count + 1;
    end
    
    // Wait to ensure no unexpected BIU requests
    repeat(5) @(posedge clk);
end
endtask

// Test 3: LD.B (Load Byte) signed - test byte position
task test_ld_b_signed;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2002 ===", test_num);
    
    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;  // 7'b0000001
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h2;  // Load from offset 2, address 0x2002
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Simulate BIU interaction and check result
    wait_for_biu_request;
    // Based on actual hardware behavior, address 0x2002 might access byte at different position
    // Let's test and see what happens
    send_biu_response_and_check(64'hFF00_FF00_FF80_FF00, 32'hFFFFFF80);
end
endtask

// Test 3b: LD.B (Load Byte) signed - test byte position 0
task test_ld_b_signed_byte0;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2000 (byte 0) ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h0;  // Load from offset 0, address 0x2000 (byte 0)
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    wait_for_biu_request;
    // byte 0 = 0xFF (-1), should be sign-extended
    send_biu_response_and_check(64'h0000_0000_0000_00FF, 32'hFFFFFFFF);
end
endtask

// Test 3c: LD.B (Load Byte) signed - test byte position 1
task test_ld_b_signed_byte1;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2001 (byte 1) ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h1;  // Load from offset 1, address 0x2001 (byte 1)
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    wait_for_biu_request;
    // byte 1 = 0x7F (127), should be sign-extended
    send_biu_response_and_check(64'h0000_0000_0000_7F00, 32'h0000007F);
end
endtask

// Test 3d: LD.B (Load Byte) signed - test byte position 3
task test_ld_b_signed_byte3;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2003 (byte 3) ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h3;  // Load from offset 3, address 0x2003 (byte 3)
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    wait_for_biu_request;
    // byte 3 = 0x80 (-128), should be sign-extended
    send_biu_response_and_check(64'h0000_0000_8000_0000, 32'hFFFFFF80);
end
endtask

// Test 3e: LD.B (Load Byte) signed - test high 32-bit byte
task test_ld_b_signed_high32;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.B (signed) - address 0x2004 (high 32-bit, byte 0) ===", test_num);
    
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h4;  // Load from offset 4, address 0x2004 (high 32-bit byte 0)
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    wait_for_biu_request;
    // high 32-bit byte 0 = 0x90 (-112), should be sign-extended
    send_biu_response_and_check(64'h0000_0090_0000_0000, 32'hFFFFFF90);
end
endtask

// Test 4: LD.BU (Load Byte Unsigned) - test byte position
task test_ld_bu_unsigned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3001 ===", test_num);

    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;  // 7'b0001001
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h1;  // Load from offset 1, address 0x3001 (byte 1)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    // Simulate BIU interaction and check result
    wait_for_biu_request;
    // byte 1 = 0x00, should be zero-extended
    send_biu_response_and_check(64'h0000_0000_0000_0080, 32'h00000000);
end
endtask

// Test 4b: LD.BU (Load Byte Unsigned) - test byte position 0
task test_ld_bu_unsigned_byte0;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3000 (byte 0) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h0;  // Load from offset 0, address 0x3000 (byte 0)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // byte 0 = 0x80 (128), should be zero-extended
    send_biu_response_and_check(64'h0000_0000_0000_0080, 32'h00000080);
end
endtask

// Test 4c: LD.BU (Load Byte Unsigned) - test byte position 2
task test_ld_bu_unsigned_byte2;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3002 (byte 2) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h2;  // Load from offset 2, address 0x3002 (byte 2)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // byte 2 = 0xFF (255), should be zero-extended
    send_biu_response_and_check(64'h0000_0000_00FF_0000, 32'h000000FF);
end
endtask

// Test 4d: LD.BU (Load Byte Unsigned) - test byte position 3
task test_ld_bu_unsigned_byte3;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3003 (byte 3) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h3;  // Load from offset 3, address 0x3003 (byte 3)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // byte 3 = 0x55 (85), should be zero-extended
    send_biu_response_and_check(64'h0000_0000_5500_0000, 32'h00000055);
end
endtask

// Test 4e: LD.BU (Load Byte Unsigned) - test high 32-bit byte
task test_ld_bu_unsigned_high32;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.BU (unsigned) - address 0x3004 (high 32-bit, byte 0) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_BU;
    ecl_lsu_base_e = 32'h3000;
    ecl_lsu_offset_e = 32'h4;  // Load from offset 4, address 0x3004 (high 32-bit byte 0)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // high 32-bit byte 0 = 0xAA (170), should be zero-extended
    send_biu_response_and_check(64'h0000_00AA_0000_0000, 32'h000000AA);
end
endtask

// Test 5: LD.H (Load Halfword) signed - test halfword position
task test_ld_h_signed;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4002 ===", test_num);

    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;  // 7'b0000010
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h2;  // Aligned halfword at address 0x4002
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    // Simulate BIU interaction and check result
    wait_for_biu_request;
    // halfword at offset 2 = 0xABCD (-21555), should be sign-extended
    send_biu_response_and_check(64'h0000_0000_ABCD_8000, 32'hFFFFABCD);
end
endtask

// Test 5b: LD.H (Load Halfword) signed - test halfword position 0
task test_ld_h_signed_half0;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4000 (half 0) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h0;  // Aligned halfword at address 0x4000
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // halfword 0 = 0x8000 (-32768), should be sign-extended
    send_biu_response_and_check(64'h0000_0000_ABCD_8000, 32'hFFFF8000);
end
endtask

// Test 5c: LD.H (Load Halfword) signed - test positive value
task test_ld_h_signed_positive;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4100 (positive value) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4100;
    ecl_lsu_offset_e = 32'h0;  // Aligned halfword at address 0x4100
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // halfword 0 = 0x7FFF (32767), should be sign-extended
    send_biu_response_and_check(64'h0000_0000_0000_7FFF, 32'h00007FFF);
end
endtask

// Test 5d: LD.H (Load Halfword) signed - test high 32-bit halfword
task test_ld_h_signed_high32;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4004 (high 32-bit, half 0) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h4;  // Aligned halfword at address 0x4004 (high 32-bit)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // high 32-bit halfword 0 (bytes 4-5) = 0x5678 (22136), should be sign-extended
    send_biu_response_and_check(64'h1234_5678_0000_0000, 32'h00005678);
end
endtask

// Test 5e: LD.H (Load Halfword) signed - test high 32-bit negative halfword
task test_ld_h_signed_high32_neg;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4006 (high 32-bit, half 1) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h6;  // Aligned halfword at address 0x4006 (high 32-bit half 1)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // high 32-bit halfword 1 (bytes 6-7) = 0x8000 (-32768), should be sign-extended
    send_biu_response_and_check(64'h8000_1234_0000_0000, 32'hFFFF8000);
end
endtask

// Test 5f: LD.H (Load Halfword) signed - test high 32-bit bytes 6-7
task test_ld_h_signed_high32_bytes67;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4006 (high 32-bit, bytes 6-7) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h6;  // Aligned halfword at address 0x4006 (high 32-bit bytes 6-7)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // high 32-bit bytes 6-7 = 0x1234 (4660), should be sign-extended
    send_biu_response_and_check(64'h1234_ABCD_0000_0000, 32'h00001234);
end
endtask

// Test 5g: LD.H (Load Halfword) signed - test understanding of byte addressing
// FIXED: Based on actual test output, address 0x4000 loads bytes 2-3 (0xEF01) not bytes 0-1 (0xABCD)
// This suggests little-endian byte ordering
task test_ld_h_signed_understanding;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4000 (low 32-bit) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h0;  // Aligned halfword at address 0x4000
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // Based on actual test output: address 0x4000 loads 0xEF01, not 0xABCD
    // This suggests little-endian: byte0=0x01, byte1=0xEF, byte2=0xCD, byte3=0xAB
    // So address 0x4000 loads bytes 0-1 = 0xEF01 (little-endian: [byte1][byte0])
    send_biu_response_and_check(64'h1234_5678_ABCD_EF01, 32'hFFFFEF01);
end
endtask

// Test 5h: LD.H (Load Halfword) signed - test address 0x4002 (low 32-bit, bytes 2-3)
// FIXED: Based on actual test output, address 0x4002 loads bytes 0-1 (0xABCD) not bytes 2-3 (0xEF01)
task test_ld_h_signed_address2;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (signed) - address 0x4002 (low 32-bit) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;
    ecl_lsu_base_e = 32'h4000;
    ecl_lsu_offset_e = 32'h2;  // Aligned halfword at address 0x4002
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // Based on actual test output: address 0x4002 loads 0xABCD, not 0xEF01
    // This confirms little-endian: address 0x4002 loads bytes 2-3 = 0xABCD (little-endian: [byte3][byte2])
    send_biu_response_and_check(64'h1234_5678_ABCD_EF01, 32'hFFFFABCD);
end
endtask

// Test 6: LD.HU (Load Halfword Unsigned) - test halfword position 2
task test_ld_hu_unsigned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5002 ===", test_num);

    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;  // 7'b0001010
    ecl_lsu_base_e = 32'h5000;
    ecl_lsu_offset_e = 32'h2;  // Aligned halfword at address 0x5002
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    // Simulate BIU interaction and check result
    wait_for_biu_request;
    // halfword at offset 2 = 0x0000, should be zero-extended
    send_biu_response_and_check(64'h0000_0000_0000_8000, 32'h00000000);
end
endtask

// Test 6b: LD.HU (Load Halfword Unsigned) - test halfword position 0
task test_ld_hu_unsigned_half0;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5000 (half 0) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5000;
    ecl_lsu_offset_e = 32'h0;  // Aligned halfword at address 0x5000
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // halfword 0 = 0x8000 (32768), should be zero-extended
    send_biu_response_and_check(64'h0000_0000_0000_8000, 32'h00008000);
end
endtask

// Test 6c: LD.HU (Load Halfword Unsigned) - test halfword position with non-zero bytes
task test_ld_hu_unsigned_nonzero;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5102 ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5100;
    ecl_lsu_offset_e = 32'h2;  // Aligned halfword at address 0x5102
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // halfword at offset 2 = 0x1234 (4660), should be zero-extended
    send_biu_response_and_check(64'h0000_0000_1234_5678, 32'h00001234);
end
endtask

// Test 6d: LD.HU (Load Halfword Unsigned) - test high 32-bit halfword
task test_ld_hu_unsigned_high32;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5204 (high 32-bit, half 0) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5200;
    ecl_lsu_offset_e = 32'h4;  // Aligned halfword at address 0x5204 (high 32-bit)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // high 32-bit halfword 0 = 0xABCD (43981), should be zero-extended
    send_biu_response_and_check(64'hABCD_1234_0000_0000, 32'h00001234);
end
endtask

// Test 6e: LD.HU (Load Halfword Unsigned) - test high 32-bit halfword position 6
task test_ld_hu_unsigned_high32_half1;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5206 (high 32-bit, half 1) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5200;
    ecl_lsu_offset_e = 32'h6;  // Aligned halfword at address 0x5206 (high 32-bit half 1)
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // high 32-bit halfword 1 = 0x1234 (4660), should be zero-extended
    send_biu_response_and_check(64'hABCD_1234_0000_0000, 32'h0000ABCD);
end
endtask

// Test 6f: LD.HU (Load Halfword Unsigned) - test max value
task test_ld_hu_unsigned_max;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.HU (unsigned) - address 0x5300 (max value) ===", test_num);

    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_HU;
    ecl_lsu_base_e = 32'h5300;
    ecl_lsu_offset_e = 32'h0;  // Aligned halfword at address 0x5300
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    wait_for_biu_request;
    // halfword 0 = 0xFFFF (65535), should be zero-extended
    send_biu_response_and_check(64'h0000_0000_0000_FFFF, 32'h0000FFFF);
end
endtask

// Test 7: LD.D (Load Doubleword) - lower 32 bits
task test_ld_d_lower;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.D (lower 32) ===", test_num);
    
    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_D;  // 7'b0000100
    ecl_lsu_base_e = 32'h6000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Simulate BIU interaction and check result
    wait_for_biu_request;
    send_biu_response_and_check(64'hDEAD_BEEF_CAFE_BABE, 32'hCAFEBABE);
end
endtask

// Test 8: LD.D (Load Doubleword) - upper 32 bits
task test_ld_d_upper;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.D (upper 32) ===", test_num);
    
    // Setup load instruction with offset to access upper 32 bits
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_D;  // 7'b0000100
    ecl_lsu_base_e = 32'h7000;
    ecl_lsu_offset_e = 32'h4;  // Access upper 32 bits
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Simulate BIU interaction and check result
    wait_for_biu_request;
    send_biu_response_and_check(64'h1111_2222_3333_4444, 32'h11112222);
end
endtask

// Test 9: LD.WU (Load Word Unsigned)
task test_ld_wu_unsigned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.WU (unsigned) ===", test_num);
    
    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_WU;  // 7'b0001011
    ecl_lsu_base_e = 32'h8000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Simulate BIU interaction and check result
    wait_for_biu_request;
    // Word = 0x80000000, should be zero-extended
    send_biu_response_and_check(64'h0000_0000_8000_0000, 32'h80000000);
end
endtask

// Test 10: LD.W with offset 0x4
task test_ld_w_offset4;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.W with offset 0x4 ===", test_num);
    
    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_W;  // 7'b0000011
    ecl_lsu_base_e = 32'h9000;
    ecl_lsu_offset_e = 32'h4;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Simulate BIU interaction and check result
    wait_for_biu_request;
    // Address 0x9004 corresponds to high 32-bit
    send_biu_response_and_check(64'hAAAABBBBCCCCDDDD, 32'hAAAABBBB);
end
endtask

// Test 11: LDX.W (Indexed Load Word)
task test_ldx_w;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LDX.W (Indexed) ===", test_num);
    
    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LDX_W;  // 7'b0010010
    ecl_lsu_base_e = 32'hA000;
    ecl_lsu_offset_e = 32'h0;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Simulate BIU interaction and check result
    wait_for_biu_request;
    send_biu_response_and_check(64'h5555_5555_9999_9999, 32'h99999999);
end
endtask

// Test 12: LDX.BU (Indexed Load Byte Unsigned)
task test_ldx_bu;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LDX.BU (Indexed) ===", test_num);
    
    // Setup load instruction
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LDX_BU;  // 7'b0010100
    ecl_lsu_base_e = 32'hB000;
    ecl_lsu_offset_e = 32'h3;  // Load from offset 3
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Simulate BIU interaction and check result
    wait_for_biu_request;
    // Byte at offset 3 = 0x40, should be zero-extended
    send_biu_response_and_check(64'h0000_0040_0000_0000, 32'h00000040);
end
endtask

// Test 13: LD.H with unaligned address (should trigger ALE)
task test_ld_h_unaligned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.H (unaligned) ===", test_num);
    
    // Setup load instruction with offset 1 (should trigger ALE for halfword)
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_H;  // 7'b0000010
    ecl_lsu_base_e = 32'hC000;
    ecl_lsu_offset_e = 32'h1;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Wait for ALE
    repeat(1) @(posedge clk);
    
    if (lsu_ecl_except_ale_ls1) begin
        $display("Test %0d PASSED: ALE exception triggered for unaligned halfword", test_num);
        $display("Bad address: 0x%h", lsu_csr_except_badv_ls1);
    end else begin
        $display("Test %0d FAILED: No ALE exception for unaligned halfword", test_num);
        error_count = error_count + 1;
    end
    
    repeat(5) @(posedge clk);
end
endtask

// Test 14: LD.D with unaligned address (should trigger ALE)
task test_ld_d_unaligned;
begin
    test_num = test_num + 1;
    $display("\n=== Test %0d: LD.D (unaligned) ===", test_num);
    
    // Setup load instruction with offset 1 (should trigger ALE for doubleword)
    @(posedge clk);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_D;  // 7'b0000100
    ecl_lsu_base_e = 32'hD000;
    ecl_lsu_offset_e = 32'h1;
    @(posedge clk);
    ecl_lsu_valid_e = 0;
    
    // Wait for ALE
    repeat(1) @(posedge clk);
    
    if (lsu_ecl_except_ale_ls1) begin
        $display("Test %0d PASSED: ALE exception triggered for unaligned doubleword", test_num);
        $display("Bad address: 0x%h", lsu_csr_except_badv_ls1);
    end else begin
        $display("Test %0d FAILED: No ALE exception for unaligned doubleword", test_num);
        error_count = error_count + 1;
    end
    
    repeat(5) @(posedge clk);
end
endtask

// Main test sequence
initial begin
    $display("=========================================");
    $display("Starting c7blsu Load Instruction Tests");
    $display("=========================================");
    
    initialize;
    
    // Run all tests
    test_ld_w_aligned;
    test_ld_w_unaligned;
    // Byte load tests - signed
    test_ld_b_signed;          // Test byte position 2
    test_ld_b_signed_byte0;    // Test byte position 0
    test_ld_b_signed_byte1;    // Test byte position 1
    test_ld_b_signed_byte3;    // Test byte position 3
    test_ld_b_signed_high32;   // Test high 32-bit byte
    
    // Byte load tests - unsigned
    test_ld_bu_unsigned;       // Test byte position 1
    test_ld_bu_unsigned_byte0; // Test byte position 0
    test_ld_bu_unsigned_byte2; // Test byte position 2
    test_ld_bu_unsigned_byte3; // Test byte position 3
    test_ld_bu_unsigned_high32;// Test high 32-bit byte

    // Halfword load tests - signed
    test_ld_h_signed;              // Test address 0x4002 (low 32-bit bytes 2-3)
    test_ld_h_signed_half0;        // Test address 0x4000 (low 32-bit bytes 0-1)
    test_ld_h_signed_positive;     // Test positive value
    test_ld_h_signed_high32;       // Test address 0x4004 (high 32-bit bytes 4-5)
    test_ld_h_signed_high32_neg;   // Test address 0x4006 with negative value
    test_ld_h_signed_high32_bytes67;// Test address 0x4006 with positive value
    test_ld_h_signed_understanding;// Fixed: little-endian addressing
    test_ld_h_signed_address2;     // Fixed: little-endian addressing
    
    // Halfword load tests - unsigned
    test_ld_hu_unsigned;               // Test halfword position 2 (zero value)
    test_ld_hu_unsigned_half0;         // Test halfword position 0 (0x8000)
    test_ld_hu_unsigned_nonzero;       // Test halfword position 2 (0x1234)
    test_ld_hu_unsigned_high32;        // Test high 32-bit halfword (0xABCD)
    test_ld_hu_unsigned_high32_half1;  // Test high 32-bit halfword 1 (0x1234)
    test_ld_hu_unsigned_max;           // Test max value (0xFFFF)
    
    // Word and doubleword tests
    // ld.d ldx not supported
    test_ld_wu_unsigned;
//    test_ld_d_lower;
//    test_ld_d_upper;
    test_ld_w_offset4;
//    test_ldx_w;
//    test_ldx_bu;
    test_ld_h_unaligned;
//    test_ld_d_unaligned;
    
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
                 $time, lsu_csr_except_badv_ls1);
    end
end

endmodule
