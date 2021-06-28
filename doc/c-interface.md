# Accelerator Interconnect Interface (C-Interface)
The C-Interface implements signal routing from and to the accelerator units.

## Interface Definition

The C-Interface features two independent decoupled channels for offloading requests and accelerator writeback.
The C-Interface defines in total four independent decoupled channels communication between the accelerator adapter and the accelerator units.
The C-Request and C-Response channels route instruction offloading requests and accelerator writeback responses.
The CMem-Request and CMem-Response channels route memory transaction requests and responses.

The C and CMem SystemVerilog interfaces are separately defined as independent entities.
Request channel signals are prefixed with the letter `q`.
Response channel signals are prefixed with the letter `p`.

All transactions are handshaked according to the following scheme:
- The initiator asserts `valid`. The assertion of `valid` must not depend on `ready`. The assertion of ready may depend on `valid`.
- Once `valid` has been asserted all data must remain stable.
- The receiver asserts `ready` whenever it is ready to receive the transaction. Asserting `ready` by default is allowed. While `valid` is low, `ready` may be retracted at any time.
- When both `valid` and `ready` are high the transaction is successful.

### Parametrization
The interface is parameterized using the following set of parameters.

| Name              | Type / Range        | Description                                       |
| ----------------- | ------------------- | ------------------------------------------------- |
| `DataWidth`       | `int` (32, 64, 128) | ISA Bit-width                                     |
| `NumReq`          | `int` (>=1)         | Number of requesting entities                     |
| `NumHier`         | `int` (>=1)         | Number of hierarchical interconnect levels        |
| `NumRsp[NumHier]` | `int[NumHier]`      | Number of responding entities per hierarchy level |
| `DualWriteback`   | `bit`               | Support for dual-writeback instructions           |
| `TernaryOps`      | `bit`               | Support for ternary operations (use `rs3`)        |

#### Derived Parameters
| Name            | Value                          | Description                                               |
| --------------- | ------------------------------ | --------------------------------------------------------- |
| `MaxNumRsp`     | `max(NumRsp)`                  | Maximum number of responding entities per hierarchy level |
| `HierAddrWidth` | `clog2(NumHier)`               | Hierarchy level address width                             |
| `AccAddrWidth`  | `clog2(MaxNumRsp)`             | Accelerator address width                                 |
| `AddrWidth`     | `HierAddrWidth + AccAddrWidth` | Overall address width                                     |
| `NumRs`         | `TernaryOps ? 3 : 2`           | Supported number of source registers                      |
| `NumWb`         | `DualWriteback ? 2 : 1`        | Supported number of simultaneous writebacks               |

### Instruction Offloading Interface

#### C-Request Channel
The request channel interface signals are:

| Signal Name       | Type                               | Direction             | Description                 |
| ----------------- | ---------------------------------- | --------------------- | --------------------------- |
| `q_addr`          | `logic [AddrWidth-1:AccAddrWidth]` | Adapter > Accelerator | Accelerator hierarchy level |
|                   | `logic [AccAddrWidth-1:0]`         | Adapter > Accelerator | Accelerator address         |
| `q_hart_id`       | `logic [DataWidth-1:0]`            | Adapter > Accelerator | Hart ID                     |
| `q_instr_data`    | `logic [31:0]`                     | Adapter > Accelerator | RISC-V instruction data     |
| `q_rs[NumRs-1:0]` | `logic [DataWidth]`                | Adapter > Accelerator | Source register contents    |

Notes:
  - The accelerator address `q_addr` is partitioned into the MSB Range identifying the interconnect hierarchy level of the target accelerator and the LSB Range denoting the accelerator address within a given hierarchy level.
  - The `q_hart_id` signal uniquely identifies the response target of any request.
    The signal is latched by the accelerator subsystem and used for eventual route-back of the instruction writeback data.

#### C-Response Channel
*Not* every operation which was offloaded must ultimately return a response.
If a response is returned, the response channel carries the following signals:

| Signal Name       | Range                   | Direction             | Description                                                                   |
| ----------------- | ----------------------- | --------------------- | ----------------------------------------------------------------------------- |
| `p_hart_id`       | `logic [DataWidth-1:0]` | Accelerator > Adapter | Hart ID                                                                       |
| `p_rd`            | `logic [4:0]`           | Accelerator > Adapter | Destination register address                                                  |
| `p_data[NumWb:0]` | `logic [DataWidth-1:0]` | Accelerator > Adapter | Instruction response data                                                     |
| `p_dualwb`        | `logic`                 | Accelerator > Adapter | Dual-Writeback Response (constant `1'b0`, if dual-writeback is not supported) |
| `p_type`          | `logic`                 | Accelerator > Adapter | Response type                                                                 |
| `p_error`         | `logic`                 | Accelerator > Adapter | Error Flag                                                                    |

Notes:
  - The `p_hart_id` signal identifies the target core for writeback of the offloaded instruction.
  - The instruction response type signal `p_type` encodes the nature of the response.
      - `1'b0` encodes regular integer register file writeback.
      - `1'b1` encodes an external memory operation response.
  - `p_data` carries the response data resulting from the offloaded instruction.
    - For regular integer register writeback responses, `p_data[NumWb-1:0]` carries the writeback data resulting from offloaded instructions.
      `p_data[0]` carries the default writeback data and is written to the destination regiser identified by `p_rd`.
      If dual-writeback instructions are supported, `p_data[1]` may carry the secondary writeback data written to `p_rd+1`.
      For dual-writeback instructions, `p_rd` must specify an even destination register other than `X0`.
    - For external memory transaction responses, the field `p_data[0]` carries the offending memory address in case of an access fault encountered by the external memory operation and `'0` otherwise.
  - Dual writeback instructions are marked by the accelerator sub-system by setting `p_dualwb`.
    If dual-writeback instructions are not supported (`DualWriteback == 0`), `the signal must be constantly tied to 0.
  - The error flag included in the response channel indicates processing errors encountered by the accelerator.

### Memory Transaction Interface

#### CMem-Request Channel
The request channel signals from the accelerator units to the accelerator adapter are:

| Signal Name          | Type                               | Direction             | Description                                               |
| -------------------- | ---------------------------------- | --------------------- | --------------------------------------------------------- |
| `q_hart_id`          | `logic [DataWidth-1:0]`            | Accelerator > Adapter | Hart ID                                                   |
| `q_addr`             | `logic [AddrWidth-1:AccAddrWidth]` | Accelerator > Adapter | Accelerator hierarchy level                               |
|                      | `logic [AccAddrWidth-1:0]`         | Accelerator > Adapter | Accelerator address                                       |
| `q_laddr`            | `logic [DataWidth-1:0]`            | Accelerator > Adapter | Target logical memory address                             |
| `q_wdata`            | `logic [DataWidth-1:0]`            | Accelerator > Adapter | Memory write data.                                        |
| `q_width`            | `logic [2:0]`                      | Accelerator > Adapter | Memory access width (byte, half-word, word, [...])        |
| `q_req_type`         | `mem_req_type_e`                   | Accelerator > Adapter | Request type (R/W/X)                                      |
| `q_mode`             | `logic`                            | Accelerator > Adapter | Memory access mode (standard / probe)                     |
| `q_spec`             | `logic`                            | Accelerator > Adapter | Speculative memory operation (no trap upon access faults) |
| `q_endoftransaction` | `logic`                            | Accelerator > Adapter | Indicates the end of a memory operation sequence          |

#### CMem-Response Channel
The response channel signals from the accelerator adapter to the accelerator unit are:

| Signal Name  | Type                           | Direction             | Description                           |
| ------------ | ------------------------------ | --------------------- | ------------------------------------- |
| `p_addr`     | `logic [AddrWidth-1:0]`        | Adapter > Accelerator | Accelerator address                   |
| `p_hart_id`  | `logic [DataWidth-1:0]`        | Adapter > Accelerator | Hart ID                               |
| `p_rdata`    | `logic [DataWidth-1:0]`        | Adapter > Accelerator | Memory response data.                 |
| `p_range`    | `logic [clog2(DataWidth)-1:0]` | Adapter > Accelerator | Validity LSB range of memory metadata |
| `p_status`   | `logic`                        | Adapter > Accelerator | Transaction status (success / fail)   |

Notes:
  - The response transaction status `p_status` field indicates the success (`p_status = 1'b1`) or failure (`p_status = 1'b0`) of the memory operation.
      - For standard requests, the status field indicates if the operation raised an access fault exception.
      - For probing memory requests, the status field indicates if the requested access has been granted.
  - The `p_range` field carries information on the memory region queried with a probing memory request.
    If the `p_status` field signals access has been granted, this field specifies the number of bits that can be changed in the logical address without changing the metadata

## Master/Slave Interface Ports
- A C-interface master port is defined to source C-request signals and sink C-response signals
- A C-interface slave port is defined to sink C-request signals and source C-response signals.
- A CMem-interface master port is defined to source CMem-request signals and sink CMem-response signals.
- A CMem-interface slave portis defined to sink CMem-request signals and source CMem-response signals.
