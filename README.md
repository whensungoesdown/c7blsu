# c7blsu — Load/Store Unit of cpu7b

c7blsu executes loads and stores for the cpu7b LA32R core. It takes a
one-cycle request pulse from the EXU control logic (ECL) in the E stage,
computes the effective address, checks alignment, translates the address
(direct address mode, DMW0/DMW1, or the 32-entry DTLB), raises address and
TLB exceptions, and issues one uncached read or write to the BIU. Read data
is extracted and sign/zero extended. There is no data cache and no store
buffer. The core stalls for the whole access, so only one access is in
flight. The LSU also owns the DTLB and serves TLBSRCH, TLBWR, TLBFILL,
TLBRD and INVTLB for it.

```
              ECL (E stage): valid / op / base / offset / wdata / ibar / dbar
                              |
                              v
  +-------------+   +----------------+   +---------+   +-------------+   +-----------+
  | LS1         |-->| LS2 _ls2 regs  |-->| c7btlb  |-->| paddr mux   |-->| LS3       |
  | addr, ALE,  |   | DA/DMW match,  |   | (DTLB)  |   | BIU rd / wr |   | extract,  |
  | LL/SC, bar  |   | tlb_s_vld      |   | 1 cycle |   | req, lanes  |   | extend    |
  +-------------+   +----------------+   +---------+   +-------------+   +-----------+
        |                                     |                                |
        v                                     v                                v
  ALE, sc/ibar/dbar fin,          TLBR/PIL/PIS/PPI/PME             data_valid / wr_fin /
  LLBit set/clr -> ECL/CSR        + badv -> ECL                    bus error -> ECL
```

## Files

| File | Module | Purpose |
|---|---|---|
| `rtl/c7blsu.v` | `c7blsu` | Top: address generation, ALE, translation, DTLB instance, BIU handshake, load data alignment, LL/SC |
| `rtl/c7blsu_defs.v` | | 7-bit LSU opcode encodings (`LLSU_*`) |
| `rtl/lib/swrvr_clib.v`, `rtl/lib/swrvr_dlib.v` | | Flop and mux library (`dffrl_ns`, `dffe_ns`, `dffrle_ns`, ...) |
| `flist/`, `tb/`, `simulation/` | | File lists, testbenches (`tb_c7blsu.v`, store and load tops), test scripts |

The DTLB is an instance of `c7btlb` (`u_dtlb`, `../c7btlb/rtl/c7btlb.v`,
included through `flist/sim.files`), the same module as the ITLB.

## Pipeline stages

| Stage | Where | What happens |
|---|---|---|
| LS1 | cycle 0, `_ls1` wires | Same cycle as EXU E. All `_ls1` signals are wires from `ecl_lsu_*_e` (`c7blsu.v:630-634`). Address add, decode, ALE, LLBit set/clear, `sc_fin`, `ibar_fin`, `dbar_fin`. |
| LS2 | cycle 1 .. ack, `_ls2` regs | `lsu_valid_ls2` pulses in cycle 1 (`c7blsu.v:665-669`), `lsu_valid_ls2_dly1` in cycle 2 (`c7blsu.v:672-676`). Address, op class, strobes and data are held in `_ls2` registers enabled by `lsu_valid_ls1`. DTLB search in cycle 1, result and TLB exceptions in cycle 2, BIU request high from cycle 3 until acknowledged. |
| LS3 | ack+1 .. done, `_ls3` regs | `lsu_addr_ls3`, `lsu_shift_ls3`, `lsu_align_mode_ls3` are captured on `biu_lsu_rd_ack_ls2` (`c7blsu.v:767-814`). Load data, write completion and bus faults pass straight through from the BIU. |

The stages are not a throughput pipeline. Each `_ls2`/`_ls3` register holds
the single in-flight request while the core is stalled
(`c7blsu.v:816-820`).

## Address generation

`lsu_addr_ls1 = ecl_lsu_base_e + ecl_lsu_offset_e` (`c7blsu.v:197`). In the
EXU `base` is `rs1` (bypassed), `offset` is `rs2` for indexed forms
(`lsu_double_read_e`) or the shifted immediate otherwise, and `wdata` is
`rs2` (`c7bexu.v:469-471`). `lsu_shift_ls1 = addr[2:0]` is carried to LS2
and LS3 for lane selection and extraction.

Op decoding (`c7blsu.v:213-288`) groups opcodes into size classes:

| Class | Opcodes |
|---|---|
| byte load `lsu_lb` | LD.B, LDX.B, LDGT.B, LDLE.B, IOCSRRD.B, PRELD, PRELDX |
| `lsu_lbu` / `lsu_lhu` / `lsu_lwu` | LD(X).BU / LD(X).HU / LD(X).WU |
| `lsu_lh` / `lsu_lw` | LD/LDX/LDGT/LDLE/IOCSRRD .H / .W |
| `lsu_sb` / `lsu_sh` | ST/STX/STGT/STLE/IOCSRWR .B / .H |
| `lsu_sw` | ST/STX/STGT/STLE/IOCSRWR .W and all AM*.W |
| `lsu_ld` / `lsu_sd` | .D forms and all AM*.D |
| LL/SC | LL.W, LL.D, SC.W, SC.D |

`lsu_load_ls1` = any load class including LL. `lsu_store_ls1` = any store
class, with SC.W/SC.D counted as a store only when `csr_lsu_llb` is 1
(`c7blsu.v:285-288`).

## Alignment check (ALE)

Computed combinationally in LS1 (`c7blsu.v:305-315`):

| Access | Condition for ALE |
|---|---|
| .D, AM*.D, LL.D, SC.D | `addr[2:0] != 0` |
| .W, .WU, AM*.W, LL.W, SC.W | `addr[1:0] != 0` |
| .H, .HU | `addr[0] != 0` |
| byte, PRELD | never |

`lsu_ecl_except_ale_ls1 = lsu_ale_ls1 & lsu_valid_ls1`, BADV is
`lsu_addr_ls1` (virtual address). ALE gates the input of `lsu_valid_ls2`
(`din = lsu_valid_ls1 & ~lsu_ale_ls1`), so no translation and no BIU
request follow. The EXU puts `lsu_except_ale_ls1` into `flush` directly and
registers it to `lsu_except_ale_m`, which merges into the M-stage exception
(`c7bexu.v:966, 1100, 1326-1336`).

## Address translation

`lsu_paddr_ls2` (in `c7blsu.v:384-387`) selects the physical address from
`lsu_addr_ls2`:

| Mode | Condition | Physical address |
|---|---|---|
| DA | `csr_lsu_crmd_da` = 1 | `lsu_addr_ls2 & 0x1FFFFFFF` |
| DMW0 | not DA, `addr[31:29] == dmw0_vseg` | `{dmw0_pseg, addr[28:0]}` |
| DMW1 | not DA, no DMW0 hit, `addr[31:29] == dmw1_vseg` | `{dmw1_pseg, addr[28:0]}` |
| DTLB | not DA, no DMW hit | `{tlb_s_pfn, addr[11:0]}` |

DMW0 has priority over DMW1. The DTLB is searched only when

```verilog
tlb_s_vld = lsu_valid_ls2 & (lsu_load_ls2 | lsu_store_ls2) & pg_mode & ~(match_dmw0_ls2 | match_dmw1_ls2);
// pg_mode = ~DA & PG
// key: vppn = addr_ls2[31:13], odd_page = addr_ls2[12], asid = CSR.ASID.ASID
```

DTLB match (`c7btlb.v:244-247`): `vppn` equal, (`asid` equal or `G`), and
`E`. The lowest matching index wins (`enc32`). The odd/even page selects V,
D, MAT, PLV and PPN.

### DTLB timing

`c7btlb` takes **one cycle** per search. The search inputs are latched into
`s_vppn_g`, `s_odd_page_g`, `s_asid_g`, `s_vld_g`, and `s_found` / `s_v` /
`s_d` / `s_plv` / `s_pfn` are combinational from the latched values
(`c7btlb.v:140-275`). The LSU keeps a matching flag
`tlb_res_vld_ls2 <= tlb_s_vld` (`c7blsu.v:830-834`) to qualify the result.

```
cycle           1 (lsu_valid_ls2)   2 (lsu_valid_ls2_dly1)
tlb_s_vld       1                   0
s_vppn          addr_ls2[31:13]     x
tlb_res_vld_ls2 0                   1
s_found         -                   result for addr_ls2
```

Because the search inputs are only reloaded when `s_vld` is high, `s_pfn`
stays stable while the request waits for the BIU.

To line up with this latency the BIU request is armed from
`lsu_valid_ls2_dly1` (cycle 2), not `lsu_valid_ls2`, for every mode,
including DA and DMW hits that do not use the DTLB (`c7blsu.v:525, 559`).
The request register drives the BIU from cycle 3.

## BIU request

### Signals

```verilog
// read (c7blsu.v:525-539)
biu_rd_req_in = ~(biu_lsu_rd_ack_ls2 | tlbr | pil | ppi)
                & ((lsu_valid_ls2_dly1 & lsu_load_ls2) | biu_rd_req_q);
lsu_biu_rd_req_ls2  = biu_rd_req_q;
lsu_biu_rd_addr_ls2 = lsu_paddr_ls2;

// write (c7blsu.v:559-580)
biu_wr_req_in = ~(biu_lsu_wr_ack_ls2 | tlbr | pis | ppi | pme)
                & ((lsu_valid_ls2_dly1 & lsu_store_ls2) | biu_wr_req_q);
lsu_biu_wr_req_ls2  = biu_wr_req_q;
lsu_biu_wr_addr_ls2 = lsu_paddr_ls2;
lsu_biu_wr_data_ls2 = paddr[2] ? {wdata_ls2, 32'b0} : {32'b0, wdata_ls2};
lsu_biu_wr_strb_ls2 = paddr[2] ? {wstrb_ls2, 4'b0}  : {4'b0, wstrb_ls2};

lsu_ecl_wr_fin_ls3 = biu_lsu_wr_fin_ls3;
```

The request is a registered level held until the ack cycle and drops the
cycle after (option 2 in the source comment, `c7blsu.v:476-506`).

In the top level (`c7b.v:172-177, 282-290`) the single LSU write request
drives both the BIU AW and W requests, `last` is 1, and `biu_lsu_wr_ack` is
`biu_lsu_wr_aw_ack & biu_lsu_wr_aw_ack`. `biu_lsu_wr_fin` is the BIU
`write_done` (B response). The BIU read arbiter gives the LSU priority and
acks combinationally (`axi_ar_ready & lsu_select & ~busy_q`,
`c7bbiu_rd_arb.v:99`).

In the timelines below cycle 0 is the E stage where `ecl_lsu_valid_e`
pulses, `A` is the BIU ack cycle (A >= 3) and `D` the data/finish cycle
(D > A). BIU wait cycles depend on the BIU/AXI.

### Timeline: load, DA or DMW (BIU read)

```
cycle                   0     1     2     3 .. A      A+1 .. D-1   D
ecl_lsu_valid_e         1     0     0     0           0            0
lsu_valid_ls2           0     1     0     0           0            0
lsu_valid_ls2_dly1      0     0     1     0           0            0
biu_rd_req_in           0     0     1     1 (0 in A)  0            0
lsu_biu_rd_req_ls2      0     0     0     1           0            0
biu_lsu_rd_ack_ls2      0     0     0     1 in A      0            0
_ls3 regs               -     -     -     load in A   held         held
lsu_ecl_data_valid_ls3  0     0     0     0           0            1
ECL stall               1     1     1     1           1            ends
```

- 0: address add and ALE check; `_ls2` registers load.
- 2: `lsu_valid_ls2_dly1` sets `biu_rd_req_in`.
- 3 .. A: request held until the BIU acks; `_ls3` registers load in A.
- D: `biu_lsu_data_valid_ls3`; data is extracted combinationally and
  written into `rd_data_m` (`c7bexu.v:924`).

### Timeline: store (BIU AW/W/B)

```
cycle                   0     1     2     3 .. A      A+1 .. D-1   D
ecl_lsu_valid_e         1     0     0     0           0            0
lsu_valid_ls2           0     1     0     0           0            0
lsu_valid_ls2_dly1      0     0     1     0           0            0
lsu_biu_wr_req_ls2      0     0     0     1           0            0
wr_addr/data/strb       -     -     -     paddr, lane by paddr[2]
biu_lsu_wr_ack_ls2      0     0     0     1 in A      0            0
biu_lsu_wr_fin_ls3 (B)  0     0     0     0           0            1
lsu_ecl_wr_fin_ls3      0     0     0     0           0            1
```

- 0: strobes and data replicated (see Store data), `_ls2` registers load.
- 3 .. A: AW and W requests driven together; ack is the AW ack.
- D: B response, `lsu_ecl_wr_fin_ls3` ends the ECL stall.

### Timeline: DTLB-mapped load (hit, V=1, PLV ok)

```
cycle                   0     1        2                 3 .. A    D
lsu_valid_ls2           0     1        0                 0         0
tlb_s_vld               0     1        0                 0         0
tlb_res_vld_ls2/s_vld_g 0     0        1                 0         0
tlb_s_found, s_v        -     -        1, 1              -         -
lsu_paddr_ls2           -     -        {pfn,addr[11:0]}  same      -
biu_rd_req_in           0     0        1                 1 until A 0
lsu_biu_rd_req_ls2      0     0        0                 1         0
lsu_ecl_data_valid_ls3  0     0        0                 0         1
```

- 1: DTLB latches the key at the end of the cycle.
- 2: result valid, no exception, request input set.

The DA/DMW and DTLB paths have the same timing; the DTLB lookup is hidden
by the `lsu_valid_ls2_dly1` cycle.

## Load data extraction

The BIU returns 64 bits. LS3 selects `data[63:32]` when `lsu_addr_ls3[2]`
is 1, else `data[31:0]` (`c7blsu.v:587-589`). Using the virtual address bit
is valid because bit 2 is part of the page offset in every translation mode.

`lsu_align_mode` (`c7blsu.v:596-600`): bit0 = 64-bit, bit1 = word,
bit2 = half, bit3 = byte, bit4 = unsigned; all zero for SC.

| Access | `shift[1:0]` | Result |
|---|---|---|
| byte signed / unsigned | 0, 1, 2, 3 | byte `[8*s+7:8*s]`, sign / zero extended |
| half signed / unsigned | 0, 2 | half `[15:0]` or `[31:16]`, sign / zero extended |
| word (W or WU) | 0 | `[31:0]` |
| none of byte/half/word set | - | `32'h1` |

`lsu_ecl_data_valid_ls3 = biu_lsu_data_valid_ls3` and the result is driven
combinationally in the same cycle (`c7blsu.v:621-622`).

## Store data and byte strobes

Built in LS1 (`c7blsu.v:294-300`) and registered into `_ls2`:

| Access | `wstrb[3:0]` | `wdata[31:0]` |
|---|---|---|
| W, SC.W, AM*.W | `1111` | `rs2` |
| H | `0011 << shift[1:0]` | `{rs2[15:0], rs2[15:0]}` |
| B | `0001 << shift[1:0]` | `{4{rs2[7:0]}}` |
| others (.D, SC.D) | `0000` | `0` |

In LS2 they are placed in the 64-bit bus lane by `lsu_paddr_ls2[2]`
(`c7blsu.v:578-580`, see BIU request).

## Exceptions

| Exception | Detected | Condition | Request sent | BADV | EXU code |
|---|---|---|---|---|---|
| ALE | LS1 (cycle 0) | see alignment table | no | `lsu_addr_ls1` | 0x09 |
| TLBR | LS2 (cycle 2) | `tlb_res_vld_ls2 & ~found` | no | `lsu_addr_ls2` | 0x3F |
| PIL | LS2 (cycle 2) | found, `~V`, load | no | `lsu_addr_ls2` | 0x01 |
| PIS | LS2 (cycle 2) | found, `~V`, store | no | `lsu_addr_ls2` | 0x02 |
| PPI | LS2 (cycle 2) | found, `V`, `CRMD.PLV > page PLV` | no | `lsu_addr_ls2` | 0x07 |
| PME | LS2 (cycle 2) | found, `V`, `~D`, store | no | `lsu_addr_ls2` | 0x04 |
| ADEM (bus error) | LS3 | `biu_lsu_fault_ls3 \| biu_lsu_wr_fault_ls3` | yes | read: `lsu_addr_ls3`, write: `lsu_addr_ls2` | 0x08, subcode 1 |
| ECC | - | tied to 0 (`c7blsu.v:844`) | - | - | - |

All BADV values are virtual addresses. TLB exceptions only exist in the
cycle where `tlb_res_vld_ls2` is high, and they clear the BIU request input
in that cycle (`c7blsu.v:525, 559`): TLBR/PIL/PPI block a read,
TLBR/PIS/PPI/PME block a write. Because the request register was never set,
no bus access is made.

The EXU merges the LSU exceptions into the M-stage exception in this
priority (`c7bexu.v:1100-1143`): bus error > ALE > TLBR > PIL > PIS > PPI >
PME > other M-stage exceptions, registers them to `exc_vld_w`, and
redirects to `csr_tlbr_addr` when the code is 0x3F (`c7bexu.v:947`). TLB
exceptions are not added to `flush` directly (`c7bexu.v:962-966`); the ECL
ends the LSU stall on `exc_vld_w` (`c7bexu.v:983`).

### Timeline: load with TLB refill exception

```
cycle                   0     1     2           3     4
lsu_valid_ls2/tlb_s_vld 0     1     0           0     0
tlb_res_vld_ls2         0     0     1           0     0
tlb_s_found             -     -     0           -     -
lsu_ecl_except_tlbr_ls2 0     0     1           0     0
biu_rd_req_in           0     0     0 (blocked) 0     0
lsu_biu_rd_req_ls2      0     0     0           0     0
EXU exc_vld_merge_m     0     0     1 (0x3F)    0     0
EXU exc_vld_w           0     0     0           1     0
```

- 2: TLBR with BADV `lsu_addr_ls2`; the request input is blocked.
- 3: `exc_vld_w` ends the ECL stall; IFU goes to `csr_tlbr_addr`.

PIL/PIS/PPI/PME follow the same timing with their own codes.

### Timeline: ALE

```
cycle                    0     1     2
ecl_lsu_valid_e          1     0     0
lsu_ecl_except_ale_ls1   1     0     0
EXU flush                1     -     1 (exc_vld_w)
ECL lsu_end              1     0     0
lsu_valid_ls2            0     0     0
BIU request              -     none  none
EXU lsu_except_ale_m     0     1     0
EXU exc_vld_w            0     0     1
```

- 0: ALE with BADV `lsu_addr_ls1`; `flush` and `lsu_end` in the same cycle,
  so there is no stall; `lsu_valid_ls2` is killed.
- 1: `lsu_except_ale_m` (code 0x09) merges into the M-stage exception.

## LL/SC and LLBit

All in LS1 (`c7blsu.v:638-640`); the CSR holds LLBit:

| Signal | Value |
|---|---|
| `lsu_csr_llb_set` | `LL.W & valid_ls1` |
| `lsu_csr_llb_clr` | `SC.W & valid_ls1 & llb` |
| `lsu_ecl_sc_fin_ls1` | `SC.W & valid_ls1 & ~llb` |
| `lsu_sc` | `lsu_scw_q`, registered `SC.W & llb` on `valid_ls1` (`c7blsu.v:822-837`) |

LL.W is a normal word load. SC.W with LLBit = 0 is not a store
(`lsu_store_ls1` = 0); `sc_fin` ends the ECL stall in LS1 and the EXU
writes `rd = 0` one cycle later through `lsu_sc_fin_m`
(`c7bexu.v:930, 1339-1342`). SC.W with LLBit = 1 clears LLBit in LS1,
performs the store, and the EXU writes `rd = 1` when
`lsu_wr_fin_ls3 & lsu_sc` (`c7bexu.v:931`).

### Timeline: SC.W, LLBit = 0

```
cycle                    0     1     2
lsu_ecl_sc_fin_ls1       1     0     0
lsu_store_ls1            0     -     -
ECL stall                none
lsu_valid_ls2            0     1     0     (load/store = 0, no request)
EXU lsu_sc_fin_m         0     1     0     (rd_data_m = 0)
```

### Timeline: SC.W, LLBit = 1

```
cycle                    0     1     2     3 .. A   D
lsu_csr_llb_clr          1     0     0     0        0
lsu_sc (lsu_scw_q)       0     1     1     1        1
lsu_biu_wr_req_ls2       0     0     0     1        0     (strb 1111)
lsu_ecl_wr_fin_ls3       0     0     0     0        1
EXU rd_data_m = 1        -     -     -     -        1
```

## IBAR / DBAR

`lsu_ecl_ibar_fin = ecl_lsu_ibar_e & valid_ls1` and
`lsu_ecl_dbar_fin = ecl_lsu_dbar_e & valid_ls1` (`c7blsu.v:318-319`). Both
complete in LS1. They are neither loads nor stores, so no DTLB search and
no BIU request follow. Since there is a single outstanding access and no
store buffer, no draining is needed.

## DTLB maintenance (TLBSRCH, TLBWR/TLBFILL, TLBRD, INVTLB)

The CSR bit `TLBIDX.I_D` (bit 16, `c7bcsr.v:627`) selects the target TLB:
1 = DTLB (this module), 0 = ITLB (`c7bifu.v:383-400`).

| Operation | DTLB connection |
|---|---|
| TLBSRCH | `s_vld = tlb_s_vld \| exu_dtlb_tlbsrch_vld_e`; while `tlbsrch_vld_e` is high the key is `CSR.TLBEHI.VPPN` and `CSR.ASID` (`c7blsu.v:411-416`). Result is read one cycle later: `dtlb_csr_tlbidx_e = tlbsrch_vld_m ? s_found : r_e`, `dtlb_csr_tlbidx_index = s_index` (`c7blsu.v:396-399`). The ECL stalls the IFU during the TLB op's E cycle so TLBSRCH owns the search port (`c7bexu.v:996`, `c7bexu_ecl.v:115`). A TLBSRCH does not set `tlb_res_vld_ls2`, so it raises no LSU exception. |
| TLBWR / TLBFILL | `we = (tlbfill_vld_e \| tlbwr_vld_e) & I_D`; index = `TLBIDX.INDEX` (TLBWR) or `exu_dtlb_random_index` (TLBFILL); `w_e = tlbrefill_ctx ? 1 : ~TLBIDX.NE`; `w_g = TLBELO0.G & TLBELO1.G` (`c7blsu.v:389-394, 426-442`). |
| TLBRD | Read port indexed by `TLBIDX.INDEX`, outputs go to CSR (`dtlb_csr_*`). |
| INVTLB | `inv_en = invtlb_vld_e & I_D`; op = `rd`, asid = `rs1[9:0]`, vppn = `rs2[31:13]` (`c7bexu.v:907-910`). Ops 0-6 clear `E` per op; other ops do nothing. INVTLB has priority over a write in the same cycle (`c7btlb.v:159-225`). |

## Notes / limitations

- No data cache and no store buffer (the STB ports are commented out);
  every access is an uncached single BIU transaction
  (`c7blsu.v:14-16, 65-83`). Only one access is outstanding; the core
  stalls until it completes (`c7blsu.v:765, 816-820`).
- The BIU request is always armed from `lsu_valid_ls2_dly1`, so the first
  request cycle is cycle 3 even for DA and DMW accesses that need no DTLB
  lookup (`c7blsu.v:525, 559`).
- DMW match compares only `VSEG` (`c7blsu.v:377-378`); the DMW PLV0/PLV3
  enable bits are not inputs, so a DMW window matches in any privilege
  level, including user mode accessing a kernel window. DMW MAT is not used.
- DA mode masks the address with `0x1FFFFFFF` (`c7blsu.v:384`) instead of
  using VA as PA.
- With DA = 0 and PG = 0 the address goes through the DMW/DTLB mux but no
  DTLB search is made, so a non-DMW address uses a stale `tlb_s_pfn`
  (`c7blsu.v:175, 362, 387`).
- DTLB `MAT` is not used (`tlb_s_mat` unconnected beyond the port); all
  accesses look the same to the BIU.
- DTLB matching ignores the page size `PS`; only 19-bit VPPN with 4 KB
  odd/even pages is matched (`c7btlb.v:244-247`).
- PPI is checked for loads and stores, and is evaluated before PME in the
  EXU priority (`c7blsu.v:354`, `c7bexu.v:1116-1117`).
- The EXU sets exception subcode 1 for all TLB-related exceptions, not only
  for ADEM (`c7bexu.v:1127`).
- `lsu_csr_llb_set` (LL.W) and `lsu_csr_llb_clr` (SC.W) are not gated by
  ALE, and the SC.W clear happens in LS1 before the store's TLB check and
  bus completion (`c7blsu.v:638-640`). A misaligned SC.W with LLBit = 0
  asserts both `sc_fin` and ALE.
- LL.D/SC.D and .D accesses are decoded, but store strobes/data are only
  generated for W/H/B, so `lsu_sd`/SC.D writes have strobe `0`; .D loads
  return `32'h1` from the default extraction term (`c7blsu.v:294-300, 619`).
- AM* opcodes are decoded as plain stores (`lsu_sw` / `lsu_sd`), with no
  read-modify-write (`c7blsu.v:261-272`).
- LDGT/LDLE/STGT/STLE are treated as plain loads/stores; the bound check is
  commented out (`c7blsu.v:275-278`).
- PRELD/PRELDX are decoded by the LSU as `lsu_lb` and would issue a real
  BIU read (`c7blsu.v:263-264`). In the core they do not reach the LSU: the
  IFU decoder removed them from `lsu_related`, so they execute as NOPs
  (`c7bifu/rtl/decoder.v:510-514`, commit 1b41723).
- IOCSR ops go through the same address translation and BIU path as memory
  accesses (`c7blsu.v:259-271`).
- `lsu_ecl_except_ecc_ls3` is tied to 0, and `biu_lsu_fault_code_ls3` /
  `biu_lsu_wr_fault_code_ls3` are unused (`c7blsu.v:844`).
- The `_ls3` registers are enabled only by `biu_lsu_rd_ack_ls2`; the write
  bus-error BADV uses `lsu_addr_ls2` (`c7blsu.v:840`).
- In the TLBSRCH path `s_odd_page` still comes from `lsu_addr_ls2[12]`
  (`c7blsu.v:414`); it only affects the page-select outputs, not `found` or
  `index`.
- Top-level integration: `biu_lsu_wr_ack` is wired to
  `biu_lsu_wr_aw_ack & biu_lsu_wr_aw_ack`, so the W-channel ack is not used
  (`c7b.v:177`).
- The ECL ends the stall for TLB exceptions on `exc_vld_w` rather than on
  the LSU TLB exception signals (`c7bexu.v:983`, marked "uty: test").

## Interface summary

| Signal | Dir | Description |
|---|---|---|
| `clk` / `resetn` | in | Clock, active-low reset |
| `ecl_lsu_valid_e` | in | One-cycle request pulse (E) |
| `ecl_lsu_ibar_e` / `ecl_lsu_dbar_e` | in | IBAR / DBAR |
| `ecl_lsu_op_e[6:0]` | in | `LLSU_*` opcode |
| `ecl_lsu_base_e` / `_offset_e` / `_wdata_e` [31:0] | in | rs1, rs2 or imm, store data |
| `lsu_ecl_data_valid_ls3` / `lsu_ecl_data_ls3[31:0]` | out | Load data |
| `lsu_ecl_wr_fin_ls3` | out | Store complete |
| `lsu_ecl_ibar_fin` / `lsu_ecl_dbar_fin` / `lsu_ecl_sc_fin_ls1` | out | Completion in LS1 |
| `lsu_ecl_except_ale_ls1` / `_badv_ls1` | out | ALE |
| `lsu_ecl_except_tlbr_ls2`, `lsu_except_{pil,pis,ppi,pme}_ls2` and `_badv_ls2` | out | TLB exceptions |
| `lsu_ecl_except_buserr_ls3` / `_badv_ls3` | out | Bus error (ADEM) |
| `lsu_ecl_except_ecc_ls3` | out | Tied 0 |
| `lsu_sc` / `lsu_csr_llb_set` / `lsu_csr_llb_clr` | out | SC in progress, LLBit set/clear |
| `csr_lsu_llb` | in | Current LLBit |
| `lsu_biu_rd_req_ls2` / `lsu_biu_rd_addr_ls2[31:0]` | out | Read request, physical address |
| `biu_lsu_rd_ack_ls2` | in | Read request accepted |
| `biu_lsu_data_valid_ls3` / `biu_lsu_data_ls3[63:0]` | in | Read data |
| `biu_lsu_fault_ls3` / `biu_lsu_fault_code_ls3[1:0]` | in | Read fault (code unused) |
| `lsu_biu_wr_req_ls2` / `_addr_ls2[31:0]` / `_data_ls2[63:0]` / `_strb_ls2[7:0]` | out | Write request |
| `biu_lsu_wr_ack_ls2` / `biu_lsu_wr_fin_ls3` | in | Write accepted, completed |
| `biu_lsu_wr_fault_ls3` / `biu_lsu_wr_fault_code_ls3[1:0]` | in | Write fault (code unused) |
| `csr_lsu_crmd_da` / `csr_lsu_crmd_pg` / `csr_dtlb_crmd_plv[1:0]` | in | Translation mode and privilege |
| `csr_lsu_dmw{0,1}_{vseg,pseg}[2:0]` | in | DMW windows |
| `csr_dtlb_asid_asid[9:0]` / `csr_dtlb_tlbehi_vppn[18:0]` | in | Search / write key |
| `csr_dtlb_tlbidx_{ne,ps,i_d,index}`, `csr_dtlb_tlbelo{0,1}_{ppn,g,mat,plv,d,v}`, `csr_dtlb_tlbrefill_ctx` | in | TLB write data and control |
| `csr_dtlb_tlbfill_vld_e` / `csr_dtlb_tlbwr_vld_e` / `exu_dtlb_random_index[4:0]` | in | TLBFILL / TLBWR |
| `exu_dtlb_tlbsrch_vld_e` / `exu_dtlb_tlbsrch_vld_m` | in | TLBSRCH issue / result cycle |
| `exu_dtlb_invtlb_vld_e` / `_op_e[4:0]` / `_asid_e[9:0]` / `_vppn_e[18:0]` | in | INVTLB |
| `dtlb_csr_*` | out | DTLB read and TLBSRCH results to CSR |
