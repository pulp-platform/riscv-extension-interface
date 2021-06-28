# Operating Principle
The RISC-V extension interface provides a portable, mostly plug-and-play infrastructure for implementing RISC-V ISA extensions.
This section describes operating principles of the REI.

## Offloading Process
A processor core implementing the REI does not need to be aware of any of its connected extensions.
Upon encountering an instruction in the instruction decoder which it is not able to decode, the offloading process is initiated.

### Core-Adapter Offloading Handshake
Offloaded instructions can not be retracted by the offloading core once they have been accepted by the accelerator adapter.
It is therefore essential, that any instructions present in the offloading core's pipeline are guaranteed to not raise any exceptions that might require invalidation of the results produced by the offloaded instruction.
In particular, an instruction may not be offloaded if there is a memory operation pending in either the core's pipeline or any of the connected accelerator units.
The memory operation status of connected accelerators is tracked by the accelerator adapter and provided to the core via the asynchronous status signal `adapter_mem_pending`.

Once there are no such conflicts possible, the offloading core initiates the offload request transaction by asserting its `x.q_valid` line on the [X instruction offloading interface](x-interface.md).

It exposes the RISC-V instruction data to the accelerator adapter using the `x.q_instr_data` signal.
The source register addresses for `rs1` through `rs3` are encoded invariantly by bits `instr_data[19:15]`, `instr_data[24:20]` and `instr_data[31:27]`.
The source register contents are exposed to the accelerator adapter through the `x.q_rs[2:0]` signal array.
The `x.q_rs_valid[2:0]` signal indicates validity of the source register contents.
The instruction data bit range `instr_data[11:7]` encode the destination register address of the instruction.
The offloading core indicates outstanding write-backs to the encoded destination register via the signal `x.q_rd_clean`.
This is necessary in order to avoid eventual write-after-write hazards.

The accelerator adapter is connected with an accelerator predecoder for each of the connected accelerators.
The predecoders do only minimal instruction decoding.
The predecoders decode the offload request's instruction data and determine if the corresponding accelerator unit can execute the instruction in question.
If so, the predecoders signal to the adapter which source registers are defined for the offloaded instruction, and weather write-back to the integer register file is expected.
Also, offloaded memory operations are identified here.

The accelerator adapter indicates acceptance of the offload request via the `x.k_accept` line.
If write-back to the integer register file is expected, the core is informed via the `x.k_writeback` line.
Once all the necessary integer source registers are marked valid, and the destination register is marked clean, the accelerator adapter asserts `x.q_ready` to complete the offload request.

### Tracking Dependencies
The offloading core is responsible for tracking possible dependencies of the instruction sequence following the offloaded instruction upon the outcome of the latter.
Accelerated instructions may not write back to the integer register file, if they impact only the architectural state of the accelerator unit.
If no write-back is expected to the integer register file, no dependencies arise in the core's pipeline.
In this case the instructions can be treated as fire-and-forget operations from a core's perspective.

### Accelerator Units
Once an offload request transaction is completed between the offloading processor core and the accelerator adapter, the offloaded instruction data along with the necessary source data are sent to the accelerator units via the accelerator interconnect [C-interface](c-interface.md).
The accelerator units implement an independent subsystem, supporting detailed decoding of the instruction data and communication with the respective functional units.
The exact nature of the offloaded instruction is only known at this point.
The instruction is decoded and executed in the accelerator subsystem.
If the instruction writes back to the integer register file, an offload response is issued by the accelerator subsystem and sent towards the corresponding accelerator adapter via the C-interface.
Regular integer register writeback responses are marked by setting the `c.p_type` signal to `1'b0`.
If the instruction only impacts the accelerator's internal architectural state, no response is issued.

### Offload Instruction Response
The offloaded instruction returns a response for
- Regular integer register file writebacks (Response Type `1'b0`).
  The offload response carries writeback data along with the target destination register.
- External mode synchronous memory operations (Response Type `1'b1`) See [Synchronous Memory Operations](#synchronous-memory-operations) for details.

### Memory operations
The REI defines two distinct modes of memory access for external accelerator units.

- *Internal mode*: Memory operations are performed through the offloading core's load/store unit
- *External mode*: Memory operations are performed through separately implemented accelerator-private memory ports.

Furthermore, offloaded memory operations are classified with the following attributes.
- *Synchronous* memory operations are performed in lockstep with the rest of the instruction stream.
  Access faults resulting from synchronous memory operations are trapped precisely by the offloading core.
  Neither the offloading core nor any of the connected accelerators may commit any new instruction results while synchronous memory operations are being served.
- *Speculative* memory operations do not automatically trigger exceptions in the offloading core upon encountering access faults.
  The success or failure of a speculative memory operation is reported by the accelerator upon completion of the instruction.
- *Asynchronous* memory operations execute in parallel to the main instruction stream.
  Memory access permissions are probed via the defined memory interfaces before starting the memory operation.
  Once the necessary permissions are acquired by the accelerator, core pipeline is released to continue operation.
  Accelerators implementing asynchronous memory operation must implement separate memory ports.
  Access faults encountered by asynchronous memory operations may not be trapped precisely and are therefore not strictly compliant to the RISC-V ISA specification.


#### Memory Interface
The REI defines separate memory channels for communication related to offloaded memory operations.
The channels are routed along with the regular instruction offloading interface.
The *XMem-interface* is defined as an analogue of the X- instruction offloading interface for communication between the offloading core and the accelerator adapter.
The *Cmem-interface* connects the adapter to the accelerator units.
The Xmem/Cmem-requests are generated by the accelerator units a memory operation has been offloaded to.
Xmem/Cmem-Responses are generated by the offloading core.
They may carry explicit memory access results in case of internal mode memory operations, or metadata concerning the targeted memory region by an external mode memory operation.


#### End of Transaction Signalling

To enable the different flavors of memory operations, the memory operation pending status signal may be lifted in two ways:
- A Cmem-request packet is sent by the accelerator unit with the specially defined `q_endoftransaction` bit asserted.
  This mechanism can be used for
  - *Non-speculative synchronous internal mode* memory transactions:
    The number of required memory operations to serve an offloaded instruction is known to the issuing accelerator unit before the fact.
    As soon as the last operation associated with the offloaded instruction has been served, the offloading core may continue normal operation without requiring an additional response by the accelerator unit.
  - *Asynchronous external mode* memory transactions: The accelerator unit must probe the memory region in question for permission before independently issuing its memory operations.
    By setting the `q_endoftransaction` signal associated with this probing request, the core pipeline is released to continue operation in parallel with the accelerator unit issuing its asynchronous requests.
- An explicit memory response packet (marked by `c.p_type`) is sent from the accelerator unit to the offloading core.
  In addition to ending the transaction, the C-response packet carries any relevant information on the success or failure status of the associated instruction.
  This mechanisms can be used for
  - *Speculative synchronous internal mode* memory transactions:
    If the number of memory operations required to complete an instructions is not known beforehand (e.g. it depends on the memory contents), the accelerator unit may issue speculative memory transactions.
    As the last memory operation is not known at request time, Cmem-request may not be marked to end the sequence.
    Instead the accelerator unit may explicitly end the memory operations.
  - *Synchronous external mode* memory transactions:
    The accelerator unit performs memory operations independently of the offloading core.
    The core is explicitly informed of the end of such a memory operation and its success/failure status.

The following subsections describe the transaction process for internal and external mode memory operations in some more detail.

#### Internal Mode
The standard mode for accessing memories for extension accelerators is through the offloading core's load/store unit.
This brings several advantages as compared to accelerator-private memory interfaces:
- Memory accesses are routed through the processor's data cache, thus reducing cache coherency hardware and performance overheads.
- Sharing the offloading core's memory infrastructure, simplifies coherent address translation, permission checks and precise exception handling.
- Through the detailed specification of instruction offloading *and* memory interfaces, the RISC-V extension interface becomes truly plug-and-play for accelerators implementing this memory operation mode.

An internal-mode memory transaction is triggered by an offload request implying a load or store memory access being accepted by the accelerator adapter.
The memory operation is identified by the accelerator predecoders, the offloading core is informed of the pending memory request through the X-interface signal `x.k_is_mem_op`.

> At this point and until the status signal is reset, the core is not allowed to commit any subsequent instructions.
> Speculative execution may continue internally, if the core implements roll-back in case of an access fault occuring.
> Further instruction offload requests may not be issued to the accelerator adapter while there is an offloaded memory operation pending, since there is no means to retract any offloaded instructions in case the result must be invalidated.
> The offloaded instruction's program counter must be stored by the offloading core for possible exception handling upon access faults.

The offload request is forwarded to the accelerator subsystem via the C-interface.
The accelerator subsystem decodes the instructions and determines memory address and nature of the operation (read/write).

The accelerator unit set the appropriate signals on the C-Mem request channel and asserts `q_valid` to initiate a transaction:
- `cmem.q_laddr` designates the target logical memory address.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_wdata` carries memory write data if this is a store transaction and `'0` otherwise.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_width` specifies the width of the memory access.
  The width of a memory transaction is limited by the processor's internal bit width.
  If wider ranges of data are needed to serve a memory instruction, multiple requests must be issued in sequence.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_req_type` specifies the request type (execute, write or read).
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_mode` is set to `1'b0` for standard memory operations.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_spec` marks speculative memory operations.
  If asserted, the offloading core will not raise an exception upon encountering an access fault.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_endoftransaction` designates the last in a series of memory request pertaining to the same offloaded memory instruction.
  This signal is used only for book-keeping by the accelerator adapter and is *not* forwarded to the offloading core accross the X-Mem interface.
- `cmem.q_hart_id` the processor core's hart ID is used for routing the C-Mem request accross the accelerator interconnect.
  This signal is *not* forwarded to the offloading core accross the X-Mem interface.

The accelerator adapter forwards the C-Mem request to the offloading core via the X-Mem interface.
The offloading core is aware of an outstanding memory request by the accelerator adapter due to the `adapter_mem_pending` status signal and provides control over the the internal load/store unit to the adapter.
The X-Mem request channel payload signals comprise the signals `q_laddr`, `q_wdata`, `q_width`, `q_req_type`, `q_mode` and `q_spec`.

The X-Mem request payload data is transfered to the offloading core's LSU and acknowledged by the core via the `xmem.q_ready` signal in the same cycle as the memory response transaction is initiated:
- The offloading core asserts `xmem.q_ready` to complete the memory request transaction and simultaneously initiates a memory response transaction by asserting `xmem.p_valid`.
- `xmem.p_rdata` carries the loaded memory contents if the access was a load operation.
  For store operations the signal is assigned `'0`.
- `xmem.p_range` is unused for standard mode memory operations. it is assigned `'0`.
- `xmem.p_status` indicates success (`p_status = 1'b1`) or failure (`p_status = 1'b0`) of the memory operation.
The response transaction is acknowledged by the accelerator adapter by asserting the `xmem.p_ready` signal and sent across the accelerator interconnect to the accelerator unit via the C-Mem response channel.


> Any memory operations issued by the accelerator units traverse all implemented PMP and PMA checks as well address translation in the offloading core as would be the case for core-internal memory operations.
> Unless a memory operation is marked as speculative operation, the core must raise a precise exception due any failed checks or memory system errors.
> The issueing accelerator unit is informed of a possible access fault via the `xmem.p_status` line.

#### External Mode
Accelerators may implement a dedicated memory interface within the accelerator subsystem.
To facilitate permission checking and address translation, the REI defines a memory probing mode on the memory interface channel.
Implementing an accelerator-private memory interface may be necessary, if
- The available bandwidth on the offloading core's memory interface is not enough to efficiently support the offloaded operations.
- Memory operations are generated dynamically by the accelerator itself.

External mode memory requests traverse the core's memory infrastructure (PMP/PMA checks and address translation) but do not generate memory requests by the core's load/store unit.
The response channel in this case carries memory system metadata, granting read/write/execute permissions for a region of memory to the accelerator unit and potentially translating logical to physical memory addresses, if implemented.
The accelerator unit implements a private memory memory port working in parallel to the offloading core's LSU.
Any memory consistency infrastructure in this case is platform specific.

Similarly to internal mode memory operations, external mode memory operations block the commitment of new instructions in the core pipeline by asserting the `adapter_mem_pending` signal in the accelerator.
The accelerator unit sets the C-Mem request channel signals as follows:

- `cmem.q_laddr` designates the target logical memory address.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_wdata` is unused for external mode memory requests and is assigned `'0`.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_width` unused for external mode memory requests and is assigned `'0`.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_req_type` specifies the request type (execute, write or read).
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_mode` is set to `1'b1` for probing the memory  memory operations.
  This signal is forwarded to the offloading core via the X-Mem interface.
- `cmem.q_endoftransaction` signals to the accelerator adapter to lift the `adapter_mem_pending` status signal and releases the blocking of the core's pipeline.
  This signal is used only for book-keeping by the accelerator adapter and is *not* forwarded to the offloading core accross the X-Mem interface.
- `cmem.q_hart_id` the processor core's hart ID is used for routing the C-Mem request accross the accelerator interconnect.
  This signal is used only for request signal routing from the accelerator unit to the adapter and is *not* forwarded to the offloading core accross the X-Mem interface.

The X-Mem request payload data is transferred to the offloading core's PMP/PMA/MMU infrastructure and acknowledged by the core via the `xmem.q_ready` signal in the same cycle as the memory response transaction is initiated:
The response channel carries the following information:
- `xmem.p_rdata` carries the corresponding physical memory address.
- `xmem.p_range` specifies the number of LSB bits that can be changed in the logical address without changing the metadata.
- `xmem.p_status` indicates if the requested access to the specified memory region is granted.
The response transaction is acknowledged by the accelerator adapter by asserting the `xmem.p_ready` signal and sent across the accelerator interconnect to the accelerator unit via the C-Mem response channel.

External mode memory requests resulting in an access *not granted response* trigger a precise trap of the offending instruction in the core's pipeline.

##### Asynchronous Memory Operations
The accelerator unit may assert `cmem.q_endoftransaction` to signal the memory access will be handled asynchronously by the accelerator unit.
The `adapter_mem_pending` signal is lifted and the core may continue operation normally.
Any potential conflicts resulting from the external memory access must be architecturally impossible, or excluded by other means defined by the ISA extension in question.
These memory operations may not be trapped precisely.
The success or failure status of asynchronous memory transactions must be read out by specially defined instructions of the implemented ISA extension.

##### Synchronous Memory Operations
If the `cmem.q_endoftransaction` signal is not asserted, the blocking `adapter_mem_pending` remains in place after the external mode memory transaction has completed.
The issuing accelerator unit remains in control of the requested memory region.
Once the external memory operations are completed, the accelerator unit sends a regular offload response accross the C-interface.
This response is marked by asserting the `c.p_mem_op` signal as a memory transaction response.
The memory operation instruction response is encoded as follows:
- `p_error` encodes the transaction status (success / fail)
- `p_data[0]` carries the offending memory address if the transaction failed and `'0` otherwise.
If an external synchronous memory operation has not been successful, the offloading core must trap using the corresponding instruction PC and the offending address transmitted via the C-interface.

## Fence Instructions
Fence instructions are handled entirely without direct participation of the accelerator adapter.
Upon encountering a fence instruction, the offloading core must wait until any outstanding integer writeback instructions have returned their responses and until the `adapter_mem_pending` signal is deasserted.
Synchronization with external asynchronous memory operations must be handled explicitly.

## Interrupts
Upon an interrupt being raised in the offloading core, it must wait until any outstanding integer writeback instructions have returned their responses and until the `adapter_mem_pending` signal is deasserted.

## Exceptions
Before any instruction is offloaded, the core must ensure that no preceding instructions in the pipeline may raise any exceptions.
As any dispatched offloaded instructions may not be retracted, there is no way to roll back a possible architectural state local to an accelerator.
Before handling an exception, the offloading core must wait until any outstanding integer writeback instructions have returned their responses and until the `adapter_mem_pending` signal is deasserted.

## Privilege modes
Before changing privilege modes for whatever reason, the offloading core must wait until any outstanding integer writeback instructions have returned their responses and until the `adapter_mem_pending` signal is deasserted.
