# Accelerator Adapter Module Specification
The [accelerator adapter module](../src/acc_adapter.sv) implements accelerator-agnostic instruction offloading from the CPU core to the accelerator interconnect.
The core-side connection implements the instruction offloading [X-interface](x-interface.md).
The accelerator adapter connects to the accelerator interconnect through the [C-interface](c-interface.md).
The adapter module operates in conjunction with an array of accelerator-specific [predecoder modules](accelerator-predecoder.md).

![Accelerator Adapter](img/acc-adapter.svg)

## Module Variations
- The module `acc_adapter_intf` features port connections using the SystemVerilog `ACC_C_BUS` and `ACC_X_BUS` interfaces defined [here](../src/acc_intf.sv).
- The module `acc_adapter` features port connections using packed structs typedefs for the according request and response channels.


## Parameterization
The accelerator adapter module is parameterized as follows

| Name              | Type / Range        | Description                                        |
| ----              | ------------        | -----------                                        |
| `DataWidth`       | `int` (32, 64, 128) | ISA bit-width                                      |
| `NumHier`         | `int` (>=1)         | Number of interconnect hierarchy levels            |
| `NumRsp[NumHier]` | `int[NumHier]`      | Number of responding entities per hierarchy level. |
| `DualWriteback`   | `bit`               | Support for dual-writeback instructions            |
| `TernaryOps`      | `bit`               | Support for ternary operations (use `rs3`)         |

### Derived Parameters
| Name    | Value                   | Description                                 |
| ----    | -----                   | -----------                                 |
| `NumRs` | `TernaryOps ? 3 : 2`    | Supported number of source registers        |
| `NumWb` | `DualWriteback ? 2 : 1` | Supported number of simultaneous writebacks |

The `acc_adapter` module variation additionally requires the accordingly generated request/response struct types:
| Name             | Description                    |
| ----             | -----------                    |
| `acc_c_req_t`    | C-interface request struct     |
| `acc_c_rsp_t`    | C-interface response struct    |
| `acc_cmem_req_t` | CMem-interface request struct  |
| `acc_cmem_rsp_t` | CMem-interface response struct |
| `acc_x_req_t`    | X-interface request struct     |
| `acc_x_rsp_t`    | X-interface response struct    |
| `acc_xmem_req_t` | XMem-interface request struct  |
| `acc_xmem_rsp_t` | XMem-interface response struct |

  The typedefs are automatically declared using the typedef macros defined [here](../include/acc_interface/typedef.svh) as demonstrated in the following snippet.

```sv
  typedef logic [AddrWidth-1:0] addr_t; // AddrWidth parameter as defined in doc/c-interface.md.
  typedef logic [DataWidth-1:0] data_t;

  `ACC_X_TYPEDEF_ALL(acc_x, data_t, NumRs, NumWb)
  `ACC_C_TYPEDEF_ALL(acc_c, addr_t, data_t, NumRs, NumWb)
```

## Port Map
The accelerator adapter module featuresthe following ports:
| Interface Name (`acc_adapter_intf`) | Port Name (`acc_adapter`) | Type (`acc_adapter`)     | Description                                                        |
| ---------                           | ---------                 | ----                     | -----------                                                        |
| `hart_id_i`                         | `hart_id_i`               | `logic [DataWdth-1:0]`   | RISC-V hardware thread ID (hart id)                                |
| `acc_x_slv`                         | `acc_x_slv_req_i`         | `acc_x_req_t`            | X-interface request channel input from offloading CPU              |
|                                     | `acc_x_slv_rsp_o`         | `acc_x_rsp_t`            | X-interface response channel output to offloading CPU              |
| `acc_xmem_mst`                      | `acc_xmem_mst_req_o`      | `acc_xmem_req_t`         | XMem-interface request channel output to offloading CPU            |
|                                     | `acc_xmem_mst_rsp_i`      | `acc_xmem_rsp_t`         | XMem-interface response channel input from offloading CPU          |
| `acc_c_mst`                         | `acc_c_mst_req_o`         | `acc_c_req_t`            | C-interface request channel output to accelerator interconnect     |
|                                     | `acc_c_mst_rsp_i`         | `acc_c_rsp_t`            | C-interface response channel input from accelerator interconnect   |
| `acc_cmem_slv`                      | `acc_cmem_mst_req_i`      | `acc_cmem_req_t`         | CMem-interface request channel input from accelerator interconnect |
|                                     | `acc_cmem_mst_rsp_o`      | `acc_cmem_rsp_t`         | CMem-interface response channel output to accelerator interconnect |
| `acc_prd[NumRspTot]`                | `acc_prd_req_o`           | `acc_pkg::acc_prd_req_t` | Predecoder request channel output (combinational)                  |
|                                     | `acc_prd_rsp_i`           | `acc_pkg::acc_prd_rsp_t` | Predecoder response channel input (combinational)                  |

