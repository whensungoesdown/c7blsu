`include "decode.vh"

//
// The ECL interface signals are pulsed for a single cycle by ECL and must
// be captured internally by the LSU to maitain the request state. The LSU
// is always ready to accept the request for this in-order core.
//

// The ecl_lsu_valid_e signal propagates through the pipeline stages as
// lsu_valid_ls1 and lsu_valid_ls2. At LS2, lsu_valid_ls2 triggers a BIU
// request (lsu_biu_rd_req_ls2 / lsu_biu_wr_req_ls2), which remains asserted
// until acknowleged by the BIU.
//
// Note: Currently, both load and store requests are issued at LS2. A future
// revision may defer loads to LS3, where they first check the Store Buffer
// before proceeding to the BIU.

module c7blsu(
   input                              clk,
   input                              resetn,

   //--------------------------------------------------
   // ECL Interface
   //--------------------------------------------------
   
   input                              ecl_lsu_valid_e,
   input  [6:0]                       ecl_lsu_op_e,
   input  [31:0]                      ecl_lsu_base_e,
   input  [31:0]                      ecl_lsu_offset_e,
   input  [31:0]                      ecl_lsu_wdata_e,
//   input  [4:0]                       ecl_lsu_rd_e,
//   input                              ecl_lsu_wen_e,

   output                             lsu_ecl_data_valid_ls3,
   output [31:0]                      lsu_ecl_data_ls3,
   // Exceptions: ale, bus error, ECC
   output                             lsu_ecl_except_ale_ls1,
   output [31:0]                      lsu_csr_except_badv_ls1,
   output                             lsu_ecl_except_buserr_ls3,
   output                             lsu_ecl_except_ecc_ls3,

   //--------------------------------------------------
   // STB Interface
   //--------------------------------------------------

//   output                             lsu_stb_store_ls1,
//   output                             lsu_stb_valid_ls2,
//   output [31:2]                      lsu_stb_addr_ls2,
//   output [5:0]                       lsu_stb_attrs_ls2,
//   output [63:0]                      lsu_stb_store_data_ls3,
//   
//   input  [3:0]                       stb_lsu_slots_valid,
//
//   // lsu load bypassing forwarding check
//   output                             lsu_stb_req_ls3,
//   output [31:0]                      lsu_stb_addr_ls3,
//   input                              stb_lsu_hit_ls2,
//   input  [31:0]                      stb_lsu_data_ls2,
//
//   output                             lsu_stb_drain_entire_stb,

   //--------------------------------------------------
   // BIU Interface
   //--------------------------------------------------

   // BIU rd
   output                             lsu_biu_rd_req_ls2,
   output [31:0]                      lsu_biu_rd_addr_ls2,
   input                              biu_lsu_rd_ack_ls2,
   input                              biu_lsu_data_valid_ls3,
   input  [63:0]                      biu_lsu_data_ls3,

   // BIU wr
   output                             lsu_biu_wr_req_ls2,
   output [31:0]                      lsu_biu_wr_addr_ls2,
   output [63:0]                      lsu_biu_wr_data_ls2,
   output [7:0]                       lsu_biu_wr_strb_ls2,

   input                              biu_lsu_wr_ack_ls2,
   input                              biu_lsu_wr_done_ls3

);

   wire               lsu_valid_ls1;
   wire               lsu_valid_ls2;
   wire [6:0]         lsu_op_ls1;
   wire [31:0]        lsu_base_ls1;
   wire [31:0]        lsu_offset_ls1;
   wire [31:0]        lsu_wdata_raw_ls1;
   wire [31:0]        lsu_wdata_ls1;
   wire [31:0]        lsu_wdata_ls2;
   wire [7:0]         lsu_wstrb_ls1;
   wire [7:0]         lsu_wstrb_ls2;
   wire [4:0]         lsu_rd_ls1;
   wire               lsu_wen_ls1;

   wire [31:0]        lsu_addr_ls1   = lsu_base_ls1 + lsu_offset_ls1;
   wire [ 2:0]        lsu_shift_ls1  = lsu_addr_ls1[2:0];
   wire [ 2:0]        lsu_shift_ls2;
   wire [ 2:0]        lsu_shift_ls3;

   wire [31:0]        lsu_addr_ls2;
   wire [31:0]        lsu_addr_ls3;

   // decode atomic op
   wire lsu_am_lw   = lsu_op_ls1 == `LLSU_AMSWAP_W    || lsu_op_ls1 == `LLSU_AMADD_W     ||
	              lsu_op_ls1 == `LLSU_AMAND_W     || lsu_op_ls1 == `LLSU_AMOR_W      ||
	              lsu_op_ls1 == `LLSU_AMXOR_W     || lsu_op_ls1 == `LLSU_AMMAX_W     ||
	              lsu_op_ls1 == `LLSU_AMMIN_W     || lsu_op_ls1 == `LLSU_AMMAX_WU    ||
	              lsu_op_ls1 == `LLSU_AMMIN_WU    || lsu_op_ls1 == `LLSU_AMSWAP_DB_W ||
	              lsu_op_ls1 == `LLSU_AMADD_DB_W  || lsu_op_ls1 == `LLSU_AMAND_DB_W  ||
	              lsu_op_ls1 == `LLSU_AMOR_DB_W   || lsu_op_ls1 == `LLSU_AMXOR_DB_W  ||
	              lsu_op_ls1 == `LLSU_AMMAX_DB_W  || lsu_op_ls1 == `LLSU_AMMIN_DB_W  ||
	              lsu_op_ls1 == `LLSU_AMMAX_DB_WU || lsu_op_ls1 == `LLSU_AMMIN_DB_WU ;

   wire lsu_am_ld   = lsu_op_ls1 == `LLSU_AMSWAP_D    || lsu_op_ls1 == `LLSU_AMADD_D     ||
	              lsu_op_ls1 == `LLSU_AMAND_D     || lsu_op_ls1 == `LLSU_AMOR_D      ||
	              lsu_op_ls1 == `LLSU_AMXOR_D     || lsu_op_ls1 == `LLSU_AMMAX_D     ||
	              lsu_op_ls1 == `LLSU_AMMIN_D     || lsu_op_ls1 == `LLSU_AMMAX_DU    ||
	              lsu_op_ls1 == `LLSU_AMMIN_DU    || lsu_op_ls1 == `LLSU_AMSWAP_DB_D ||
	              lsu_op_ls1 == `LLSU_AMADD_DB_D  || lsu_op_ls1 == `LLSU_AMAND_DB_D  ||
	              lsu_op_ls1 == `LLSU_AMOR_DB_D   || lsu_op_ls1 == `LLSU_AMXOR_DB_D  ||
	              lsu_op_ls1 == `LLSU_AMMAX_DB_D  || lsu_op_ls1 == `LLSU_AMMIN_DB_D  ||
	              lsu_op_ls1 == `LLSU_AMMAX_DB_DU || lsu_op_ls1 == `LLSU_AMMIN_DB_DU ;

   wire lsu_am_sw   = lsu_op_ls1 == `LLSU_AMSWAP_W    || lsu_op_ls1 == `LLSU_AMADD_W     ||
	              lsu_op_ls1 == `LLSU_AMAND_W     || lsu_op_ls1 == `LLSU_AMOR_W      ||
	              lsu_op_ls1 == `LLSU_AMXOR_W     || lsu_op_ls1 == `LLSU_AMMAX_W     ||
	              lsu_op_ls1 == `LLSU_AMMIN_W     || lsu_op_ls1 == `LLSU_AMMAX_WU    ||
	              lsu_op_ls1 == `LLSU_AMMIN_WU    || lsu_op_ls1 == `LLSU_AMSWAP_DB_W ||
	              lsu_op_ls1 == `LLSU_AMADD_DB_W  || lsu_op_ls1 == `LLSU_AMAND_DB_W  ||
	              lsu_op_ls1 == `LLSU_AMOR_DB_W   || lsu_op_ls1 == `LLSU_AMXOR_DB_W  ||
	              lsu_op_ls1 == `LLSU_AMMAX_DB_W  || lsu_op_ls1 == `LLSU_AMMIN_DB_W  ||
	              lsu_op_ls1 == `LLSU_AMMAX_DB_WU || lsu_op_ls1 == `LLSU_AMMIN_DB_WU ;

   wire lsu_am_sd   = lsu_op_ls1 == `LLSU_AMSWAP_D    || lsu_op_ls1 == `LLSU_AMADD_D     ||
	              lsu_op_ls1 == `LLSU_AMAND_D     || lsu_op_ls1 == `LLSU_AMOR_D      ||
	              lsu_op_ls1 == `LLSU_AMXOR_D     || lsu_op_ls1 == `LLSU_AMMAX_D     ||
	              lsu_op_ls1 == `LLSU_AMMIN_D     || lsu_op_ls1 == `LLSU_AMMAX_DU    ||
	              lsu_op_ls1 == `LLSU_AMMIN_DU    || lsu_op_ls1 == `LLSU_AMSWAP_DB_D ||
	              lsu_op_ls1 == `LLSU_AMADD_DB_D  || lsu_op_ls1 == `LLSU_AMAND_DB_D  ||
	              lsu_op_ls1 == `LLSU_AMOR_DB_D   || lsu_op_ls1 == `LLSU_AMXOR_DB_D  ||
	              lsu_op_ls1 == `LLSU_AMMAX_DB_D  || lsu_op_ls1 == `LLSU_AMMIN_DB_D  ||
	              lsu_op_ls1 == `LLSU_AMMAX_DB_DU || lsu_op_ls1 == `LLSU_AMMIN_DB_DU ;

   wire lsu_llw     = lsu_op_ls1 == `LLSU_LL_W;
   wire lsu_lld     = lsu_op_ls1 == `LLSU_LL_D;
   wire lsu_scw     = lsu_op_ls1 == `LLSU_SC_W;
   wire lsu_scd     = lsu_op_ls1 == `LLSU_SC_D;

   wire lsu_lw      = lsu_op_ls1 == `LLSU_LD_W  || lsu_op_ls1 == `LLSU_LDX_W  || lsu_op_ls1 == `LLSU_LDGT_W || lsu_op_ls1 == `LLSU_LDLE_W || lsu_op_ls1 == `LLSU_IOCSRRD_W;
   wire lsu_lwu     = lsu_op_ls1 == `LLSU_LD_WU || lsu_op_ls1 == `LLSU_LDX_WU ;
   wire lsu_sw      = lsu_op_ls1 == `LLSU_ST_W  || lsu_op_ls1 == `LLSU_STX_W  || lsu_op_ls1 == `LLSU_STGT_W || lsu_op_ls1 == `LLSU_STLE_W || lsu_op_ls1 == `LLSU_IOCSRWR_W ||
                      lsu_am_sw;
   wire lsu_lb      = lsu_op_ls1 == `LLSU_LD_B  || lsu_op_ls1 == `LLSU_LDX_B  || lsu_op_ls1 == `LLSU_LDGT_B || lsu_op_ls1 == `LLSU_LDLE_B || lsu_op_ls1 == `LLSU_IOCSRRD_B ||
                      lsu_op_ls1 == `LLSU_PRELD || lsu_op_ls1 == `LLSU_PRELDX ;
   wire lsu_lbu     = lsu_op_ls1 == `LLSU_LD_BU || lsu_op_ls1 == `LLSU_LDX_BU ;
   wire lsu_lh      = lsu_op_ls1 == `LLSU_LD_H  || lsu_op_ls1 == `LLSU_LDX_H  || lsu_op_ls1 == `LLSU_LDGT_H || lsu_op_ls1 == `LLSU_LDLE_H || lsu_op_ls1 == `LLSU_IOCSRRD_H;
   wire lsu_ld      = lsu_op_ls1 == `LLSU_LD_D  || lsu_op_ls1 == `LLSU_LDX_D  || lsu_op_ls1 == `LLSU_LDGT_D || lsu_op_ls1 == `LLSU_LDLE_D || lsu_op_ls1 == `LLSU_IOCSRRD_D;
   wire lsu_lhu     = lsu_op_ls1 == `LLSU_LD_HU || lsu_op_ls1 == `LLSU_LDX_HU ;
   wire lsu_sb      = lsu_op_ls1 == `LLSU_ST_B  || lsu_op_ls1 == `LLSU_STX_B  || lsu_op_ls1 == `LLSU_STGT_B || lsu_op_ls1 == `LLSU_STLE_B || lsu_op_ls1 == `LLSU_IOCSRWR_B;
   wire lsu_sh      = lsu_op_ls1 == `LLSU_ST_H  || lsu_op_ls1 == `LLSU_STX_H  || lsu_op_ls1 == `LLSU_STGT_H || lsu_op_ls1 == `LLSU_STLE_H || lsu_op_ls1 == `LLSU_IOCSRWR_H;
   wire lsu_sd      = lsu_op_ls1 == `LLSU_ST_D  || lsu_op_ls1 == `LLSU_STX_D  || lsu_op_ls1 == `LLSU_STGT_D || lsu_op_ls1 == `LLSU_STLE_D || lsu_op_ls1 == `LLSU_IOCSRWR_D ||
                      lsu_am_sd;   


   wire lsu_gt      = lsu_op_ls1 == `LLSU_LDGT_W || lsu_op_ls1 == `LLSU_LDGT_B || lsu_op_ls1 == `LLSU_LDGT_H || lsu_op_ls1 == `LLSU_LDGT_D ||
                      lsu_op_ls1 == `LLSU_STGT_W || lsu_op_ls1 == `LLSU_STGT_B || lsu_op_ls1 == `LLSU_STGT_H || lsu_op_ls1 == `LLSU_STGT_D ;
   wire lsu_le      = lsu_op_ls1 == `LLSU_LDLE_W || lsu_op_ls1 == `LLSU_LDLE_B || lsu_op_ls1 == `LLSU_LDLE_H || lsu_op_ls1 == `LLSU_LDLE_D ||
                      lsu_op_ls1 == `LLSU_STLE_W || lsu_op_ls1 == `LLSU_STLE_B || lsu_op_ls1 == `LLSU_STLE_H || lsu_op_ls1 == `LLSU_STLE_D ;
   wire lsu_idle    = lsu_op_ls1 == `LLSU_IDLE;

   wire prefetch    = lsu_op_ls1 == `LLSU_PRELD || lsu_op_ls1 == `LLSU_PRELDX;


   //wire lsu_wr      = lsu_sw || lsu_sb || lsu_sh || lsu_scw || lsu_scd || lsu_sd;
   wire lsu_load_ls1  = lsu_ld || lsu_lw || lsu_llw || lsu_lld || lsu_lb  || lsu_lbu || lsu_lh || lsu_lhu || lsu_lbu || lsu_lwu;
   wire lsu_store_ls1 = lsu_sb || lsu_sh || lsu_sd  || lsu_sw  || lsu_scw || lsu_scd;

   wire lsu_load_ls2;
   wire lsu_store_ls2;



  assign lsu_wstrb_ls1    = {4{lsu_sw||lsu_scw}} & (4'b1111              ) |
                            {4{lsu_sh         }} & (4'b0011 << lsu_shift_ls1[1:0]) |
                            {4{lsu_sb         }} & (4'b0001 << lsu_shift_ls1[1:0]) ;

   assign lsu_wdata_ls1   = {32{lsu_sw||lsu_scw}} & {lsu_wdata_raw_ls1[31:0]} |
                            {32{lsu_sh         }} & {lsu_wdata_raw_ls1[15:0], lsu_wdata_raw_ls1[15:0]} |
                            {32{lsu_sb         }} & {lsu_wdata_raw_ls1[ 7:0], lsu_wdata_raw_ls1[7:0], lsu_wdata_raw_ls1[7:0], lsu_wdata_raw_ls1[7:0]};



   // address alignment exception, trigger pipeline abort
   wire am_addr_align_exc = (lsu_am_lw || lsu_am_sw || lsu_llw || lsu_scw) && lsu_addr_ls1[1:0] != 2'd0 ||
	                    (lsu_am_ld || lsu_am_sd || lsu_lld || lsu_scd) && lsu_addr_ls1[2:0] != 3'd0 ;

   wire cm_addr_align_exc = (lsu_ld||lsu_sd         ) && lsu_addr_ls1[2:0] != 3'd0 ||
                            (lsu_lw||lsu_lwu||lsu_sw) && lsu_addr_ls1[1:0] != 2'd0 ||
                            (lsu_lh||lsu_lhu||lsu_sh) && lsu_addr_ls1[0]   != 1'd0 ;

   wire lsu_ale_ls1               = am_addr_align_exc || cm_addr_align_exc;

   assign lsu_ecl_except_ale_ls1  = lsu_ale_ls1 & lsu_valid_ls1;
   assign lsu_csr_except_badv_ls1 = lsu_addr_ls1;


   //
   // BIU read request
   //
   
   // lsu_valid_ls2 & lsu_load_ls2        : _-_____
   // biu_lsu_rd_ack_ls2                  : _____-_
   //
   // biu_rd_req_in                       : _----__
   // biu_rd_req_q                        : __----_

   wire biu_rd_req_in;
   wire biu_rd_req_q;

   assign biu_rd_req_in = (biu_rd_req_q & ~biu_lsu_rd_ack_ls2) | (lsu_valid_ls2 & lsu_load_ls2);

   dffrl_s #(1) biu_rd_req_reg (
      .din   (biu_rd_req_in),
      .clk   (clk),
      .rst_l (resetn),
      .q     (biu_rd_req_q),
      .se(), .si(), .so());

   assign lsu_biu_rd_req = biu_rd_req_in;

   assign lsu_biu_rd_addr = {lsu_addr_ls2[31:3], 3'b000}; // 64-bit align

   //
   // BIU write request 
   //

   // lsu_valid_ls2 & lsu_store_ls2       : _-_____
   // biu_lsu_wr_ack_ls2                  : _____-_
   //
   // biu_wr_req_in                       : _----__
   // biu_wr_red_q                        : __----_
   
   wire biu_wr_req_in;
   wire biu_wr_req_q;

   assign biu_wr_req_in = (biu_wr_req_q & ~biu_lsu_wr_ack_ls2) | (lsu_valid_ls2 & lsu_store_ls2);

   dffrl_s #(1) biu_wr_req_reg (
      .din   (biu_wr_req_in),
      .clk   (clk),
      .rst_l (resetn),
      .q     (biu_wr_req_q),
      .se(), .si(), .so());

   assign lsu_biu_wr_req_ls2 = biu_wr_req_in;

   assign lsu_biu_wr_addr_ls2 = {lsu_addr_ls2[31:3], 3'b000}; // 64-bit align



   wire lsu_wr_high32_ls2 = lsu_addr_ls2[2];
   assign lsu_biu_wr_data_ls2 = lsu_wr_high32_ls2 ? {lsu_wdata_ls2, 32'b0} : {32'b0, lsu_wdata_ls2};
   assign lsu_biu_wr_strb_ls2 = lsu_wr_high32_ls2 ? {lsu_wstrb_ls2, 4'b0} : {4'b0, lsu_wstrb_ls2};


   //
   // Process data received from BIU 
   //

   wire data_high32_ls3 = lsu_addr_ls3[2];

   wire [31:0] data_rdata_input_ls3 = data_high32_ls3 ? biu_lsu_data_ls3[63:32] : biu_lsu_data_ls3[31:0];


   wire [4:0] lsu_align_mode_ls1;
   wire [4:0] lsu_align_mode_ls2;
   wire [4:0] lsu_align_mode_ls3;

   assign lsu_align_mode_ls1[0] = !(lsu_scw || lsu_scd) && (lsu_ld ||lsu_lld);
   assign lsu_align_mode_ls1[1] = !(lsu_scw || lsu_scd) && (lsu_lw ||lsu_llw||lsu_lwu);
   assign lsu_align_mode_ls1[2] = !(lsu_scw || lsu_scd) && (lsu_lh ||lsu_lhu);
   assign lsu_align_mode_ls1[3] = !(lsu_scw || lsu_scd) && (lsu_lb ||lsu_lbu);
   assign lsu_align_mode_ls1[4] = !(lsu_scw || lsu_scd) && (lsu_lbu||lsu_lhu||lsu_lwu);


   wire [31:0] lsu_align_res_ls3 = 
	   ({32{lsu_shift_ls3[1:0] == 2'b00 && !lsu_align_mode_ls3[4] && lsu_align_mode_ls3[3]}} & {{24{data_rdata_input_ls3[ 7]}},data_rdata_input_ls3[ 7: 0]}) | // ld.b
	   ({32{lsu_shift_ls3[1:0] == 2'b01 && !lsu_align_mode_ls3[4] && lsu_align_mode_ls3[3]}} & {{24{data_rdata_input_ls3[15]}},data_rdata_input_ls3[15: 8]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b10 && !lsu_align_mode_ls3[4] && lsu_align_mode_ls3[3]}} & {{24{data_rdata_input_ls3[23]}},data_rdata_input_ls3[23:16]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b11 && !lsu_align_mode_ls3[4] && lsu_align_mode_ls3[3]}} & {{24{data_rdata_input_ls3[31]}},data_rdata_input_ls3[31:24]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b00 &&  lsu_align_mode_ls3[4] && lsu_align_mode_ls3[3]}} & {24'd0,data_rdata_input_ls3[ 7: 0]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b01 &&  lsu_align_mode_ls3[4] && lsu_align_mode_ls3[3]}} & {24'd0,data_rdata_input_ls3[15: 8]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b10 &&  lsu_align_mode_ls3[4] && lsu_align_mode_ls3[3]}} & {24'd0,data_rdata_input_ls3[23:16]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b11 &&  lsu_align_mode_ls3[4] && lsu_align_mode_ls3[3]}} & {24'd0,data_rdata_input_ls3[31:24]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b00 && !lsu_align_mode_ls3[4] && lsu_align_mode_ls3[2]}} & {{16{data_rdata_input_ls3[15]}},data_rdata_input_ls3[15: 0]}) | // ld.h
	   ({32{lsu_shift_ls3[1:0] == 2'b10 && !lsu_align_mode_ls3[4] && lsu_align_mode_ls3[2]}} & {{16{data_rdata_input_ls3[31]}},data_rdata_input_ls3[31:16]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b00 &&  lsu_align_mode_ls3[4] && lsu_align_mode_ls3[2]}} & {16'd0,data_rdata_input_ls3[15: 0]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b10 &&  lsu_align_mode_ls3[4] && lsu_align_mode_ls3[2]}} & {16'd0,data_rdata_input_ls3[31:16]}) |
	   ({32{lsu_shift_ls3[1:0] == 2'b00 && !lsu_align_mode_ls3[4] && lsu_align_mode_ls3[1]}} & data_rdata_input_ls3[31: 0]) | // ld.w|
	   ({32{lsu_shift_ls3[1:0] == 2'b00 &&  lsu_align_mode_ls3[4] && lsu_align_mode_ls3[1]}} & data_rdata_input_ls3[31: 0]) |
	   //({32{!lsu_align_mode_ls3[4] && !lsu_align_mode_ls3[3] && !lsu_align_mode_ls3[2] && !lsu_align_mode_ls3[1]}} & {31'd0,data_scsucceed}) ; // data_scsucceed = 1'b1
	   ({32{!lsu_align_mode_ls3[4] && !lsu_align_mode_ls3[3] && !lsu_align_mode_ls3[2] && !lsu_align_mode_ls3[1]}} & {31'd0, 1'b1}) ; // data_scsucceed = 1'b1

   assign lsu_ecl_data_ls3 = lsu_align_res_ls3;
   assign lsu_ecl_data_valid_ls3 = biu_lsu_data_valid_ls3;


   //
   // registers
   //

   // The signal lsu_valid_ls1 initiates load/store execution within the LSU.
   // The ECL interface signals are pulsed for a single cycle by ECL and must
   // be captured internally by the LSU to maitain the request state. The LSU
   // is always ready to accept the request for this in-order core.
   //
   // The signal lsu_valid_ls1 is cleared and refreshed after a request is
   // served (by BIU, STB, or DCACHE) or aborted (e.g., due to an ALE in ls1).
   dffrl_s #(1) lsu_valid_ls1_reg (
      .din (ecl_lsu_valid_e),
      // lsu_ecl_except_buserr_ls3 lsu_ecl_except_ecc_ls3 should also go here 
      //.en  (ecl_lsu_valid_e | lsu_ecl_data_valid_ls3 | lsu_ale_ls1),
      .clk (clk),
      .rst_l (resetn),
      .q   (lsu_valid_ls1),
      .se(), .si(), .so());

   dffrl_s #(1) lsu_valid_ls2_reg (
      .din (lsu_valid_ls1),
      .clk (clk),
      .rst_l (resetn),
      .q   (lsu_valid_ls2),
      .se(), .si(), .so());

   // lsu_valid_ls3 
  

   dffe_s #(7) lsu_op_ls1_reg (
      .din (ecl_lsu_op_e),
      .en  (ecl_lsu_valid_e),
      .clk (clk),
      .q   (lsu_op_ls1),
      .se(), .si(), .so());

   dffe_s #(32) lsu_base_ls1_reg (
      .din (ecl_lsu_base_e),
      .en  (ecl_lsu_valid_e),
      .clk (clk),
      .q   (lsu_base_ls1),
      .se(), .si(), .so());

   dffe_s #(32) lsu_offset_ls1_reg (
      .din (ecl_lsu_offset_e),
      .en  (ecl_lsu_valid_e),
      .clk (clk),
      .q   (lsu_offset_ls1),
      .se(), .si(), .so());

   dffe_s #(32) lsu_wdata_raw_ls1_reg (
      .din (ecl_lsu_wdata_e),
      .en  (ecl_lsu_valid_e),
      .clk (clk),
      .q   (lsu_wdata_raw_ls1),
      .se(), .si(), .so());

   dff_s #(32) lsu_wdata_ls2_reg (
      .din (lsu_wdata_ls1),
      .clk (clk),
      .q   (lsu_wdata_ls2),
      .se(), .si(), .so());

   dff_s #(8) lsu_wstrb_ls2_reg (
      .din (lsu_wstrb_ls1),
      .clk (clk),
      .q   (lsu_wstrb_ls2),
      .se(), .si(), .so());

   // The load instruction's destination register and wen should not be
   // managed by the LSU.
   // There is no reservation station or other structure in the design to hold
   // the rd field for loads.
   // Instead, because the in-order core will stall on a load instruction, the
   // rd information must be preserved within the EXU.
   //dffe_s #(5) ecl_lsu_rd_ls1_reg (
   //   .din (ecl_lsu_rd_e),
   //   .en  (ecl_lsu_valid_e),
   //   .clk (clk),
   //   .q   (lsu_rd_ls1),
   //   .se(), .si(), .so());

   //dffe_s #(1) ecl_lsu_wen_ls1_reg (
   //   .din (ecl_lsu_wen_e),
   //   .en  (ecl_lsu_valid_e),
   //   .clk (clk),
   //   .q   (lsu_wen_ls1),
   //   .se(), .si(), .so());

   // The LSU pipeline begins when ecl_lsu_valid_e is asserted, and the core
   // remains stalled until the LSU returns a result.
   // The stage registers(_ls1, _ls2, _ls3) do not require explicit enable
   // signals because the data flows sequentially between them. Since the core
   // is stalled for the core is stalled for the duration of this pipeline,
   // the register values are preserved.
   dff_s #(5) lsu_align_mode_ls2_reg (
      .din (lsu_align_mode_ls1),
      .clk (clk),
      .q   (lsu_align_mode_ls2),
      .se(), .si(), .so());

   dff_s #(5) lsu_align_mode_ls3_reg (
      .din (lsu_align_mode_ls2),
      .clk (clk),
      .q   (lsu_align_mode_ls3),
      .se(), .si(), .so());

   dff_s #(3) lsu_shift_ls2_reg (
      .din (lsu_shift_ls1),
      .clk (clk),
      .q   (lsu_shift_ls2),
      .se(), .si(), .so());

   dff_s #(3) lsu_shift_ls3_reg (
      .din (lsu_shift_ls2),
      .clk (clk),
      .q   (lsu_shift_ls3),
      .se(), .si(), .so());

   dff_s #(1) lsu_load_ls2_reg (
      .din (lsu_load_ls1),
      .clk (clk),
      .q   (lsu_load_ls2),
      .se(), .si(), .so());

   dff_s #(1) lsu_store_ls2_reg (
      .din (lsu_store_ls1),
      .clk (clk),
      .q   (lsu_store_ls2),
      .se(), .si(), .so());

   dff_s #(32) lsu_addr_ls2_reg (
      .din (lsu_addr_ls1),
      .clk (clk),
      .q   (lsu_addr_ls2),
      .se(), .si(), .so());

   dff_s #(32) lsu_addr_ls3_reg (
      .din (lsu_addr_ls2),
      .clk (clk),
      .q   (lsu_addr_ls3),
      .se(), .si(), .so());

   // Note: The pipeline registers _ls2 and _ls3 are functionally redundant.
   // Because the core stalls for load/store instructions, resuling in only
   // one request processing through the pipeline at a time. These registers
   // therefore simply duplicate the value in _ls1. They are kept in the
   // design for clarity and to maintain flexibility for future modifications.


   // Unimplmented signals
   assign lsu_ecl_except_buserr_ls3 = 1'b0;
   assign lsu_ecl_except_ecc_ls3 = 1'b0;

endmodule
