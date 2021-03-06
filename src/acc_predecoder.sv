// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Noam Gallmann <gnoam@live.com>

// Per-extension instruction metadata predecoder

module acc_predecoder #(
    parameter int                       NumInstr               = 1,
    parameter acc_pkg::offload_instr_t  OffloadInstr[NumInstr] = {0}
) (
    input  acc_pkg::acc_prd_req_t prd_req_i,
    output acc_pkg::acc_prd_rsp_t prd_rsp_o
);

  import acc_pkg::*;

  acc_prd_rsp_t [NumInstr-1:0] instr_rsp;
  logic         [NumInstr-1:0] instr_sel;

  for (genvar i = 0; i < NumInstr; i++) begin : gen_predecoder_selector
    assign instr_sel[i] =
      ((OffloadInstr[i].instr_mask & prd_req_i.q_instr_data) == OffloadInstr[i].instr_data);
  end

  for (genvar i = 0; i < NumInstr; i++) begin : gen_predecoder_mux
    assign instr_rsp[i].p_accept    = instr_sel[i] ? 1'b1 : 1'b0;
    assign instr_rsp[i].p_writeback = instr_sel[i] ? OffloadInstr[i].prd_rsp.p_writeback : '0;
    assign instr_rsp[i].p_is_mem_op = instr_sel[i] ? OffloadInstr[i].prd_rsp.p_is_mem_op : '0;
    assign instr_rsp[i].p_use_rs    = instr_sel[i] ? OffloadInstr[i].prd_rsp.p_use_rs : '0;
  end

  always_comb begin
    prd_rsp_o.p_accept    = 1'b0;
    prd_rsp_o.p_writeback = '0;
    prd_rsp_o.p_is_mem_op = '0;
    prd_rsp_o.p_use_rs    = '0;
    for (int unsigned i = 0; i < NumInstr; i++) begin
      prd_rsp_o.p_accept    |= instr_rsp[i].p_accept;
      prd_rsp_o.p_writeback |= instr_rsp[i].p_writeback;
      prd_rsp_o.p_is_mem_op |= instr_rsp[i].p_is_mem_op;
      prd_rsp_o.p_use_rs    |= instr_rsp[i].p_use_rs;
    end
  end

endmodule

