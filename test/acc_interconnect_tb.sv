// Copyright 2020 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Noam Gallmann <gnoam@live.com>
//
// Simulates one hierarchy level of the accelerator interconnect.

`include "acc_interface/assign.svh"
`include "acc_interface/typedef.svh"

module acc_interconnect_tb  #(
  parameter int HierLevel       = 1, // 0, .., NumHier-1
  parameter int NumReq          = 8,
  parameter bit RegisterReq     = 1,
  parameter bit RegisterRsp     = 1,
  // TB params
  parameter int unsigned NrRandomTransactions = 1000
);

  // All relevant top-level design parameters are derived from the following base parameters
  // defined in acc_pkg.

  // ISA bit width:
  // --- parameter int DataWidth
  // Number of interconnect hierarchy levels:
  // --- parameter int NumHier
  // Number of responders per hierarchy level:
  // --- parameter int NumRsp[NumHier]
  // Support for ternary operations:
  // --- parameter bit TernaryOps
  // Support for dual writeback instructions:
  // --- parameter bit DualWriteback
  // Insert pipeline stage at hierarchy level X, request path:
  // --- parameter bit RegisterReq [NumHier]
  // Insert pipeline stage at hierarchy level X, response path:
  // --- parameter bit RegisterRsp [NumHier]

  // The following dependent parameters are derived:
  //
  // Total number of connected accelerators
  // --- parameter int unsigned NumRspTot
  // Maximum number of accelerators per sharing level
  // --- parameter int unsigned MaxNumRsp
  // Hierarchy address width
  // --- parameter int unsigned HierAddrWidth
  // Per-level accelerator addresss width
  // --- parameter int unsigned AccAddrWidth
  // Total Address Width
  // --- parameter int unsigned AddrWidth
  // Number of source regs
  // --- parameter int unsigned NumRs
  // Number of simultaneous writebacks.
  // --- parameter int unsigned NumWb
  // dependent parameters

  import acc_pkg::*;

  typedef acc_test::c_req_t #(
    .AddrWidth ( AddrWidth ),
    .DataWidth ( DataWidth ),
    .NumRs     ( NumRs     )
  ) tb_c_req_t;

  typedef acc_test::c_rsp_t #(
    .DataWidth ( DataWidth ),
    .NumWb     ( NumWb     )
  ) tb_c_rsp_t;

  typedef acc_test::cmem_req_t #(
    .AddrWidth ( AddrWidth ),
    .DataWidth ( DataWidth )
  ) tb_cmem_req_t;

  typedef acc_test::cmem_rsp_t #(
    .AddrWidth ( AddrWidth ),
    .DataWidth ( DataWidth )
  ) tb_cmem_rsp_t;

  // Timing params
  localparam time ClkPeriod = 10ns;
  localparam time ApplTime =  2ns;
  localparam time TestTime =  8ns;

  logic clk, rst_n;

  ACC_C_BUS #(
    .AddrWidth     ( AddrWidth     ),
    .DataWidth     ( DataWidth     ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    )
  ) c_master[NumReq] ();

  ACC_C_BUS_DV #(
    .AddrWidth     ( AddrWidth     ),
    .DataWidth     ( DataWidth     ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    )
  ) c_master_dv[NumReq] (
    clk
  );

  ACC_C_BUS #(
    .AddrWidth     ( AddrWidth     ),
    .DataWidth     ( DataWidth     ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    )
  ) c_slave_next[NumReq] ();

  ACC_C_BUS_DV #(
    .AddrWidth     ( AddrWidth     ),
    .DataWidth     ( DataWidth     ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    )
  ) c_slave_next_dv[NumReq] (
    clk
  );

  ACC_C_BUS #(
    .AddrWidth     ( AddrWidth     ),
    .DataWidth     ( DataWidth     ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    )
  ) c_slave[NumRsp[HierLevel]] ();

  ACC_C_BUS_DV #(
    .AddrWidth     ( AddrWidth     ),
    .DataWidth     ( DataWidth     ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    )
  ) c_slave_dv[NumRsp[HierLevel]](
    clk
  );

  ACC_CMEM_BUS #(
    .DataWidth(DataWidth),
    .AddrWidth(AddrWidth)
  ) cmem_slave [NumReq] ();

  ACC_CMEM_BUS_DV #(
    .DataWidth(DataWidth),
    .AddrWidth(AddrWidth)
  ) cmem_slave_dv [NumReq] (
    clk
  );

  ACC_CMEM_BUS #(
    .DataWidth(DataWidth),
    .AddrWidth(AddrWidth)
  ) cmem_master_next [NumReq] ();

  ACC_CMEM_BUS_DV #(
    .DataWidth(DataWidth),
    .AddrWidth(AddrWidth)
  ) cmem_master_next_dv [NumReq] (
    clk
  );

  ACC_CMEM_BUS #(
    .DataWidth(DataWidth),
    .AddrWidth(AddrWidth)
  ) cmem_master [NumRsp[HierLevel]] ();

  ACC_CMEM_BUS_DV #(
    .DataWidth(DataWidth),
    .AddrWidth(AddrWidth)
  ) cmem_master_dv [NumRsp[HierLevel]] (
    clk
  );

  for (genvar i = 0; i < NumReq; i++) begin : gen_c_mst_if_assignement
    `ACC_C_ASSIGN(c_master[i], c_master_dv[i])
  end

  for (genvar i = 0; i < NumReq; i++) begin : gen_c_mst_next_if_assignement
    `ACC_C_ASSIGN(c_slave_next_dv[i], c_slave_next[i])
  end

  for (genvar i = 0; i < NumRsp[HierLevel]; i++) begin : gen_c_slv_if_assignement
    `ACC_C_ASSIGN(c_slave_dv[i], c_slave[i])
  end

  for (genvar i = 0; i < NumReq; i++) begin : gen_cmem_slv_if_assignement
    `ACC_CMEM_ASSIGN(cmem_slave_dv[i], cmem_slave[i])
  end

  for (genvar i = 0; i < NumReq; i++) begin : gen_cmem_slv_next_if_assignement
    `ACC_CMEM_ASSIGN(cmem_master_next[i], cmem_master_next_dv[i])
  end

  for (genvar i = 0; i < NumRsp[HierLevel]; i++) begin : gen_cmem_mst_if_assignement
    `ACC_CMEM_ASSIGN(cmem_master[i], cmem_master_dv[i])
  end

  // ----------------
  // Clock generation
  // ----------------
  initial begin
    rst_n = 0;
    repeat (3) begin
      #(ClkPeriod / 2) clk = 0;
      #(ClkPeriod / 2) clk = 1;
    end
    rst_n = 1;
    forever begin
      #(ClkPeriod / 2) clk = 0;
      #(ClkPeriod / 2) clk = 1;
    end
  end

  // -------
  // Monitor
  // -------

  // C Monitors
  // ----------
  typedef acc_test::acc_c_slv_monitor #(
    .DataWidth     ( DataWidth     ),
    .AddrWidth     ( AddrWidth     ),
    .NumReq        ( NumReq        ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    ),
    .TA            ( ApplTime      ),
    .TT            ( TestTime      )
  ) acc_c_slv_monitor_t;

  typedef acc_test::acc_c_mst_monitor #(
    .DataWidth     ( DataWidth     ),
    .AddrWidth     ( AddrWidth     ),
    .AccAddrWidth  ( AccAddrWidth  ),
    .HierLevel     ( HierLevel     ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    ),
    .TA            ( ApplTime      ),
    .TT            ( TestTime      )
  ) acc_c_mst_monitor_t;

  acc_c_mst_monitor_t acc_c_mst_monitor[NumReq];
  for (genvar i=0; i<NumReq; i++) begin : gen_c_mst_mon
    initial begin
      acc_c_mst_monitor[i] = new(c_master_dv[i]);
      @(posedge rst_n);
      acc_c_mst_monitor[i].monitor();
    end
  end

  acc_c_slv_monitor_t acc_c_slv_monitor[NumRsp[HierLevel]];
  for (genvar i=0; i<NumRsp[HierLevel]; i++) begin : gen_c_slv_mon
    initial begin
      acc_c_slv_monitor[i] = new(c_slave_dv[i]);
      @(posedge rst_n);
      acc_c_slv_monitor[i].monitor();
    end
  end

  acc_c_slv_monitor_t acc_c_fwd_slv_monitor[NumReq];
  for (genvar i=0; i<NumReq; i++) begin : gen_c_fwd_slv_mon
    initial begin
      acc_c_fwd_slv_monitor[i] = new(c_slave_next_dv[i]);
      @(posedge rst_n);
      acc_c_fwd_slv_monitor[i].monitor();
    end
  end

  // CMem Monitors
  // -------------
  typedef acc_test::acc_cmem_slv_monitor #(
    .DataWidth     ( DataWidth     ),
    .AddrWidth     ( AddrWidth     ),
    .NumReq        ( NumReq        ),
    .TA            ( ApplTime      ),
    .TT            ( TestTime      )
  ) acc_cmem_slv_monitor_t;

  typedef acc_test::acc_cmem_mst_monitor #(
    .DataWidth     ( DataWidth     ),
    .AddrWidth     ( AddrWidth     ),
    .NumReq        ( NumReq        ),
    .TA            ( ApplTime      ),
    .TT            ( TestTime      )
  ) acc_cmem_mst_monitor_t;

  acc_cmem_mst_monitor_t acc_cmem_mst_monitor[NumRsp[HierLevel]];
  for (genvar i=0; i<NumRsp[HierLevel]; i++) begin : gen_cmem_mst_mon
    initial begin
      acc_cmem_mst_monitor[i] = new(cmem_master_dv[i]);
      @(posedge rst_n);
      acc_cmem_mst_monitor[i].monitor();
    end
  end

  acc_cmem_mst_monitor_t acc_cmem_mst_next_monitor[NumReq];
  for (genvar i=0; i<NumReq; i++) begin : gen_cmem_mst_next_mon
    initial begin
      acc_cmem_mst_next_monitor[i] = new(cmem_master_next_dv[i]);
      @(posedge rst_n);
      acc_cmem_mst_next_monitor[i].monitor();
    end
  end

  acc_cmem_slv_monitor_t acc_cmem_slv_monitor[NumReq];
  for (genvar i=0; i<NumReq; i++) begin : gen_cmem_slv_mon
    initial begin
      acc_cmem_slv_monitor[i] = new(cmem_slave_dv[i]);
      @(posedge rst_n);
      acc_cmem_slv_monitor[i].monitor();
    end
  end

  // ------
  // Driver
  // ------

  // C Drivers
  // ---------
  typedef acc_test::rand_c_slave #(
    .DataWidth     ( DataWidth     ),
    .AddrWidth     ( AddrWidth     ),
    .NumReq        ( NumReq        ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    ),
    .TA            ( ApplTime      ),
    .TT            ( TestTime      )
  ) rand_c_slave_t;

  // Slaves connected to this interconnect level
  rand_c_slave_t rand_c_slave[NumRsp[HierLevel]];
  for (genvar i=0; i<NumRsp[HierLevel]; i++) begin : gen_c_slv_driver
    initial begin
      rand_c_slave[i] = new(c_slave_dv[i]);
      rand_c_slave[i].reset();
      @(posedge rst_n);
      rand_c_slave[i].run();
    end
  end

  // Slaves connected to higher interconnect levels
  rand_c_slave_t rand_c_fwd_slave[NumReq];
  for (genvar i=0; i<NumReq; i++) begin : gen_c_slv_fwd_driver
    initial begin
      rand_c_fwd_slave[i] = new(c_slave_next_dv[i]);
      rand_c_fwd_slave[i].reset();
      @(posedge rst_n);
      rand_c_fwd_slave[i].run();
    end
  end

  typedef acc_test::rand_c_master #(
    .DataWidth     ( DataWidth     ),
    .AccAddrWidth  ( AccAddrWidth  ),
    .AddrWidth     ( AddrWidth     ),
    .NumRsp        ( NumRsp        ),
    .NumHier       ( NumHier       ),
    .HierLevel     ( HierLevel     ),
    .DualWriteback ( DualWriteback ),
    .TernaryOps    ( TernaryOps    ),
    .TA            ( ApplTime      ),
    .TT            ( TestTime      )
  ) rand_c_master_t;

  rand_c_master_t rand_c_master[NumReq];

  for (genvar i=0; i<NumReq; i++) begin : gen_c_mst_driver
    initial begin
      automatic acc_test::rand_hart_id hid = new;
      rand_c_master[i] = new(c_master_dv[i], hid.hart_id);
      rand_c_master[i].reset();
      @(posedge rst_n);
      rand_c_master[i].run(NrRandomTransactions);
    end
  end

  // CMem Drivers
  // ------------
 typedef acc_test::rand_cmem_slave #(
    .DataWidth     ( DataWidth     ),
    .AddrWidth     ( AddrWidth     ),
    .TA            ( ApplTime      ),
    .TT            ( TestTime      )
  ) rand_cmem_slave_t;

  rand_cmem_slave_t rand_cmem_slave[NumReq];
  for (genvar i=0; i<NumReq; i++) begin : gen_cmem_slv_driver
    initial begin
      rand_cmem_slave[i] = new(cmem_slave_dv[i]);
      rand_cmem_slave[i].reset();
      @(posedge rst_n);
      rand_cmem_slave[i].run();
    end
  end

  typedef acc_test::rand_cmem_master #(
    .DataWidth     ( DataWidth     ),
    .AddrWidth     ( AddrWidth     ),
    .TA            ( ApplTime      ),
    .TT            ( TestTime      )
  ) rand_cmem_master_t;

  rand_cmem_master_t rand_cmem_master[NumRsp[HierLevel]];
  for (genvar i=0; i<NumRsp[HierLevel]; i++) begin : gen_cmem_mst_driver
    logic [AddrWidth-1:0] AccAddr = unsigned'(HierLevel)<<AccAddrWidth | unsigned'(i);
    initial begin
      //$display("rand_cmem_master: AccAddr= %x\n", AccAddr);
      rand_cmem_master[i] = new(cmem_master_dv[i], AccAddr);
      rand_cmem_master[i].reset();
      @(posedge rst_n);
      rand_cmem_master[i].run(NrRandomTransactions);
    end
  end

  rand_cmem_master_t rand_cmem_fwd_master[NumReq];
  for (genvar i=0; i<NumReq; i++) begin : gen_cmem_mst_fwd_driver
    // chose any address in another hierarchy level. If HierLevel is highest,
    // this wraps around to level 0. The behavior of the interconnect is the
    // same.
    logic [AddrWidth-1:0] AccAddr = unsigned'(HierLevel+1)<<AccAddrWidth | unsigned'(i);
    initial begin
      //$display("rand_cmem_fwd_master: AccAddr= %x\n", AccAddr);
      rand_cmem_fwd_master[i] = new(cmem_master_next_dv[i], AccAddr);
      rand_cmem_fwd_master[i].reset();
      @(posedge rst_n);
      rand_cmem_fwd_master[i].run(NrRandomTransactions);
    end
  end


  class scoreboard_tracker;
    static int nr_c_requests;
    static int nr_c_responses;
    static int nr_cmem_requests;
    static int nr_cmem_responses;
  endclass

  ////////////////
  // Scoreboard //
  ////////////////

  // C Request Path
  // --------------
  // Map each C request observed at the accelerator request output to a request generated at
  // a core request input port.
  initial begin
    scoreboard_tracker::nr_c_requests = 0;
    @(posedge rst_n);
    for (int kk=0; kk<NumReq; kk++) begin  // masters k
      automatic int k = kk;
      fork
        // Check requests to same-level slaves
        for (int ii=0; ii<NumRsp[HierLevel]; ii++) begin  // slaves i
          fork
            automatic int i = ii;
            forever begin
              automatic tb_c_req_t req_mst;
              automatic tb_c_req_t req_slv;
              automatic tb_c_req_t req_slv_all[NumReq];
              automatic int sender_id = -1;
              acc_c_slv_monitor[i].req_mbx_cnt.get_direct(req_slv, k);
              scoreboard_tracker::nr_c_requests++;
              for (int l=0; l<NumReq; l++) begin
                if (rand_c_master[l].drv.hart_id == req_slv.hart_id) begin
                  sender_id = l;
                  acc_c_mst_monitor[l].req_mbx[i].get(req_mst);
                end
              end
              assert(sender_id >= 0) else begin
                $error("Request Routing Error: C Slave %0d ", i,
                    "Could not determine origin of C request");
                req_slv.display();
              end
              assert(req_mst.do_compare(req_slv)) else
                $error("Request Mismatch: C master %0d to C slave %0d ", k, i);
              // check that request was intended for slave i
              assert(req_mst.addr[AccAddrWidth-1:0] == i) else
                $error("Request Routing Error: C Master %0d", sender_id);
            end  // -- forever
          join_none
        end  // -- for (int i=0; i<NumRsp[HierLevel]; i++)

        // Check forwarded requests
        fork
          forever begin
            automatic tb_c_req_t req_mst;
            automatic tb_c_req_t req_slv_fwd;
            // Master k has sent interconnect forward port k
            // Check that slave k has received.
            acc_c_fwd_slv_monitor[k].req_mbx_cnt.get_direct(req_slv_fwd, 0);
            acc_c_mst_monitor[k].req_mbx_fwd.get(req_mst);
            assert(req_mst.do_compare(req_slv_fwd)) else
              $error("Forwarded Request Mismatch: C Master %0d", k);
            scoreboard_tracker::nr_c_requests++;
          end  // -- forever
        join_none
      join_none
    end
  end

  // C Response Path
  // ---------------
  // Map each C response observed at the core response output to a response generated at the
  // accelerator response input port.
  initial begin
    scoreboard_tracker::nr_c_responses = 0;
    @(posedge rst_n);
    for (int jj=0; jj<NumReq; jj++) begin
      fork
        automatic int j = jj;
        forever begin
          automatic tb_c_rsp_t rsp_mst;
          automatic tb_c_rsp_t rsp_slv_fwd;
          automatic bit rsp_sender_found = 0;
          acc_c_mst_monitor[j].rsp_mbx.get(rsp_mst);
          scoreboard_tracker::nr_c_responses++;
          // Check this interconnect level
          for (int l = 0; l < NumRsp[HierLevel]; l++) begin
            if (acc_c_slv_monitor[l].rsp_mbx_cnt.num(rsp_mst.hart_id) != 0) begin
              automatic tb_c_rsp_t rsp_slv;
              acc_c_slv_monitor[l].rsp_mbx_cnt.peek(rsp_slv, rsp_mst.hart_id);
              if (rsp_mst.do_compare(rsp_slv)) begin
                acc_c_slv_monitor[l].rsp_mbx_cnt.get(rsp_slv, rsp_mst.hart_id);
                rsp_sender_found |= 1;
                break;
              end
            end
          end

          // Check forwarded responses from upper interconnect levels.
          if (acc_c_fwd_slv_monitor[j].rsp_mbx_cnt.num(rsp_mst.hart_id) != 0) begin
            acc_c_fwd_slv_monitor[j].rsp_mbx_cnt.peek(rsp_slv_fwd, rsp_mst.hart_id);
            if (rsp_mst.do_compare(rsp_slv_fwd)) begin
              acc_c_fwd_slv_monitor[j].rsp_mbx_cnt.get(rsp_slv_fwd, rsp_mst.hart_id);
              rsp_sender_found |= 1;
            end
          end

          assert(rsp_sender_found) else
            $error("Master %0d: Received response but no Sender found", j);
        end
      join_none
    end
  end

  // CMem Request Path
  // -----------------
  // For any CMem request observed at the core request output, check for
  // a request generated at an accelerator request input port.
  initial begin
    scoreboard_tracker::nr_cmem_requests = 0;
    @(posedge rst_n);
    for (int kk=0; kk<NumReq; kk++) begin
      automatic int k = kk;
      fork
        forever begin
          automatic tb_cmem_req_t req_mst;
          automatic tb_cmem_req_t req_slv;
          automatic bit req_sender_found = 0;
          automatic logic[AddrWidth-AccAddrWidth-1:0] lvl_addr;
          automatic logic[AccAddrWidth-1:0] acc_addr;
          acc_cmem_slv_monitor[k].req_mbx.get(req_slv);
          scoreboard_tracker::nr_cmem_requests++;
          lvl_addr = req_slv.addr[AddrWidth-1:AccAddrWidth];
          acc_addr = req_slv.addr[AccAddrWidth-1:0];
          if (lvl_addr == HierLevel) begin
            // Check requests from same-level masters
            req_sender_found =
                acc_cmem_mst_monitor[acc_addr].req_mbx_cnt.try_get(req_mst, req_slv.hart_id);
          end else begin
            // Check requests thorugh forwarding ports
            //req_slv.display();
            req_sender_found =
                acc_cmem_mst_next_monitor[k].req_mbx_cnt.try_get(req_mst, req_slv.hart_id);
          end
          assert(req_sender_found) else begin
            $error("Request Routing Error: CMem Slave %0d: ", k,
                "Could not determine origin of CMem request");
              req_slv.display();
              req_mst.display();
            end
          assert(req_mst.do_compare(req_slv)) else
            $error("Request Mismatch: CMem master (AccAddress): 0x%0x to Cmem slave %0d",
                {lvl_addr, acc_addr}, k);
        end
      join_none
    end
  end

  // CMem Response Path
  // -----------------
  // For any CMem Response observed at the accelerator response output, check for
  // a response generated at a core response input port.
  initial begin
    scoreboard_tracker::nr_cmem_responses = 0;
    @(posedge rst_n);
    // Check responses to same-level masters
    for (int kk=0; kk<NumRsp[HierLevel]; kk++) begin
      automatic int k = kk; // acc_address[AccAddrWidth-1:0]
      fork
        forever begin
          automatic tb_cmem_rsp_t rsp_mst;
          automatic tb_cmem_rsp_t rsp_slv;
          automatic bit rsp_sender_id = -1;
          automatic logic[AccAddrWidth-1:0] acc_addr = k;
          automatic logic[AddrWidth-AccAddrWidth-1:0] lvl_addr = HierLevel;
          acc_cmem_mst_monitor[k].rsp_mbx.get(rsp_mst);
          scoreboard_tracker::nr_cmem_responses++;
          for (int l=0; l<NumReq; l++) begin
            if (rand_c_master[l].drv.hart_id == rsp_mst.hart_id) begin
              rsp_sender_id = l;
              assert(acc_cmem_slv_monitor[l].rsp_mbx_cnt.try_get(rsp_slv, rsp_mst.addr)) else
                $error("Response Routing Error: CMem Slave %0d to CMem Master (acc_addr) 0x%0x",
                    rsp_sender_id, {lvl_addr, acc_addr});
            end
          end
          assert(rsp_sender_id >= 0) else
            $error("Response Routing Error: CMem master (AccAddress) 0x%0x", {lvl_addr, acc_addr},
                "Could not determine origin of CMem response");
            assert(rsp_mst.do_compare(rsp_slv)) else begin
            $error("Response Mismatch: CMem Slave %0d to CMem Master (acc_addr) 0x%0x",
                    rsp_sender_id, {lvl_addr, acc_addr});
                  rsp_mst.display();
                  rsp_slv.display();
          end
        end
      join_none
    end

    // Check forwarded responses
    for (int jj=0; jj<NumReq; jj++) begin
      automatic int j = jj; // forwarding port ID
      fork
        forever begin
          automatic tb_cmem_rsp_t rsp_mst;
          automatic tb_cmem_rsp_t rsp_slv;
          acc_cmem_mst_next_monitor[j].rsp_mbx.get(rsp_mst);
          scoreboard_tracker::nr_cmem_responses++;
          assert(acc_cmem_slv_monitor[j].rsp_mbx_cnt.try_get(rsp_slv, rsp_mst.addr)) else
            $error("Response Routing Error: CMem Slave %0d to CMem Master (forwarding port) %0d",
                  j, j);
          assert(rsp_mst.do_compare(rsp_slv)) else begin
            $error("Response Mismatch: CMem Slave %0d to CMem Master (forwarding port) %0d",
                    j, j);
                rsp_mst.display();
                rsp_slv.display();
          end


        end
      join_none
    end
  end


  // Wait for all transactions to cease
  initial begin
    automatic bit c_req_done = 0;
    automatic bit c_rsp_done = 0;
    automatic bit cmem_req_done = 0;
    automatic bit cmem_rsp_done = 0;

    automatic int NrCTransactions = NumReq * NrRandomTransactions;
    automatic int NrCMemTransactions = NrRandomTransactions * (NumReq + NumRsp[HierLevel]);
    forever begin
      //$monitor(scoreboard_tracker::nr_cmem_responses);
      @(posedge clk);
      c_req_done = scoreboard_tracker::nr_c_requests == NrCTransactions;
      c_rsp_done = scoreboard_tracker::nr_c_responses == NrCTransactions;
      cmem_req_done = scoreboard_tracker::nr_cmem_requests == NrCMemTransactions;
      cmem_rsp_done = scoreboard_tracker::nr_cmem_responses == NrCMemTransactions;
      if (c_req_done && c_rsp_done && cmem_req_done && cmem_rsp_done) break;
    end
    $finish;
  end

  // Check for non-empty mailboxes (unchecked transactions)
  final begin
    for (int i=0; i<NumReq; i++) begin
      assert(acc_c_mst_monitor[i].rsp_mbx.num() == 0);
      assert(acc_c_mst_monitor[i].req_mbx_fwd.num() == 0);
      assert(acc_c_fwd_slv_monitor[i].req_mbx_cnt.empty());
      assert(acc_c_fwd_slv_monitor[i].rsp_mbx_cnt.empty());
      assert(acc_cmem_slv_monitor[i].req_mbx.num() == 0);
      assert(acc_cmem_slv_monitor[i].rsp_mbx_cnt.empty);
      for (int j=0; j<NumRsp[HierLevel]; j++) begin
        assert(acc_c_mst_monitor[i].req_mbx[j].num() == 0);
      end
    end
    for (int j=0; j<NumRsp[HierLevel]; j++) begin
      assert(acc_c_slv_monitor[j].req_mbx_cnt.empty());
      assert(acc_c_slv_monitor[j].rsp_mbx_cnt.empty());
      assert(acc_cmem_mst_monitor[j].rsp_mbx.num() == 0);
      assert(acc_cmem_mst_monitor[j].req_mbx_cnt.empty());
      assert(acc_cmem_mst_next_monitor[j].req_mbx_cnt.empty());
      assert(acc_cmem_mst_next_monitor[j].rsp_mbx.num() == 0);
    end
    $display("Checked for non-empty mailboxes.");
  end

  acc_interconnect_intf #(
    .HierLevel     ( HierLevel         ),
    .NumReq        ( NumReq            ),
    .NumRsp        ( NumRsp[HierLevel] ),
    .RegisterReq   ( RegisterReq       ),
    .RegisterRsp   ( RegisterRsp       )
  ) dut (
    .clk_i             ( clk              ),
    .rst_ni            ( rst_n            ),
    .acc_c_slv         ( c_master         ),
    .acc_c_mst_next    ( c_slave_next     ),
    .acc_c_mst         ( c_slave          ),
    .acc_cmem_mst      ( cmem_slave       ),
    .acc_cmem_slv_next ( cmem_master_next ),
    .acc_cmem_slv      ( cmem_master      )
  );

endmodule
