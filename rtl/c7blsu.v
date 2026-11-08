`include "c7blsu_defs.v"

//
// The ECL interface signals are pulsed for a single cycle by ECL and must
// be captured internally by the LSU to maitain the request state. The LSU
// is always ready to accept the request for this in-order core.
//

// The ecl_lsu_valid_e signal is registered through the pipeline stages as
// lsu_valid_ls1 and lsu_valid_ls2. The DTLB is searched in LS1 and returns
// its result in LS2, where lsu_valid_ls2 triggers a BIU request
// (lsu_biu_rd_req_ls2 / lsu_biu_wr_req_ls2), which remains asserted until
// acknowleged by the BIU. E-stage work (address, decode, ALE, LL/SC, barriers)
// uses the _e wires. See the "registers" section for the stage summary.
//
// Note: Currently, both load and store requests are issued at LS2. A future
// revision may defer loads to LS3, where they first check the Store Buffer
// before proceeding to the BIU.

module c7blsu(
   input              clk,
   input              resetn,

   //--------------------------------------------------
   // ECL Interface
   //--------------------------------------------------
   
   input              ecl_lsu_valid_e,
   input              ecl_lsu_ibar_e,
   input              ecl_lsu_dbar_e,
   input  [6:0]       ecl_lsu_op_e,
   input  [31:0]      ecl_lsu_base_e,
   input  [31:0]      ecl_lsu_offset_e,
   input  [31:0]      ecl_lsu_wdata_e,

   output             lsu_ecl_data_valid_ls3,
   output [31:0]      lsu_ecl_data_ls3,

   output             lsu_ecl_wr_fin_ls3,
   // Exceptions: ale, bus error, ECC, tlb refill
   // ALE is detected in E, from the E-stage address
   output             lsu_ecl_except_ale_e,
   output [31:0]      lsu_ecl_except_ale_badv_e,
   output             lsu_ecl_except_buserr_ls3,
   output             lsu_ecl_except_ecc_ls3,
   output [31:0]      lsu_ecl_except_buserr_badv_ls3,
   output             lsu_ecl_except_tlbr_ls2,
   output [31:0]      lsu_ecl_except_tlbr_badv_ls2,
   output             lsu_except_pil_ls2,
   output [31:0]      lsu_except_pil_badv_ls2,
   output             lsu_except_pis_ls2,
   output [31:0]      lsu_except_pis_badv_ls2,
   output             lsu_except_ppi_ls2,
   output [31:0]      lsu_except_ppi_badv_ls2,
   output             lsu_except_pme_ls2,
   output [31:0]      lsu_except_pme_badv_ls2,

   // ibar/dbar/sc finish in E
   output             lsu_ecl_ibar_fin_e,
   output             lsu_ecl_dbar_fin_e,
   output             lsu_ecl_sc_fin_e,

   output             lsu_sc,
   // LLBit set by LL.W / cleared by SC.W, in E
   output             lsu_csr_llb_set_e,
   output             lsu_csr_llb_clr_e,

   input              csr_lsu_llb,

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
   output             lsu_biu_rd_req_ls2,
   output [31:0]      lsu_biu_rd_addr_ls2,
   input              biu_lsu_rd_ack_ls2,
   input              biu_lsu_data_valid_ls3,
   input  [63:0]      biu_lsu_data_ls3,
   input              biu_lsu_fault_ls3,
   input  [1:0]       biu_lsu_fault_code_ls3,

   // BIU wr
   output             lsu_biu_wr_req_ls2,
   output [31:0]      lsu_biu_wr_addr_ls2,
   output [63:0]      lsu_biu_wr_data_ls2,
   output [7:0]       lsu_biu_wr_strb_ls2,

   input              biu_lsu_wr_ack_ls2,
   input              biu_lsu_wr_fin_ls3,
   input              biu_lsu_wr_fault_ls3,
   input  [1:0]       biu_lsu_wr_fault_code_ls3,

   input              csr_lsu_crmd_da, 
   input              csr_lsu_crmd_pg,

   input  [2:0]       csr_lsu_dmw0_pseg,
   input  [2:0]       csr_lsu_dmw0_vseg,

   input  [2:0]       csr_lsu_dmw1_pseg,
   input  [2:0]       csr_lsu_dmw1_vseg,

   input  [18:0]      csr_dtlb_tlbehi_vppn,

   input              csr_dtlb_tlbidx_ne,
   input  [5:0]       csr_dtlb_tlbidx_ps,
   input              csr_dtlb_tlbidx_i_d,
   input  [4:0]       csr_dtlb_tlbidx_index,

   input  [19:0]      csr_dtlb_tlbelo0_ppn,
   input              csr_dtlb_tlbelo0_g,
   input  [1:0]       csr_dtlb_tlbelo0_mat,
   input  [1:0]       csr_dtlb_tlbelo0_plv,
   input              csr_dtlb_tlbelo0_d,
   input              csr_dtlb_tlbelo0_v,

   input  [19:0]      csr_dtlb_tlbelo1_ppn,
   input              csr_dtlb_tlbelo1_g,
   input  [1:0]       csr_dtlb_tlbelo1_mat,
   input  [1:0]       csr_dtlb_tlbelo1_plv,
   input              csr_dtlb_tlbelo1_d,
   input              csr_dtlb_tlbelo1_v,
   input  [9:0]       csr_dtlb_asid_asid, 

   input              csr_dtlb_tlbrefill_ctx, 
   input  [1:0]       csr_dtlb_crmd_plv, 

   input  [4:0]       exu_dtlb_random_index, 

   input              csr_dtlb_tlbfill_vld_e, 
   input              csr_dtlb_tlbwr_vld_e,
   input              exu_dtlb_tlbsrch_vld_e, 
   input              exu_dtlb_tlbsrch_vld_m, 
   input              exu_dtlb_invtlb_vld_e,

   input  [4:0]       exu_dtlb_invtlb_op_e,
   input  [9:0]       exu_dtlb_invtlb_asid_e,
   input  [18:0]      exu_dtlb_invtlb_vppn_e,

   // dtlb to csr
   output [4:0]       dtlb_csr_tlbidx_index,
   output [18:0]      dtlb_csr_tlbehi_vppn,
   output             dtlb_csr_tlbelo_g,
   output [5:0]       dtlb_csr_tlbidx_ps,
   output             dtlb_csr_tlbidx_e,
   output             dtlb_csr_tlbelo0_v,
   output             dtlb_csr_tlbelo0_d,
   output [1:0]       dtlb_csr_tlbelo0_mat,
   output [1:0]       dtlb_csr_tlbelo0_plv,
   output [19:0]      dtlb_csr_tlbelo0_ppn,
   output             dtlb_csr_tlbelo1_v,
   output             dtlb_csr_tlbelo1_d,
   output [1:0]       dtlb_csr_tlbelo1_mat,
   output [1:0]       dtlb_csr_tlbelo1_plv,
   output [19:0]      dtlb_csr_tlbelo1_ppn,
   output [9:0]       dtlb_csr_asid_asid 
);

   wire da_mode = csr_lsu_crmd_da;
   wire pg_mode = ~csr_lsu_crmd_da & csr_lsu_crmd_pg;

   wire match_dmw0_ls1;
   wire match_dmw1_ls1;

   wire match_dmw0_ls2;
   wire match_dmw1_ls2;

   wire               lsu_valid_e;
   wire               lsu_valid_ls1;
   wire               lsu_valid_ls2;
   wire [6:0]         lsu_op_e;
   wire [31:0]        lsu_wdata_e;
   wire [31:0]        lsu_wdata_ls1;
   wire [31:0]        lsu_wdata_ls2;
   wire [3:0]         lsu_wstrb_e;
   wire [3:0]         lsu_wstrb_ls1;
   wire [3:0]         lsu_wstrb_ls2;

   wire [31:0]        lsu_addr_e   = ecl_lsu_base_e + ecl_lsu_offset_e;
   wire [ 2:0]        lsu_shift_e  = lsu_addr_e[2:0];
   wire [ 2:0]        lsu_shift_ls1;
   wire [ 2:0]        lsu_shift_ls2;
   wire [ 2:0]        lsu_shift_ls3;

   wire [31:0]        lsu_addr_ls1;
   wire [31:0]        lsu_addr_ls2;
   wire [31:0]        lsu_addr_ls3;

   wire [31:0]        lsu_paddr_ls2;


   wire lsu_dbar_e = ecl_lsu_dbar_e;
   wire lsu_ibar_e = ecl_lsu_ibar_e;

   wire lsu_scw_q; // record whether this is a scw instrution for later use

   // decode atomic op
   wire lsu_am_lw   = lsu_op_e == `LLSU_AMSWAP_W    || lsu_op_e == `LLSU_AMADD_W     ||
	              lsu_op_e == `LLSU_AMAND_W     || lsu_op_e == `LLSU_AMOR_W      ||
	              lsu_op_e == `LLSU_AMXOR_W     || lsu_op_e == `LLSU_AMMAX_W     ||
	              lsu_op_e == `LLSU_AMMIN_W     || lsu_op_e == `LLSU_AMMAX_WU    ||
	              lsu_op_e == `LLSU_AMMIN_WU    || lsu_op_e == `LLSU_AMSWAP_DB_W ||
	              lsu_op_e == `LLSU_AMADD_DB_W  || lsu_op_e == `LLSU_AMAND_DB_W  ||
	              lsu_op_e == `LLSU_AMOR_DB_W   || lsu_op_e == `LLSU_AMXOR_DB_W  ||
	              lsu_op_e == `LLSU_AMMAX_DB_W  || lsu_op_e == `LLSU_AMMIN_DB_W  ||
	              lsu_op_e == `LLSU_AMMAX_DB_WU || lsu_op_e == `LLSU_AMMIN_DB_WU ;

   wire lsu_am_ld   = lsu_op_e == `LLSU_AMSWAP_D    || lsu_op_e == `LLSU_AMADD_D     ||
	              lsu_op_e == `LLSU_AMAND_D     || lsu_op_e == `LLSU_AMOR_D      ||
	              lsu_op_e == `LLSU_AMXOR_D     || lsu_op_e == `LLSU_AMMAX_D     ||
	              lsu_op_e == `LLSU_AMMIN_D     || lsu_op_e == `LLSU_AMMAX_DU    ||
	              lsu_op_e == `LLSU_AMMIN_DU    || lsu_op_e == `LLSU_AMSWAP_DB_D ||
	              lsu_op_e == `LLSU_AMADD_DB_D  || lsu_op_e == `LLSU_AMAND_DB_D  ||
	              lsu_op_e == `LLSU_AMOR_DB_D   || lsu_op_e == `LLSU_AMXOR_DB_D  ||
	              lsu_op_e == `LLSU_AMMAX_DB_D  || lsu_op_e == `LLSU_AMMIN_DB_D  ||
	              lsu_op_e == `LLSU_AMMAX_DB_DU || lsu_op_e == `LLSU_AMMIN_DB_DU ;

   wire lsu_am_sw   = lsu_op_e == `LLSU_AMSWAP_W    || lsu_op_e == `LLSU_AMADD_W     ||
	              lsu_op_e == `LLSU_AMAND_W     || lsu_op_e == `LLSU_AMOR_W      ||
	              lsu_op_e == `LLSU_AMXOR_W     || lsu_op_e == `LLSU_AMMAX_W     ||
	              lsu_op_e == `LLSU_AMMIN_W     || lsu_op_e == `LLSU_AMMAX_WU    ||
	              lsu_op_e == `LLSU_AMMIN_WU    || lsu_op_e == `LLSU_AMSWAP_DB_W ||
	              lsu_op_e == `LLSU_AMADD_DB_W  || lsu_op_e == `LLSU_AMAND_DB_W  ||
	              lsu_op_e == `LLSU_AMOR_DB_W   || lsu_op_e == `LLSU_AMXOR_DB_W  ||
	              lsu_op_e == `LLSU_AMMAX_DB_W  || lsu_op_e == `LLSU_AMMIN_DB_W  ||
	              lsu_op_e == `LLSU_AMMAX_DB_WU || lsu_op_e == `LLSU_AMMIN_DB_WU ;

   wire lsu_am_sd   = lsu_op_e == `LLSU_AMSWAP_D    || lsu_op_e == `LLSU_AMADD_D     ||
	              lsu_op_e == `LLSU_AMAND_D     || lsu_op_e == `LLSU_AMOR_D      ||
	              lsu_op_e == `LLSU_AMXOR_D     || lsu_op_e == `LLSU_AMMAX_D     ||
	              lsu_op_e == `LLSU_AMMIN_D     || lsu_op_e == `LLSU_AMMAX_DU    ||
	              lsu_op_e == `LLSU_AMMIN_DU    || lsu_op_e == `LLSU_AMSWAP_DB_D ||
	              lsu_op_e == `LLSU_AMADD_DB_D  || lsu_op_e == `LLSU_AMAND_DB_D  ||
	              lsu_op_e == `LLSU_AMOR_DB_D   || lsu_op_e == `LLSU_AMXOR_DB_D  ||
	              lsu_op_e == `LLSU_AMMAX_DB_D  || lsu_op_e == `LLSU_AMMIN_DB_D  ||
	              lsu_op_e == `LLSU_AMMAX_DB_DU || lsu_op_e == `LLSU_AMMIN_DB_DU ;

   wire lsu_llw     = lsu_op_e == `LLSU_LL_W;
   wire lsu_lld     = lsu_op_e == `LLSU_LL_D;
   wire lsu_scw     = lsu_op_e == `LLSU_SC_W;
   wire lsu_scd     = lsu_op_e == `LLSU_SC_D;

   wire lsu_lw      = lsu_op_e == `LLSU_LD_W  || lsu_op_e == `LLSU_LDX_W  || lsu_op_e == `LLSU_LDGT_W || lsu_op_e == `LLSU_LDLE_W || lsu_op_e == `LLSU_IOCSRRD_W;
   wire lsu_lwu     = lsu_op_e == `LLSU_LD_WU || lsu_op_e == `LLSU_LDX_WU ;
   wire lsu_sw      = lsu_op_e == `LLSU_ST_W  || lsu_op_e == `LLSU_STX_W  || lsu_op_e == `LLSU_STGT_W || lsu_op_e == `LLSU_STLE_W || lsu_op_e == `LLSU_IOCSRWR_W ||
                      lsu_am_sw;
   wire lsu_lb      = lsu_op_e == `LLSU_LD_B  || lsu_op_e == `LLSU_LDX_B  || lsu_op_e == `LLSU_LDGT_B || lsu_op_e == `LLSU_LDLE_B || lsu_op_e == `LLSU_IOCSRRD_B ||
                      lsu_op_e == `LLSU_PRELD || lsu_op_e == `LLSU_PRELDX ;
   wire lsu_lbu     = lsu_op_e == `LLSU_LD_BU || lsu_op_e == `LLSU_LDX_BU ;
   wire lsu_lh      = lsu_op_e == `LLSU_LD_H  || lsu_op_e == `LLSU_LDX_H  || lsu_op_e == `LLSU_LDGT_H || lsu_op_e == `LLSU_LDLE_H || lsu_op_e == `LLSU_IOCSRRD_H;
   wire lsu_ld      = lsu_op_e == `LLSU_LD_D  || lsu_op_e == `LLSU_LDX_D  || lsu_op_e == `LLSU_LDGT_D || lsu_op_e == `LLSU_LDLE_D || lsu_op_e == `LLSU_IOCSRRD_D;
   wire lsu_lhu     = lsu_op_e == `LLSU_LD_HU || lsu_op_e == `LLSU_LDX_HU ;
   wire lsu_sb      = lsu_op_e == `LLSU_ST_B  || lsu_op_e == `LLSU_STX_B  || lsu_op_e == `LLSU_STGT_B || lsu_op_e == `LLSU_STLE_B || lsu_op_e == `LLSU_IOCSRWR_B;
   wire lsu_sh      = lsu_op_e == `LLSU_ST_H  || lsu_op_e == `LLSU_STX_H  || lsu_op_e == `LLSU_STGT_H || lsu_op_e == `LLSU_STLE_H || lsu_op_e == `LLSU_IOCSRWR_H;
   wire lsu_sd      = lsu_op_e == `LLSU_ST_D  || lsu_op_e == `LLSU_STX_D  || lsu_op_e == `LLSU_STGT_D || lsu_op_e == `LLSU_STLE_D || lsu_op_e == `LLSU_IOCSRWR_D ||
                      lsu_am_sd;   


//   wire lsu_gt      = lsu_op_e == `LLSU_LDGT_W || lsu_op_e == `LLSU_LDGT_B || lsu_op_e == `LLSU_LDGT_H || lsu_op_e == `LLSU_LDGT_D ||
//                      lsu_op_e == `LLSU_STGT_W || lsu_op_e == `LLSU_STGT_B || lsu_op_e == `LLSU_STGT_H || lsu_op_e == `LLSU_STGT_D ;
//   wire lsu_le      = lsu_op_e == `LLSU_LDLE_W || lsu_op_e == `LLSU_LDLE_B || lsu_op_e == `LLSU_LDLE_H || lsu_op_e == `LLSU_LDLE_D ||
//                      lsu_op_e == `LLSU_STLE_W || lsu_op_e == `LLSU_STLE_B || lsu_op_e == `LLSU_STLE_H || lsu_op_e == `LLSU_STLE_D ;
//   wire lsu_idle    = lsu_op_e == `LLSU_IDLE;
//
//   wire prefetch    = lsu_op_e == `LLSU_PRELD || lsu_op_e == `LLSU_PRELDX;


   //wire lsu_wr      = lsu_sw || lsu_sb || lsu_sh || lsu_scw || lsu_scd || lsu_sd;
   wire lsu_load_e  = lsu_ld || lsu_lw || lsu_llw || lsu_lld || lsu_lb  || lsu_lbu || lsu_lh || lsu_lhu || lsu_lbu || lsu_lwu;
   //wire lsu_store_e = lsu_sb || lsu_sh || lsu_sd  || lsu_sw  || lsu_scw || lsu_scd;
   // If no llb set, sc do not perform store
   wire lsu_store_e = lsu_sb || lsu_sh || lsu_sd  || lsu_sw  || (lsu_scw && csr_lsu_llb) || (lsu_scd && csr_lsu_llb); 

   wire lsu_load_ls1;
   wire lsu_store_ls1;
   wire lsu_load_ls2;
   wire lsu_store_ls2;


   assign lsu_wstrb_e    = {4{lsu_sw||lsu_scw}} & (4'b1111              ) |
                             {4{lsu_sh         }} & (4'b0011 << lsu_shift_e[1:0]) |
                             {4{lsu_sb         }} & (4'b0001 << lsu_shift_e[1:0]) ;

   assign lsu_wdata_e   = {32{lsu_sw||lsu_scw}} & {ecl_lsu_wdata_e[31:0]} |
                            {32{lsu_sh         }} & {ecl_lsu_wdata_e[15:0], ecl_lsu_wdata_e[15:0]} |
                            {32{lsu_sb         }} & {ecl_lsu_wdata_e[ 7:0], ecl_lsu_wdata_e[7:0], ecl_lsu_wdata_e[7:0], ecl_lsu_wdata_e[7:0]};



   // address alignment exception, trigger pipeline abort
   wire am_addr_align_exc = (lsu_am_lw || lsu_am_sw || lsu_llw || lsu_scw) && lsu_addr_e[1:0] != 2'd0 ||
	                    (lsu_am_ld || lsu_am_sd || lsu_lld || lsu_scd) && lsu_addr_e[2:0] != 3'd0 ;

   wire cm_addr_align_exc = (lsu_ld||lsu_sd         ) && lsu_addr_e[2:0] != 3'd0 ||
                            (lsu_lw||lsu_lwu||lsu_sw) && lsu_addr_e[1:0] != 2'd0 ||
                            (lsu_lh||lsu_lhu||lsu_sh) && lsu_addr_e[0]   != 1'd0 ;

   wire lsu_ale_e               = am_addr_align_exc || cm_addr_align_exc;

   assign lsu_ecl_except_ale_e  = lsu_ale_e & lsu_valid_e;
   assign lsu_ecl_except_ale_badv_e = lsu_addr_e;


   assign lsu_ecl_ibar_fin_e = lsu_ibar_e & lsu_valid_e;
   assign lsu_ecl_dbar_fin_e = lsu_dbar_e & lsu_valid_e;



   //
   // dtlb
   //

   // ---------- TLB search port signals ----------
   wire        tlb_s_vld_ls1;
   wire [18:0] tlb_s_vppn;     // VPN2 (19 bits)
   wire        tlb_s_odd_page;
   wire [ 9:0] tlb_s_asid;
   wire        tlb_s_found;
   wire [ 4:0] tlb_s_index;
   wire [19:0] tlb_s_pfn;      // Physical page number
   wire        tlb_s_d;
   wire        tlb_s_v;
   wire [ 1:0] tlb_s_mat;
   wire [ 1:0] tlb_s_plv;

   wire tlb_res_vld_ls2;
   wire tlbr_exception_ls2;
   wire pil_exception_ls2;
   wire pis_exception_ls2;
   wire ppi_exception_ls2;
   wire pme_exception_ls2;

   //wire tlb_related_exceptions;
   //assign tlb_related_exceptions = tlbr_exception_ls2 | pil_exception_ls2 | pis_exception_ls2 | pme_exception_ls2;

   assign tlbr_exception_ls2 = tlb_res_vld_ls2 & ~tlb_s_found; // uty: test

   assign pil_exception_ls2 = tlb_res_vld_ls2 & tlb_s_found & ~tlb_s_v & lsu_load_ls2;
   assign pis_exception_ls2 = tlb_res_vld_ls2 & tlb_s_found & ~tlb_s_v & lsu_store_ls2;
   assign ppi_exception_ls2 = tlb_res_vld_ls2 & tlb_s_found & tlb_s_v & (csr_dtlb_crmd_plv > tlb_s_plv);
   assign pme_exception_ls2 = tlb_res_vld_ls2 & tlb_s_found & tlb_s_v & ~tlb_s_d & lsu_store_ls2;

   // The DTLB is searched in LS1 with the registered address; the result,
   // the TLB exceptions and the BIU request follow in LS2.
   // Has to be load or store operations, for example, ibar and dbar do not
   // need tlb address translation
   assign tlb_s_vld_ls1 = (lsu_valid_ls1 & (lsu_load_ls1 | lsu_store_ls1)) & pg_mode & ~(match_dmw0_ls1 | match_dmw1_ls1);
   assign tlb_s_vppn = lsu_addr_ls1[31:13];
   assign tlb_s_odd_page = lsu_addr_ls1[12];
   assign tlb_s_asid = csr_dtlb_asid_asid;

   // Physical address generation
   // - Direct address mode (DA=1, PG=0): clear high 3 bits
   // - Mapped address mode (DA=0, PG=1):
   //   - If DMW0 hit, use DMW0 direct mapping
   //   - Otherwise use TLB translation result
   assign match_dmw0_ls1 = (lsu_addr_ls1[31:29] == csr_lsu_dmw0_vseg);
   assign match_dmw1_ls1 = (lsu_addr_ls1[31:29] == csr_lsu_dmw1_vseg);
   assign match_dmw0_ls2 = (lsu_addr_ls2[31:29] == csr_lsu_dmw0_vseg);
   assign match_dmw1_ls2 = (lsu_addr_ls2[31:29] == csr_lsu_dmw1_vseg);

   // ---------- Generate physical address ----------
   // Physical address = PFN (20 bits) concatenated with page offset (12 bits)
   // This is valid only when tlb_s_found is 1; otherwise the value is meaningless.
   // Physical address with DMW0 priority over DMW1
   assign lsu_paddr_ls2 = da_mode ? (lsu_addr_ls2 & 32'h1FFFFFFF)  // not affect 0x1c000000
                                  : (match_dmw0_ls2 ? {csr_lsu_dmw0_pseg, lsu_addr_ls2[28:0]}
                                  : (match_dmw1_ls2 ? {csr_lsu_dmw1_pseg, lsu_addr_ls2[28:0]}
                                                    : {tlb_s_pfn, lsu_addr_ls2[11:0]}));

   wire dtlb_we;
   assign dtlb_we = (csr_dtlb_tlbfill_vld_e | csr_dtlb_tlbwr_vld_e) & csr_dtlb_tlbidx_i_d;

   wire [4:0] dtlb_w_index;
   assign dtlb_w_index = csr_dtlb_tlbfill_vld_e ? exu_dtlb_random_index :
                        (csr_dtlb_tlbwr_vld_e   ? csr_dtlb_tlbidx_index : 5'b0); 

   assign dtlb_csr_tlbidx_index = tlb_s_index;

   wire tlbidx_e;
   assign dtlb_csr_tlbidx_e = exu_dtlb_tlbsrch_vld_m ? tlb_s_found : tlbidx_e;

   wire dtlb_inv_en;
   //assign dtlb_inv_en = exu_dtlb_invtlb_vld_e & csr_dtlb_tlbidx_i_d;
   // INVTLB has no index: invalidate matching entries in both the ITLB and
   // the DTLB, independent of TLBIDX.I_D, as on a unified TLB. Gating it
   // with I_D left stale entries in the other TLB after a page flush (COW).
   assign dtlb_inv_en = exu_dtlb_invtlb_vld_e;


   c7btlb u_dtlb(
      .clk                             (clk),
      .resetn                          (resetn),

      // search port
      .s_vld                           (tlb_s_vld_ls1 | exu_dtlb_tlbsrch_vld_e),
      //.s_vppn                          (tlb_s_vppn),
      .s_vppn                          (exu_dtlb_tlbsrch_vld_e ? csr_dtlb_tlbehi_vppn : tlb_s_vppn),
      .s_odd_page                      (tlb_s_odd_page),
      //.s_asid                          (tlb_s_asid),
      .s_asid                          (exu_dtlb_tlbsrch_vld_e ? csr_dtlb_asid_asid : tlb_s_asid),
      .s_found                         (tlb_s_found),
      .s_index                         (tlb_s_index),
      .s_pfn                           (tlb_s_pfn),
      .s_d                             (tlb_s_d),
      .s_v                             (tlb_s_v),
      .s_mat                           (tlb_s_mat),
      .s_plv                           (tlb_s_plv),

      // write port
      .we                              (dtlb_we),
      .w_index                         (dtlb_w_index),
      .w_vppn                          (csr_dtlb_tlbehi_vppn),
      .w_asid                          (csr_dtlb_asid_asid),
      .w_g                             (csr_dtlb_tlbelo0_g & csr_dtlb_tlbelo1_g),
      .w_ps                            (csr_dtlb_tlbidx_ps),
      .w_e                             (csr_dtlb_tlbrefill_ctx ? 1'b1 : ~csr_dtlb_tlbidx_ne),
      .w_v0                            (csr_dtlb_tlbelo0_v), 
      .w_d0                            (csr_dtlb_tlbelo0_d),
      .w_mat0                          (csr_dtlb_tlbelo0_mat),
      .w_plv0                          (csr_dtlb_tlbelo0_plv),
      .w_ppn0                          (csr_dtlb_tlbelo0_ppn),
      .w_v1                            (csr_dtlb_tlbelo1_v),
      .w_d1                            (csr_dtlb_tlbelo1_d),
      .w_mat1                          (csr_dtlb_tlbelo1_mat),
      .w_plv1                          (csr_dtlb_tlbelo1_plv),
      .w_ppn1                          (csr_dtlb_tlbelo1_ppn),

      // read port
      .r_index                         (csr_dtlb_tlbidx_index),
      .r_vppn                          (dtlb_csr_tlbehi_vppn),
      .r_asid                          (dtlb_csr_asid_asid),
      .r_g                             (dtlb_csr_tlbelo_g),
      .r_ps                            (dtlb_csr_tlbidx_ps),
      //.r_e                             (dtlb_csr_tlbidx_e),
      .r_e                             (tlbidx_e),
      .r_v0                            (dtlb_csr_tlbelo0_v),
      .r_d0                            (dtlb_csr_tlbelo0_d),
      .r_mat0                          (dtlb_csr_tlbelo0_mat),
      .r_plv0                          (dtlb_csr_tlbelo0_plv),
      .r_ppn0                          (dtlb_csr_tlbelo0_ppn),
      .r_v1                            (dtlb_csr_tlbelo1_v),
      .r_d1                            (dtlb_csr_tlbelo1_d),
      .r_mat1                          (dtlb_csr_tlbelo1_mat),
      .r_plv1                          (dtlb_csr_tlbelo1_plv),
      .r_ppn1                          (dtlb_csr_tlbelo1_ppn),

      // invalid port
      .inv_en                          (dtlb_inv_en),
      .inv_op                          (exu_dtlb_invtlb_op_e),
      .inv_asid                        (exu_dtlb_invtlb_asid_e),
      .inv_vppn                        (exu_dtlb_invtlb_vppn_e)
   );


   //
   // BIU read request
   //

  
   // 
   // When managing the lsu_biu_rd_req_ls2 signals (the same with
   // lsu_biu_wr_req_ls2), three implementation options exist:
   //
   // Option 1, lsu_biu_rd_req_ls2 = biu_rd_req_in;
   // Since biu_rd_req_in may involve combinational logic on the BIU side,
   // this could establish a feedback loop depending on how biu_lsu_rd_ack_ls2
   // is handled.
   //
   // Option 2, lsu_biu_rd_req_ls2 = biu_rd_req_q;
   // This is the current selected approach. It avoids looping and ensures
   // correct handshaking, though it introduces a one-cycle latency even when
   // the LSU is free.
   //
   // Option 3, lsu_biu_rd_req_ls2 = biu_rd_req_in | biu_rd_req_q;
   // This resembles AXI-style VALID/READY signaling in most cases:
   //
   // lsu_valid_ls2 & lsu_load_ls2 : _-_____
   // biu_lsu_rd_ack_ls2           : _____-_
   // lsu_biu_rd_req_ls2           : _-----_
   //
   // However, when start and end occur in the same cycle, the behavior
   // changes:
   //
   // lsu_valid_ls2 & lsu_load_ls2 : _-_____
   // biu_lsu_rd_ack_ls2           : _--____
   // lsu_biu_rd_req_ls2           : _--____
   //
   // This still requires two cycles and results in an awkward timing
   // appearance for biu_lsu_rd_ack_ls2
   //


   // lsu_valid_ls2 & lsu_load_ls2        : _-_____
   // biu_lsu_rd_ack_ls2                  : _____-_
   //
   // biu_rd_req_in                       : _----__
   // biu_rd_req_q                        : __----_

   wire biu_rd_req_in;
   wire biu_rd_req_q;

   //assign biu_rd_req_in = (biu_rd_req_q & ~biu_lsu_rd_ack_ls2) | (lsu_valid_ls2 & lsu_load_ls2);
   //assign biu_rd_req_in = (biu_rd_req_q & ~(biu_lsu_rd_ack_ls2 | tlbr_exception_ls2)) | (lsu_valid_ls2 & lsu_load_ls2);
   //assign biu_rd_req_in = (~(biu_lsu_rd_ack_ls2 | tlbr_exception_ls2)) & ((lsu_valid_ls2 & lsu_load_ls2) | biu_rd_req_q);
   //
   // tlb_related_exceptions contains pis and pme, which are not suppose to
   // happen during a ld
   //assign biu_rd_req_in = (~(biu_lsu_rd_ack_ls2 | tlbr_exception_ls2 | pil_exception_ls2 | ppi_exception_ls2)) & ((lsu_valid_ls2 & lsu_load_ls2) | biu_rd_req_q);
   assign biu_rd_req_in = (~(biu_lsu_rd_ack_ls2 | tlbr_exception_ls2 | pil_exception_ls2 | ppi_exception_ls2)) & ((lsu_valid_ls2 & lsu_load_ls2) | biu_rd_req_q);

   dffrl_ns #(1) biu_rd_req_reg (
      .din   (biu_rd_req_in),
      .clk   (clk),
      .rst_l (resetn),
      .q     (biu_rd_req_q));
      //.se(), .si(), .so());

   assign lsu_biu_rd_req_ls2 = biu_rd_req_q;
   //assign lsu_biu_rd_req_ls2 = biu_rd_req_q & (da_mode | match_dmw0 | match_dmw1 | (tlb_s_found & tlb_s_v));

   //assign lsu_biu_rd_addr_ls2 = {lsu_addr_ls2[31:3], 3'b000}; // 64-bit align
   //assign lsu_biu_rd_addr_ls2 = lsu_addr_ls2;
   assign lsu_biu_rd_addr_ls2 = lsu_paddr_ls2;

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
   

   //assign biu_wr_req_in = (biu_wr_req_q & ~biu_lsu_wr_ack_ls2) | (lsu_valid_ls2 & lsu_store_ls2);
   //assign biu_wr_req_in = (biu_wr_req_q & ~(biu_lsu_wr_ack_ls2 | tlbr_exception_ls2)) | (lsu_valid_ls2 & lsu_store_ls2);
   //assign biu_wr_req_in = (~(biu_lsu_wr_ack_ls2 | tlbr_exception_ls2)) & ((lsu_valid_ls2 & lsu_store_ls2) | biu_wr_req_q);
   //assign biu_wr_req_in = (~(biu_lsu_wr_ack_ls2 | tlbr_exception_ls2 | pis_exception_ls2 | ppi_exception_ls2 | pme_exception_ls2)) & ((lsu_valid_ls2 & lsu_store_ls2) | biu_wr_req_q);
   assign biu_wr_req_in = (~(biu_lsu_wr_ack_ls2 | tlbr_exception_ls2 | pis_exception_ls2 | ppi_exception_ls2 | pme_exception_ls2)) & ((lsu_valid_ls2 & lsu_store_ls2) | biu_wr_req_q);

   dffrl_ns #(1) biu_wr_req_reg (
      .din   (biu_wr_req_in),
      .clk   (clk),
      .rst_l (resetn),
      .q     (biu_wr_req_q));
      //.se(), .si(), .so());

   assign lsu_biu_wr_req_ls2 = biu_wr_req_q;
   //assign lsu_biu_wr_req_ls2 = biu_wr_req_q & (da_mode | match_dmw0 | match_dmw1 | (tlb_s_found & tlb_s_v));

   //assign lsu_biu_wr_addr_ls2 = {lsu_addr_ls2[31:3], 3'b000}; // 64-bit align
   //assign lsu_biu_wr_addr_ls2 = lsu_addr_ls2;
   assign lsu_biu_wr_addr_ls2 = lsu_paddr_ls2;



   //wire lsu_wr_high32_ls2 = lsu_addr_ls2[2];
   wire lsu_wr_high32_ls2 = lsu_paddr_ls2[2];
   assign lsu_biu_wr_data_ls2 = lsu_wr_high32_ls2 ? {lsu_wdata_ls2, 32'b0} : {32'b0, lsu_wdata_ls2};
   assign lsu_biu_wr_strb_ls2 = lsu_wr_high32_ls2 ? {lsu_wstrb_ls2, 4'b0} : {4'b0, lsu_wstrb_ls2};


   //
   // Process data received from BIU 
   //

   wire data_high32_ls3 = lsu_addr_ls3[2]; // should be lsu_paddr_ls3, but it is the same

   wire [31:0] data_rdata_input_ls3 = data_high32_ls3 ? biu_lsu_data_ls3[63:32] : biu_lsu_data_ls3[31:0];


   wire [4:0] lsu_align_mode_e;
   wire [4:0] lsu_align_mode_ls1;
   wire [4:0] lsu_align_mode_ls2;
   wire [4:0] lsu_align_mode_ls3;

   assign lsu_align_mode_e[0] = !(lsu_scw || lsu_scd) && (lsu_ld ||lsu_lld);
   assign lsu_align_mode_e[1] = !(lsu_scw || lsu_scd) && (lsu_lw ||lsu_llw||lsu_lwu);
   assign lsu_align_mode_e[2] = !(lsu_scw || lsu_scd) && (lsu_lh ||lsu_lhu);
   assign lsu_align_mode_e[3] = !(lsu_scw || lsu_scd) && (lsu_lb ||lsu_lbu);
   assign lsu_align_mode_e[4] = !(lsu_scw || lsu_scd) && (lsu_lbu||lsu_lhu||lsu_lwu);


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
   // If it is a scw, it also writes rd register
   //assign lsu_ecl_data_ls3 = lsu_scw_q ? 32'b1 : lsu_align_res_ls3;
   //assign lsu_ecl_data_valid_ls3 = lsu_scw_q ? biu_lsu_wr_fin_ls3 : biu_lsu_data_valid_ls3;


   assign lsu_ecl_wr_fin_ls3 = biu_lsu_wr_fin_ls3;

   assign lsu_valid_e = ecl_lsu_valid_e;
   assign lsu_op_e = ecl_lsu_op_e;


   // ll.w sc.w
   assign lsu_csr_llb_set_e = lsu_llw & lsu_valid_e;
   assign lsu_csr_llb_clr_e = lsu_scw & lsu_valid_e & csr_lsu_llb;
   assign lsu_ecl_sc_fin_e = lsu_scw & lsu_valid_e & ~csr_lsu_llb;


   //
   // registers
   //

   // Stages (one request at a time, the core stalls until the LSU ends it):
   //
   //   E   : ecl_lsu_*_e pulse for one cycle. Address add, decode, ALE,
   //         LLBit set/clear, sc_fin, ibar_fin, dbar_fin (all _e wires;
   //         the outputs lsu_ecl_except_ale_e, lsu_ecl_*_fin_e and
   //         lsu_csr_llb_*_e are valid in this cycle).
   //   LS1 : E registered. DTLB search with lsu_addr_ls1.
   //   LS2 : DTLB result, TLB exceptions, BIU request armed. The request
   //         (lsu_biu_*_req_ls2) is registered and held until the BIU ack.
   //   LS3 : BIU ack captures _ls2 into _ls3; read data / write finish.
   //
   // Every stage register is enabled by the previous stage's valid (LS3 by
   // the BIU ack), so its value is held while the core is stalled.

   // ALE is detected in E and the request goes no further: lsu_valid_ls1
   // stays low, so no DTLB search and no BIU request follow.
   dffrl_ns #(1) lsu_valid_ls1_reg (
      .din (lsu_valid_e & ~lsu_ale_e),
      .clk (clk),
      .rst_l (resetn),
      .q   (lsu_valid_ls1));
      //.se(), .si(), .so());

   dffrl_ns #(1) lsu_valid_ls2_reg (
      .din (lsu_valid_ls1),
      .clk (clk),
      .rst_l (resetn),
      .q   (lsu_valid_ls2));

   // LS2 holds the DTLB result for the search issued in LS1. A TLBSRCH does
   // not set it, so it raises no LSU exception.
   dffrl_ns #(1) tlb_res_vld_ls2_reg (
      .din (tlb_s_vld_ls1),
      .clk (clk),
      .rst_l (resetn),
      .q   (tlb_res_vld_ls2));

   //
   // E -> LS1
   //

   dffe_ns #(32) lsu_addr_ls1_reg (
      .din (lsu_addr_e),
      .clk (clk),
      .en  (lsu_valid_e),
      .q   (lsu_addr_ls1));
      //.se(), .si(), .so());

   dffe_ns #(3) lsu_shift_ls1_reg (
      .din (lsu_shift_e),
      .clk (clk),
      .en  (lsu_valid_e),
      .q   (lsu_shift_ls1));
      //.se(), .si(), .so());

   dffe_ns #(1) lsu_load_ls1_reg (
      .din (lsu_load_e),
      .clk (clk),
      .en  (lsu_valid_e),
      .q   (lsu_load_ls1));
      //.se(), .si(), .so());

   dffe_ns #(1) lsu_store_ls1_reg (
      .din (lsu_store_e),
      .clk (clk),
      .en  (lsu_valid_e),
      .q   (lsu_store_ls1));
      //.se(), .si(), .so());

   dffe_ns #(32) lsu_wdata_ls1_reg (
      .din (lsu_wdata_e),
      .clk (clk),
      .en  (lsu_valid_e),
      .q   (lsu_wdata_ls1));
      //.se(), .si(), .so());

   dffe_ns #(4) lsu_wstrb_ls1_reg (
      .din (lsu_wstrb_e),
      .clk (clk),
      .en  (lsu_valid_e),
      .q   (lsu_wstrb_ls1));
      //.se(), .si(), .so());

   dffe_ns #(5) lsu_align_mode_ls1_reg (
      .din (lsu_align_mode_e),
      .clk (clk),
      .en  (lsu_valid_e),
      .q   (lsu_align_mode_ls1));
      //.se(), .si(), .so());

   // The load instruction's destination register and wen are not managed by
   // the LSU. There is no reservation station or other structure in the
   // design to hold the rd field for loads. Because the in-order core stalls
   // on a load instruction, the rd information is preserved within the EXU.

   dffrle_ns #(1) lsu_scw_reg (
      .din (lsu_scw & csr_lsu_llb), // it is a scw that will store and write rd register with 32'b1
      .clk (clk),
      .rst_l (resetn),
      .en (lsu_valid_e),
      .q   (lsu_scw_q));

   //
   // LS1 -> LS2
   //

   dffe_ns #(32) lsu_addr_ls2_reg (
      .din (lsu_addr_ls1),
      .clk (clk),
      .en  (lsu_valid_ls1),
      .q   (lsu_addr_ls2));
      //.se(), .si(), .so());

   dffe_ns #(3) lsu_shift_ls2_reg (
      .din (lsu_shift_ls1),
      .clk (clk),
      .en  (lsu_valid_ls1),
      .q   (lsu_shift_ls2));
      //.se(), .si(), .so());

   dffe_ns #(1) lsu_load_ls2_reg (
      .din (lsu_load_ls1),
      .clk (clk),
      .en  (lsu_valid_ls1),
      .q   (lsu_load_ls2));
      //.se(), .si(), .so());

   dffe_ns #(1) lsu_store_ls2_reg (
      .din (lsu_store_ls1),
      .clk (clk),
      .en  (lsu_valid_ls1),
      .q   (lsu_store_ls2));
      //.se(), .si(), .so());

   dffe_ns #(32) lsu_wdata_ls2_reg (
      .din (lsu_wdata_ls1),
      .clk (clk),
      .en  (lsu_valid_ls1),
      .q   (lsu_wdata_ls2));
      //.se(), .si(), .so());

   dffe_ns #(4) lsu_wstrb_ls2_reg (
      .din (lsu_wstrb_ls1),
      .clk (clk),
      .en  (lsu_valid_ls1),
      .q   (lsu_wstrb_ls2));
      //.se(), .si(), .so());

   dffe_ns #(5) lsu_align_mode_ls2_reg (
      .din (lsu_align_mode_ls1),
      .clk (clk),
      .en  (lsu_valid_ls1),
      .q   (lsu_align_mode_ls2));
      //.se(), .si(), .so());

   //
   // LS2 -> LS3
   //

   // The memory read request is issued in LS2 via lsu_biu_rd_req_ls2. The
   // BIU's response time is variable, acknowledgment via biu_lsu_rd_ack_ls2
   // may occur in the same cycle or be delayed. This acknowledgment signal
   // initiates the subsequent pipeline stage, LS3.

   dffe_ns #(32) lsu_addr_ls3_reg (
      .din (lsu_addr_ls2),
      .clk (clk),
      .en  (biu_lsu_rd_ack_ls2),
      .q   (lsu_addr_ls3));
      //.se(), .si(), .so());

   dffe_ns #(3) lsu_shift_ls3_reg (
      .din (lsu_shift_ls2),
      .clk (clk),
      .en  (biu_lsu_rd_ack_ls2),
      .q   (lsu_shift_ls3));
      //.se(), .si(), .so());

   dffe_ns #(5) lsu_align_mode_ls3_reg (
      .din (lsu_align_mode_ls2),
      .clk (clk),
      .en  (biu_lsu_rd_ack_ls2),
      .q   (lsu_align_mode_ls3));
      //.se(), .si(), .so());

   // Note: Because the core stalls for load/store instructions, only one
   // request is in the pipeline at a time, so _ls2 and _ls3 duplicate _ls1.
   // They are kept for clarity and to allow overlapping requests later.


   assign lsu_sc = lsu_scw_q;

   assign lsu_ecl_except_buserr_ls3 = biu_lsu_fault_ls3 | biu_lsu_wr_fault_ls3;
   assign lsu_ecl_except_buserr_badv_ls3 = biu_lsu_fault_ls3 ? lsu_addr_ls3 : lsu_addr_ls2;
   //assign lsu_ecl_except_buserr_badv_ls3 = lsu_addr_ls2; // it is fine to use lsu_addr_ls2

   // Unimplmented signals
   assign lsu_ecl_except_ecc_ls3 = 1'b0;

   assign lsu_ecl_except_tlbr_ls2 = tlbr_exception_ls2;
   assign lsu_ecl_except_tlbr_badv_ls2 = lsu_addr_ls2;

   assign lsu_except_pil_ls2 = pil_exception_ls2;
   assign lsu_except_pil_badv_ls2 = lsu_addr_ls2;

   assign lsu_except_pis_ls2 = pis_exception_ls2;
   assign lsu_except_pis_badv_ls2 = lsu_addr_ls2;

   assign lsu_except_ppi_ls2 = ppi_exception_ls2;
   assign lsu_except_ppi_badv_ls2 = lsu_addr_ls2;

   assign lsu_except_pme_ls2 = pme_exception_ls2;
   assign lsu_except_pme_badv_ls2 = lsu_addr_ls2;

endmodule
