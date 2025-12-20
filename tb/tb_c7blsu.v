`timescale 1ns/1ps

module top_tb();

// 全局信号
reg clk;
reg resetn;

// 接口信号
reg ecl_lsu_valid_e;
reg [6:0] ecl_lsu_op_e;
reg [31:0] ecl_lsu_base_e;
reg [31:0] ecl_lsu_offset_e;
reg [31:0] ecl_lsu_wdata_e;
//reg [4:0] ecl_lsu_rd_e;
//reg ecl_lsu_wen_e;

wire lsu_ecl_data_valid_ls3;
wire [31:0] lsu_ecl_data_ls3;
wire lsu_ecl_except_ale_ls1;
wire [31:0] lsu_csr_except_badv_ls1;
wire lsu_ecl_except_buserr_ls3;
wire lsu_ecl_except_ecc_ls3;

// BIU 接口
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

// 待测模块实例化
c7blsu uut (
    .clk(clk),
    .resetn(resetn),

    // ECL Interface
    .ecl_lsu_valid_e(ecl_lsu_valid_e),
    .ecl_lsu_op_e(ecl_lsu_op_e),
    .ecl_lsu_base_e(ecl_lsu_base_e),
    .ecl_lsu_offset_e(ecl_lsu_offset_e),
    .ecl_lsu_wdata_e(ecl_lsu_wdata_e),
    //.ecl_lsu_rd_e(ecl_lsu_rd_e),
    //.ecl_lsu_wen_e(ecl_lsu_wen_e),

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

    .lsu_biu_wr_req_ls2(lsu_biu_wr_req_ls2),
    .lsu_biu_wr_addr_ls2(lsu_biu_wr_addr_ls2),
    .lsu_biu_wr_data_ls2(lsu_biu_wr_data_ls2),
    .lsu_biu_wr_strb_ls2(lsu_biu_wr_strb_ls2),

    .biu_lsu_wr_ack_ls2(biu_lsu_wr_ack_ls2),
    .biu_lsu_wr_done_ls3(biu_lsu_wr_done_ls3)
);

// 时钟生成
always #5 clk = ~clk;

// 初始化
initial begin
    clk = 0;
    resetn = 0;

    ecl_lsu_valid_e = 0;
    ecl_lsu_op_e = 0;
    ecl_lsu_base_e = 0;
    ecl_lsu_offset_e = 0;
    ecl_lsu_wdata_e = 0;
    //ecl_lsu_rd_e = 0;
    //ecl_lsu_wen_e = 0;

    biu_lsu_rd_ack_ls2 = 0;
    biu_lsu_data_valid_ls3 = 0;
    biu_lsu_data_ls3 = 0;

    biu_lsu_wr_ack_ls2 = 0;
    biu_lsu_wr_done_ls3 = 0;

    // 复位序列
    #20 resetn = 1;

    #10;

    // 测试用例1：加载字（LW）
    $display("[%0t] Test 1: Load Word", $time);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_W; // 假设 decode.vh 中有定义
    ecl_lsu_base_e = 32'h1000;
    ecl_lsu_offset_e = 32'h4;
    //ecl_lsu_wen_e = 1;
    //ecl_lsu_rd_e = 5'h5;

    @(posedge clk);
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    // 模拟 BIU 响应
    #10 biu_lsu_rd_ack_ls2 = 1;
    @(posedge clk);
    @(posedge clk);
    biu_lsu_rd_ack_ls2 = 0;

    #20 biu_lsu_data_valid_ls3 = 1;
    biu_lsu_data_ls3 = 64'h123456789ABCDEF0;
    @(posedge clk);
    @(posedge clk);
    biu_lsu_data_valid_ls3 = 0;

    #30;

    // 测试用例2：存储字节（SB）
    $display("[%0t] Test 2: Store Byte", $time);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_ST_B;
    ecl_lsu_base_e = 32'h2000;
    ecl_lsu_offset_e = 32'h2;
    ecl_lsu_wdata_e = 32'hAA;
    //ecl_lsu_wen_e = 0;

    @(posedge clk);
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    #10 biu_lsu_wr_ack_ls2 = 1;
    @(posedge clk);
    @(posedge clk);
    biu_lsu_wr_ack_ls2 = 0;

    #30 biu_lsu_wr_done_ls3 = 1;
    @(posedge clk);
    @(posedge clk);
    biu_lsu_wr_done_ls3 = 0;

    #30;

    // 测试用例3：对齐异常（ALE）
    $display("[%0t] Test 3: Alignment Exception", $time);
    ecl_lsu_valid_e = 1;
    ecl_lsu_op_e = `LLSU_LD_W;
    ecl_lsu_base_e = 32'h3001; // 未对齐地址
    ecl_lsu_offset_e = 32'h0;

    @(posedge clk);
    @(posedge clk);
    ecl_lsu_valid_e = 0;

    #30;

    // 结束测试
    $display("[%0t] Simulation finished.", $time);
    $finish;
end

// 监控输出
always @(posedge clk) begin
    if (lsu_ecl_data_valid_ls3)
        $display("[%0t] LSU Data Valid: data=0x%h", $time, lsu_ecl_data_ls3);

    if (lsu_ecl_except_ale_ls1)
        $display("[%0t] ALE Exception detected at LS1", $time);
end

endmodule
