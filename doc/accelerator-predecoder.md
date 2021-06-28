# Accelerator Predecoder Module Specification
The accelerator predecoder module implements the actual identification of offloadable instructions for a specific connected accelerator unit.

## Context
The accelerator predecoders are instantiated in a flat array of modules to the accelerator adapter.
The first `NumRsp[0]` predecoders correspond to the accelerator units in the accelerator interconnect hierarchy 0.
Predecoders `NumRsp[0]+1 ... NumRsp[1]` correspond to the accelerator units in the hierarchy level 1 [...].
The connection order of the accelerator units to the accelerator interconnect in each level must correspond to the the connection order of the predecoders to the adapter module.

![Accelerator Adapter Detail](img/acc-adapter-detail.svg)

## Interface

The accelerator predecoder modules contain entirely combinational logic to identify all data needed for the offloading core to correctly offload an instruction.
The accelerator predecoder signals are:


### Request Channel
| Signal Name    | Type          | Direction            | Description              |
| -------------- | ------------- | -------------------- | ------------------------ |
| `q_instr_data` | `logic[31:0]` | Adapter > Predecoder | RISC-V Instruction Data. |

### Response Channel
The response channel signals are summarized in the SystemVerilog struct `prd_rsp_t`.

| Signal Name   | Type          | Direction            | Description                                                                       |
| ------------- | ------------- | -------------------- | --------------------------------------------------------------------------------- |
| `p_accept`    | `logic`       | Predecoder > Adapter | Indicates valid instruction                                                       |
| `p_writeback` | `logic [1:0]` | Predecoder > Adapter | Instruction writeback to `rd` (`p_writeback[0]`) and `rd + 1` (`p_writeback[1]`)  |
| `p_use_rs`    | `logic [2:0]` | Predecoder > Adapter | Asserting `p_use_rs[i]` implies the instruction requires source register `rs[i]`. |
| `p_is_mem_op` | `logic`       | Predecoder > Adapter | Instruction is memory access                                                      |

## Parameterization
To support decoding arbitrary offload instructions, the following SystemVerilog struct `offload_instr_t` is defined.

| Signal name  | Type           | Description                                                         |
| ------------ | -------------- | ------------------------------------------------------------------- |
| `instr_data` | `logic [31:0]` | Instruction data matching the offloaded instruction                 |
| `instr_mask` | `logic [31:0]` | Bitmask, masking off decode-irrelevant bits of the instruction data |
| `prd_rsp`    | `prd_rsp_t`    | Predefined predecoder response                                      |

The accelerator predecoder module is parameterized as follows:

| Name                     | Type                        | Description                              |
| ------------------------ | --------------------------- | ---------------------------------------- |
| `NumInstr`               | `int` (>=1)                 | Total number of offloadable instructions |
| `OffloadInstr[NumInstr]` | `offload_instr_t[NumInstr]` | Offload instruction metadata             |


