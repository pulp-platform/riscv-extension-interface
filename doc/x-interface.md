# Offloading Interface (X-Interface)
The X-Interface implements accelerator-agnostic instruction offloading and translation to the accelerator interconnect C-Interface.

## Interface Definition
The X-Interface defines in total four independent decoupled channels communication between the accelerator adapter and the offloading processor core.
The X-Request and X-Response channels route instruction offloading requests and accelerator writeback responses.
The XMem-Request and XMem-Response channels route memory transaction requests and responses.

The X and XMem SystemVerilog interfaces are separately defined as independent entities.
Request channel signals are prefixed with the letter `q`.
Response channel signals are prefixed with the letter `p`.

All transactions are handshaked according to the following scheme:
- The initiator asserts `valid`. The assertion of `valid` must not depend on `ready`. The assertion of ready may depend on `valid`.
- Once `valid` has been asserted all data must remain stable unless otherwise noted (see [X-Request transactions](#offload-x-request-transactions)).
- The receiver asserts `ready` whenever it is ready to receive the transaction. Asserting `ready` by default is allowed. While `valid` is low, `ready` may be retracted at any time.
- When both `valid` and `ready` are high the transaction is successful.

### Parameterization
The interface is parameterized using the following set of parameters.

| Name               | Type / Range        | Description                                      |
| ------------------ | ------------------- | ------------------------------------------------ |
| `DataWidth`        | `int` (32, 64, 128) | ISA bit-width                                    |
| `TernaryOps`       | `bit`               | Support for ternary operations (use `rs3`)       |
| `DualWriteback`    | `bit`               | Support for dual-writeback instructions          |

#### Derived Parameters
| Name    | Value                   | Description                                 |
| ------- | ----------------------- | ------------------------------------------- |
| `NumRs` | `TernaryOps ? 3 : 2`    | Supported number of source registers        |
| `NumWb` | `DualWriteback ? 2 : 1` | Supported number of simultaneous writebacks |

### Instruction Offloading Interface
#### X-Request Channel
The request channel signals are:
| Signal Name       | Type                    | Direction      | Description                                                |
| ----------------- | ----------------------- | -------------- | ---------------------------------------------------------- |
| `q_instr_data`    | `logic [31:0]`          | Core > Adapter | Instruction data (ID stage)                                |
| `q_rs[NumRs-1:0]` | `logic [DataWidth-1:0]` | Core > Adapter | Source register contents                                   |
| `q_rs_valid`      | `logic [NumRs-1:0]`     | Core > Adapter | Source register valid indicator                            |
| `q_rd_clean`      | `logic [NumWb-1:0]`     | Core > Adapter | Scoreboard status of destination register                  |
| `k_accept`        | `logic`                 | Adapter > Core | Offload request acceptance indicator                       |
| `k_is_mem_op`     | `logic`                 | Adapter > Core | Offloaded instruction is a memory operation                |
| `k_writeback`     | `logic [NumWb-1:0]`     | Adapter > Core | Mark outstanding accelerator writeback to`rd` (and `rd+1`) |

Additionally, the handshake signals `q_ready` and `q_valid` are implemented.

##### X-Request Transaction
The instruction offloading process takes place according to the following scheme:
- The offloading core asserts `q_valid` upon encountering an unknown instruction in the instruction decode stage, initiating a transaction.
- Once `q_valid` has been asserted, `q_instr_data` must remain stable.
- The signals `q_rs_valid[i]` indicate the status of the source registers `q_rs[i]`.
  `q_rs_valid[i]` may initially be 0 and change to 1 during the transaction.
  While `q_rs_valid[i]` is low, `q_rs[i]` may change.
  Once `q_valid` and `q_rs_valid[i]` have been asserted, `q_rs_valid[i]` and `q_rs[i]` must remain stable.
- `q_rd_clean` indicates there is no pending writeback to the specified the destination register.
  It may initially be 0 and change to 1 during the transaction.
  Once `q_rd_clean` is asserted, it must remain stable.
- The accelerator adapter asserts `q_ready`, if
    - The instruction is accepted by any of the connected predecoders:
      - The required source registers are marked valid by the offloading core  (`q_rs_valid`).
      - There are no writebacks pending to the destination register (`q_rd_clean`).
      - There are no pending memory operations in either the core pipeline or any of the connected accelerators. (status signal `core_mem_pending` and adapter-internal book-keeping)
      The adapter asserts `k_accept` to indicate a valid offload instruction and `k_writeback` if writeback is excpected.
    - The instruction is not accepted by any of the connected predecoders.
      The adapter de-asserts `k_accept` and `k_writeback` to indicate an illegal instruction has been encountered.
- When both `q_valid` and `q_ready` are high, the transaction is successful

#### X-Response Channel
The response channel signals are:

| Signal Name       | Type                    | Direction      | Description                                                                   |
| ----------------- | ----------------------- | -------------- | ----------------------------------------------------------------------------- |
| `p_rd`            | `logic [4:0]`           | Adapter > Core | Destination register address                                                  |
| `p_data[NumWb:0]` | `logic [DataWidth-1:0]` | Adapter > Core | Instruction response data                                                     |
| `p_dualwb`        | `logic`                 | Adapter > Core | Dual-Writeback response (constant `1'b0`, if dual-writeback is not supported) |
| `p_type`          | `logic`                 | Adapter > Core | Response type                                                                 |
| `p_error`         | `logic`                 | Adapter > Core | Error flag                                                                    |

Notes:
  - The instruction response type signal `p_type` encodes the nature of the response.
      - `1'b0` encodes regular integer register file writeback.
      - `1'b1` encodes an external memory operation response.
  - `p_data` carries the response data resulting from the offloaded instruction.
    - For regular integer register writeback responses, `p_data[NumWb-1:0]` carries the writeback data resulting from offloaded instructions.
      `p_data[0]` carries the default writeback data and is written to the destination regiser identified by `p_rd`.
      If dual-writeback instructions are supported, `p_data[1]` may carry the secondary writeback data written to `p_rd+1`.
      For dual-writeback instructions, `p_rd` must specify an even destination register other than `X0`.
    - For external memory transaction responses, the field `p_data[0]` carries the offending memory address in case of an access fault encountered by the external memory operation and `'0` otherwise.
  - Dual writeback responses are marked by the accelerator sub-system by setting `p_dualwb`.
    If dual-writeback instructions are not supported (`DualWriteback == 0`), the signal must be constantly tied to 0.
  - The error flag included in the response channel indicates processing errors encountered by the accelerator.

### Memory Transaction Interface

#### XMem-Request Channel

The request channel signals from the adapter to the offloading core are:

| Signal Name          | Type                    | Direction      | Description                                               |
| -------------------- | ----------------------- | -------------- | --------------------------------------------------------- |
| `q_laddr`            | `logic [DataWidth-1:0]` | Adapter > Core | Target logical memory address                             |
| `q_wdata`            | `logic [DataWidth-1:0]` | Adapter > Core | Memory write data                                         |
| `q_width`            | `logic [1:0]`           | Adapter > Core | Memory access width (byte, half-word, word, [...])        |
| `q_req_type`         | `mem_req_type_e`        | Adapter > Core | Request type (R/W/X)                                      |
| `q_mode`             | `logic`                 | Adapter > Core | Memory access mode (standard / probe)                     |
| `q_spec`             | `logic`                 | Adapter > Core | Speculative memory operation (no trap upon access faults) |
| `q_endoftransaction` | `logic`                 | Adapter > Core | Indicates the end of a memory operation sequence          |

#### XMem-Response Channel

The response channel signals from the offloading core to the adapter are:

| Signal Name | Type                           | Direction             | Description                           |
| ----------- | ------------------------------ | --------------------- | ------------------------------------- |
| `p_rdata`   | `logic [DataWidth-1:0]`        | Core > Adapter        | Memory response data.                 |
| `p_range`   | `logic [clog2(DataWidth)-1:0]` | Core > Adapter        | Validity LSB range of memory metadata |
| `p_status`  | `logic`                        | Core > Adapter        | Transaction status (success / fail)   |

Notes:
  - The response transaction status `p_status` field indicates the success (`p_status = 1'b1`) or failure (`p_status = 1'b0`) of the memory operation.
      - For standard requests, the status field indicates if the operation raised an access fault exception.
      - For probing memory requests, the status field indicates if the requested access has been granted.
  - The `p_range` field carries information on the memory region queried with a probing memory request.
    If the `p_status` field signals access has been granted, this field specifies the number of bits that can be changed in the logical address without changing the metadata

## Master/Slave Interface Ports
- An X-interface master port is defined to source X-request signals and sink X-response signals
- An X-interface slave port is defined to sink X-request signals and source X-response signals.
- An XMem-interface master port is defined to source XMem-request signals and sink XMem-response signals.
- An XMem-interface slave portis defined to sink XMem-request signals and source XMem-response signals.
