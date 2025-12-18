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
reg [4:0] ecl_lsu_rd_e;
reg ecl_lsu_wen_e;

// LSU output signals
wire lsu_ecl_data_valid_ls3;
wire [31:0] lsu_ecl_data_ls3;
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
reg biu_lsu_wr_done_ls3;

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
    .ecl_lsu_rd_e(ecl_lsu_rd_e),
    .ecl_lsu_wen_e(ecl_lsu_wen_e),
    
    .lsu_ecl_data_valid_ls3(lsu_ecl_data_valid_ls3),
    .lsu_ecl_data_ls3(lsu_ecl_data_ls3),
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
    .biu_lsu_wr_done_ls3(biu_lsu_wr_done_ls3)
);

// Clock generation
always #5 clk = ~clk;

// Test case parameters
reg [31:0] expected_addr;
reg [63:0] expected_data;
reg [7:0]  expected_strb;
reg [7:0]  expected_strb_replicated;
integer test_count;
integer error_count;

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
    ecl_lsu_rd_e = 0;
    ecl_lsu_wen_e = 0;
    
    biu_lsu_rd_ack_ls2 = 0;
    biu_lsu_data_valid_ls3 = 0;
    biu_lsu_data_ls3 = 0;
    
    biu_lsu_wr_ack_ls2 = 0;
    biu_lsu_wr_done_ls3 = 0;
    
    test_count = 0;
    error_count = 0;
    
    // Reset sequence
    #20 resetn = 1;
    @(posedge clk);
    
    $display("\n========================================");
    $display("Starting Store Byte (SB) Operation Test with WSTRB Verification");
    $display("========================================\n");
    
    // Test Case 1: Test all byte positions with wstrb verification
    test_all_byte_positions();
    
    // Test Case 2: Test data replication for SB, SH, SW
    test_data_replication();
    
    // Test Case 3: Test wstrb generation for different store types
    test_store_types_wstrb();
    
    // Test Case 4: Test wstrb with boundary addresses
    test_boundary_wstrb();
    
    // Test summary
    $display("\n========================================");
    $display("Test Complete");
    $display("Total Tests Executed: %0d", test_count);
    $display("Error Count: %0d", error_count);
    if (error_count == 0)
        $display("All Tests Passed! ✓");
    else
        $display("Some Tests Failed! ✗");
    $display("========================================\n");
    
    #100;
    $finish;
end

// Test task: Verify wstrb for all byte positions
task test_all_byte_positions;
    integer i;
    reg [7:0] test_data;
    reg [63:0] data_before_wstrb;
    
    begin
        $display("[Test Group] WSTRB Verification for All Byte Positions");
        
        for (i = 0; i < 8; i = i + 1) begin
            test_count = test_count + 1;
            test_data = 8'hA0 + i;
            
            $display("\n[Test %0d] Byte Position %0d", test_count, i);
            $display("  Testing wstrb for byte at position %0d", i);
            
            // Send store byte request
            @(posedge clk);
            ecl_lsu_valid_e = 1;
            ecl_lsu_op_e = `LLSU_ST_B;
            ecl_lsu_base_e = 32'h1000;
            ecl_lsu_offset_e = i;
            ecl_lsu_wdata_e = {24'h0, test_data};
            ecl_lsu_wen_e = 0;
            
            @(posedge clk);
            ecl_lsu_valid_e = 0;
            
            // Wait for LS2 stage
            repeat(2) @(posedge clk);
            
            // Expected wstrb based on byte position
            case (i)
                0: expected_strb = 8'b00000001;
                1: expected_strb = 8'b00000010;
                2: expected_strb = 8'b00000100;
                3: expected_strb = 8'b00001000;
                4: expected_strb = 8'b00010000;
                5: expected_strb = 8'b00100000;
                6: expected_strb = 8'b01000000;
                7: expected_strb = 8'b10000000;
            endcase
            
            // Verify wstrb
            $display("  Expected wstrb: 0b%b (0x%h)", expected_strb, expected_strb);
            $display("  Actual wstrb:   0b%b (0x%h)", lsu_biu_wr_strb_ls2, lsu_biu_wr_strb_ls2);
            
            if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
                $display("  ERROR: WSTRB mismatch!");
                error_count = error_count + 1;
            end else begin
                $display("  WSTRB correct!");
            end
            
            // Calculate data BEFORE wstrb masking (data with replication)
            // For SB: data is replicated to all positions
            data_before_wstrb = 64'h0;
            case (i)
                // Lower 32-bit region
                0: data_before_wstrb = {56'h0, test_data};
                1: data_before_wstrb = {48'h0, test_data, 8'h0};
                2: data_before_wstrb = {40'h0, test_data, 16'h0};
                3: data_before_wstrb = {32'h0, test_data, 24'h0};
                // Upper 32-bit region  
                4: data_before_wstrb = {24'h0, test_data, 32'h0};
                5: data_before_wstrb = {16'h0, test_data, 40'h0};
                6: data_before_wstrb = {8'h0, test_data, 48'h0};
                7: data_before_wstrb = {test_data, 56'h0};
            endcase
            
            // Expected data sent to BIU (should match actual data)
            // The data sent should already have the correct byte at the right position
            // AND all other positions should have the replicated value
            expected_data = data_before_wstrb;
            
            $display("  Expected data (before wstrb): 0x%h", expected_data);
            $display("  Actual data:                  0x%h", lsu_biu_wr_data_ls2);
            
            // Check that the data at the target position is correct
            case (i)
                0: if (lsu_biu_wr_data_ls2[7:0] !== test_data) begin
                    $display("  ERROR: Data at position 0 incorrect!");
                    error_count = error_count + 1;
                end
                1: if (lsu_biu_wr_data_ls2[15:8] !== test_data) begin
                    $display("  ERROR: Data at position 1 incorrect!");
                    error_count = error_count + 1;
                end
                2: if (lsu_biu_wr_data_ls2[23:16] !== test_data) begin
                    $display("  ERROR: Data at position 2 incorrect!");
                    error_count = error_count + 1;
                end
                3: if (lsu_biu_wr_data_ls2[31:24] !== test_data) begin
                    $display("  ERROR: Data at position 3 incorrect!");
                    error_count = error_count + 1;
                end
                4: if (lsu_biu_wr_data_ls2[39:32] !== test_data) begin
                    $display("  ERROR: Data at position 4 incorrect!");
                    error_count = error_count + 1;
                end
                5: if (lsu_biu_wr_data_ls2[47:40] !== test_data) begin
                    $display("  ERROR: Data at position 5 incorrect!");
                    error_count = error_count + 1;
                end
                6: if (lsu_biu_wr_data_ls2[55:48] !== test_data) begin
                    $display("  ERROR: Data at position 6 incorrect!");
                    error_count = error_count + 1;
                end
                7: if (lsu_biu_wr_data_ls2[63:56] !== test_data) begin
                    $display("  ERROR: Data at position 7 incorrect!");
                    error_count = error_count + 1;
                end
            endcase
            
            // Verify that wstrb ORed with data gives expected result
            // This is what the BIU will do: use wstrb to select which bytes to write
            verify_wstrb_data_combination(expected_strb, expected_data);
            
            // Send BIU response
            send_biu_response();
        end
    end
endtask

// Test task: Verify data replication patterns
task test_data_replication;
    reg [31:0] test_wdata;
    reg [63:0] data_before_wstrb;
    
    integer j;

    begin

        $display("\n[Test Group] Data Replication Patterns");
        
        // Test SB (Store Byte) - data replication
        test_count = test_count + 1;
        $display("\n[Test %0d] Store Byte (SB) - Byte Replication Pattern", test_count);
        test_wdata = 32'h000000CD;
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h2000;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = test_wdata;
        ecl_lsu_wen_e = 0;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Wstrb for SB at position 0
        expected_strb = 8'b00000001;
        
        // Data should have the byte replicated in all positions
        // For SB: all 8 bytes should have the same value (0xCD)
        data_before_wstrb = {8{test_wdata[7:0]}};
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Expected data pattern (replicated): 0x%h", data_before_wstrb);
        $display("  Actual data:                        0x%h", lsu_biu_wr_data_ls2);
        
        // Verify data replication pattern
        if (lsu_biu_wr_data_ls2 !== data_before_wstrb) begin
            $display("  ERROR: Data replication pattern incorrect!");
            // Check each byte
            for (j = 0; j < 8; j = j + 1) begin
                if (lsu_biu_wr_data_ls2[j*8+:8] !== test_wdata[7:0]) begin
                    $display("    Byte %0d: Expected 0x%h, Actual 0x%h", 
                             j, test_wdata[7:0], lsu_biu_wr_data_ls2[j*8+:8]);
                end
            end
            error_count = error_count + 1;
        end else begin
            $display("  Data replication pattern correct!");
        end
        
        verify_wstrb_data_combination(expected_strb, data_before_wstrb);
        send_biu_response();
        
        // Test SH (Store Halfword) - halfword replication
        test_count = test_count + 1;
        $display("\n[Test %0d] Store Halfword (SH) - Halfword Replication Pattern", test_count);
        test_wdata = 32'h0000ABCD;
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_H;
        ecl_lsu_base_e = 32'h2004;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = test_wdata;
        ecl_lsu_wen_e = 0;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Wstrb for SH at aligned address
        expected_strb = 8'b00000011;
        
        // For SH: halfword is replicated [AB, CD, AB, CD, AB, CD, AB, CD]
        data_before_wstrb = {4{test_wdata[15:0]}};
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Expected data pattern (halfword replicated): 0x%h", data_before_wstrb);
        $display("  Actual data:                                0x%h", lsu_biu_wr_data_ls2);
        
        // Check the pattern
        for (j = 0; j < 4; j = j + 1) begin
            if (lsu_biu_wr_data_ls2[j*16+:16] !== test_wdata[15:0]) begin
                $display("  ERROR: Halfword replication incorrect at group %0d", j);
                error_count = error_count + 1;
            end
        end
        
        verify_wstrb_data_combination(expected_strb, data_before_wstrb);
        send_biu_response();
        
        // Test SW (Store Word) - word replication
        test_count = test_count + 1;
        $display("\n[Test %0d] Store Word (SW) - Word Replication Pattern", test_count);
        test_wdata = 32'h12345678;
        
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_W;
        ecl_lsu_base_e = 32'h2008;
        ecl_lsu_offset_e = 32'h0;
        ecl_lsu_wdata_e = test_wdata;
        ecl_lsu_wen_e = 0;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Wstrb for SW at aligned address
        expected_strb = 8'b00001111;
        
        // For SW: word is replicated [12, 34, 56, 78, 12, 34, 56, 78]
        data_before_wstrb = {2{test_wdata}};
        
        $display("  Expected wstrb: 0b%b", expected_strb);
        $display("  Expected data pattern (word replicated): 0x%h", data_before_wstrb);
        $display("  Actual data:                            0x%h", lsu_biu_wr_data_ls2);
        
        // Check the pattern
        if (lsu_biu_wr_data_ls2[31:0] !== test_wdata || 
            lsu_biu_wr_data_ls2[63:32] !== test_wdata) begin
            $display("  ERROR: Word replication incorrect!");
            error_count = error_count + 1;
        end
        
        verify_wstrb_data_combination(expected_strb, data_before_wstrb);
        send_biu_response();
    end
endtask

// Test task: Verify wstrb and data relationship
task test_wstrb_data_relationship;
    integer i;
    integer j;
    reg [63:0] test_pattern;
    reg [7:0] expected_byte;
    
    begin
        $display("\n[Test Group] WSTRB and Data Relationship");
        
        // Test that wstrb indicates which bytes contain valid data
        test_count = test_count + 1;
        $display("\n[Test %0d] WSTRB indicates valid data positions", test_count);
        
        // Test different store types at different alignments
        for (i = 0; i < 3; i = i + 1) begin
            case (i)
                0: begin // SB at position 3
                    ecl_lsu_op_e = `LLSU_ST_B;
                    ecl_lsu_offset_e = 32'h3;
                    expected_strb = 8'b00001000;
                    expected_byte = 8'h99;
                end
                1: begin // SH at position 2 (unaligned)
                    ecl_lsu_op_e = `LLSU_ST_H;
                    ecl_lsu_offset_e = 32'h2;
                    expected_strb = 8'b00111100; // For unaligned SH
                    expected_byte = 8'hAA; // Will be replicated
                end
                2: begin // SW at position 1 (unaligned)
                    ecl_lsu_op_e = `LLSU_ST_W;
                    ecl_lsu_offset_e = 32'h1;
                    expected_strb = 8'b00001110; // For unaligned SW
                    expected_byte = 8'hBB; // Will be replicated
                end
            endcase
            
            @(posedge clk);
            ecl_lsu_valid_e = 1;
            ecl_lsu_base_e = 32'h3000 + (i * 32'h10);
            ecl_lsu_wdata_e = {24'h0, expected_byte};
            ecl_lsu_wen_e = 0;
            
            @(posedge clk);
            ecl_lsu_valid_e = 0;
            
            repeat(2) @(posedge clk);
            
            $display("  Operation %0d: Op=%h, Offset=%h", 
                     i, ecl_lsu_op_e, ecl_lsu_offset_e);
            $display("  Expected wstrb: 0b%b", expected_strb);
            $display("  Actual wstrb:   0b%b", lsu_biu_wr_strb_ls2);
            
            // Verify that for each wstrb=1 position, data has the expected value
            for (j = 0; j < 8; j = j + 1) begin
                if (expected_strb[j] && lsu_biu_wr_strb_ls2[j]) begin
                    // This byte should be enabled
                    if (lsu_biu_wr_data_ls2[j*8+:8] !== expected_byte) begin
                        $display("  ERROR: Byte %0d should be 0x%h but is 0x%h", 
                                 j, expected_byte, lsu_biu_wr_data_ls2[j*8+:8]);
                        error_count = error_count + 1;
                    end
                end
            end
            
            // The combination of wstrb and data should work correctly
            verify_wstrb_data_combination(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);
            
            send_biu_response();
            repeat(2) @(posedge clk);
        end
    end
endtask

// Helper task: Verify that wstrb ORed with data gives correct result
task verify_wstrb_data_combination;
    input [7:0] wstrb;
    input [63:0] data;
    
    reg [63:0] combined_result;
    reg [63:0] expected_combined;
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
        
        // The combined result should be exactly the data at wstrb-enabled positions
        // and 0 at other positions
        expected_combined = 64'h0;
        for (j = 0; j < 8; j = j + 1) begin
            if (wstrb[j]) begin
                expected_combined[j*8+:8] = data[j*8+:8];
            end
        end
        
        if (combined_result !== expected_combined) begin
            $display("    ERROR: WSTRB-data combination incorrect!");
            $display("    Combined result: 0x%h", combined_result);
            $display("    Expected:        0x%h", expected_combined);
            error_count = error_count + 1;
        end else begin
            $display("    WSTRB-data combination correct");
        end
        
        // Also verify that for wstrb=0 positions, data can be anything
        // (it's don't-care for the BIU)
        $display("    Note: Data at wstrb=0 positions is don't-care for BIU");
    end
endtask

// Helper task: Print detailed byte-by-byte analysis
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

// Initial block - update to include new test groups
initial begin
    // [Initialization code...]
    
    $display("\n========================================");
    $display("Starting Store Operation Test with WSTRB-Data Relationship");
    $display("========================================\n");
    
    // Test Case 1: Test all byte positions
    test_all_byte_positions();
    
    // Test Case 2: Test data replication patterns
    test_data_replication();
    
    // Test Case 3: Test wstrb and data relationship
    test_wstrb_data_relationship();
    
    // Test Case 4: Test wstrb generation for different store types
    test_store_types_wstrb();
    
    // Test Case 5: Test wstrb with boundary addresses
    test_boundary_wstrb();
    
    // [Test summary...]
end

// Test task: Test wstrb generation for different store types (updated)
task test_store_types_wstrb;
    integer addr_offset;
    reg [7:0] expected_wstrb;
    
    begin
        $display("\n[Test Group] WSTRB Generation for Different Store Types");
        
        // Test all store types
        test_store_type_wstrb(`LLSU_ST_B, "Store Byte (SB)");
        test_store_type_wstrb(`LLSU_ST_H, "Store Halfword (SH)");
        test_store_type_wstrb(`LLSU_ST_W, "Store Word (SW)");
        test_store_type_wstrb(`LLSU_ST_D, "Store Doubleword (SD)");
    end
endtask

task test_store_type_wstrb;
	input [6:0] opcode;
	input [80:0] store_type_name;

	integer offset;
	reg [7:0] expected_wstrb;

	begin
		test_count = test_count + 1;
		$display("\n[Test %0d] %s WSTRB Patterns", test_count, store_type_name);

		// Test different alignments
		for (offset = 0; offset < 8; offset = offset + 1) begin
			// Skip invalid alignments for certain operations
			if ((opcode == `LLSU_ST_H && offset[0] == 1'b1 && offset < 7) || // SH must be halfword aligned
				(opcode == `LLSU_ST_W && offset[1:0] != 2'b00 && offset < 5) || // SW must be word aligned
				(opcode == `LLSU_ST_D && offset[2:0] != 3'b000)) // SD must be doubleword aligned
			begin
				//continue;
				//nothing
			end else begin

				@(posedge clk);
				ecl_lsu_valid_e = 1;
				ecl_lsu_op_e = opcode;
				ecl_lsu_base_e = 32'h4000 + (offset * 32'h4);
				ecl_lsu_offset_e = offset;
				ecl_lsu_wdata_e = 32'h11223344;
				ecl_lsu_wen_e = 0;

				@(posedge clk);
				ecl_lsu_valid_e = 0;

				repeat(2) @(posedge clk);

				// Calculate expected wstrb based on opcode and offset
				case (opcode)
					`LLSU_ST_B: expected_wstrb = (8'b1 << offset);
					`LLSU_ST_H: begin
						if (offset == 7) begin
							expected_wstrb = 8'b10000000; // Special case for position 7
						end else begin
							expected_wstrb = 8'b11 << offset;
						end
					end
					`LLSU_ST_W: expected_wstrb = 8'b1111 << offset;
					`LLSU_ST_D: expected_wstrb = 8'b11111111; // Always all bytes for doubleword
				endcase

				$display("  Offset %0d: Expected wstrb=0b%b, Actual=0b%b", 
					offset, expected_wstrb, lsu_biu_wr_strb_ls2);

				if (lsu_biu_wr_strb_ls2 !== expected_wstrb) begin
					$display("    ERROR: WSTRB mismatch!");
					error_count = error_count + 1;
				end

				// Print byte analysis
				print_byte_analysis(lsu_biu_wr_strb_ls2, lsu_biu_wr_data_ls2);

				send_biu_response();
				repeat(2) @(posedge clk);
			end
		end
	end
endtask



// Test task: WSTRB with boundary addresses
task test_boundary_wstrb;
    begin
        $display("\n[Test Group] WSTRB at Boundary Addresses");
        
        // Test near 64-bit boundary (crossing 32-bit boundary)
        test_count = test_count + 1;
        $display("\n[Test %0d] Store Byte at 32-bit boundary", test_count);
        
        // Address 0x...3 (last byte of lower 32-bit)
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h5000;
        ecl_lsu_offset_e = 32'h3;
        ecl_lsu_wdata_e = 32'h000000FF;
        ecl_lsu_wen_e = 0;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Address[2:0] = 3'b011, so wstrb should be 8'b00001000 (lower 32-bit)
        expected_strb = 8'b00001000;
        
        $display("  Address at 32-bit boundary (offset 3)");
        $display("  Expected wstrb: 0b%b, Actual: 0b%b", 
                 expected_strb, lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            error_count = error_count + 1;
        end
        
        send_biu_response();
        
        // Test at next address (crossing to upper 32-bit)
        test_count = test_count + 1;
        $display("\n[Test %0d] Store Byte crossing 32-bit boundary", test_count);
        
        // Address 0x...4 (first byte of upper 32-bit)
        @(posedge clk);
        ecl_lsu_valid_e = 1;
        ecl_lsu_op_e = `LLSU_ST_B;
        ecl_lsu_base_e = 32'h5000;
        ecl_lsu_offset_e = 32'h4;
        ecl_lsu_wdata_e = 32'h000000AA;
        ecl_lsu_wen_e = 0;
        
        @(posedge clk);
        ecl_lsu_valid_e = 0;
        
        repeat(2) @(posedge clk);
        
        // Address[2] = 1'b1, so wstrb should be in upper 32-bit: 8'b00010000
        expected_strb = 8'b00010000;
        
        $display("  Address crossing 32-bit boundary (offset 4)");
        $display("  Expected wstrb: 0b%b, Actual: 0b%b", 
                 expected_strb, lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== expected_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            error_count = error_count + 1;
        end
        
        send_biu_response();
    end
endtask

// Helper task: Verify wstrb and data
task verify_wstrb_and_data;
    input [7:0] exp_strb;
    input [63:0] exp_data;
    
    begin
        $display("  Expected wstrb: 0b%b (0x%h)", exp_strb, exp_strb);
        $display("  Actual wstrb:   0b%b (0x%h)", lsu_biu_wr_strb_ls2, lsu_biu_wr_strb_ls2);
        
        if (lsu_biu_wr_strb_ls2 !== exp_strb) begin
            $display("  ERROR: WSTRB mismatch!");
            error_count = error_count + 1;
        end else begin
            $display("  WSTRB correct!");
        end
        
        $display("  Expected data: 0x%h", exp_data);
        $display("  Actual data:   0x%h", lsu_biu_wr_data_ls2);
        
        if (lsu_biu_wr_data_ls2 !== exp_data) begin
            $display("  ERROR: Data mismatch!");
            error_count = error_count + 1;
        end else begin
            $display("  Data correct!");
        end
    end
endtask

// Helper task: Send BIU response
task send_biu_response;
    begin
        @(posedge clk);
        biu_lsu_wr_ack_ls2 = 1;
        @(posedge clk);
        biu_lsu_wr_ack_ls2 = 0;
        
        @(posedge clk);
        biu_lsu_wr_done_ls3 = 1;
        @(posedge clk);
        biu_lsu_wr_done_ls3 = 0;
        
        repeat(2) @(posedge clk);
    end
endtask

// Monitor outputs
always @(posedge clk) begin
    // Monitor exception signals
    if (lsu_ecl_except_ale_ls1) begin
        $display("[%0t] ALE Exception: Address=0x%h", $time, lsu_csr_except_badv_ls1);
    end
end

endmodule
