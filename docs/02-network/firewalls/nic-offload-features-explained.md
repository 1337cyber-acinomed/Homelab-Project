<!-- Converted from Word document: Offload Features.docx -->

**What each offload feature does**

For the Project Polaris runbook, here's a concise explanation of each.

**TSO (TCP Segmentation Offload)**

Normally, Linux breaks large TCP data into 1500-byte Ethernet frames before sending.

With TSO enabled:

- Linux hands one large packet to the NIC.

- The NIC performs the segmentation in hardware.

Benefits:

- Lower CPU utilization

- Higher throughput

If broken:

- Large TCP transfers may fail while pings still work.

**GSO (Generic Segmentation Offload)**

Similar to TSO, but implemented in the Linux networking stack rather than the NIC.

Benefits:

- Reduced CPU overhead

- More efficient packet processing

**GRO (Generic Receive Offload)**

The reverse of GSO.

Instead of Linux processing hundreds of incoming packets:

- The kernel combines them into one larger packet before handing them to the network stack.

Benefits:

- Fewer interrupts

- Better performance

**TX Checksum Offload**

Normally Linux computes every outgoing TCP/UDP/IP checksum.

With TX offload:

- The NIC computes checksums in hardware.

Benefits:

- Reduced CPU load.

**RX Checksum Offload**

The NIC verifies incoming checksums before Linux processes them.

Benefits:

- Less CPU usage

- Faster receive path

**Why we disabled them**

One of the most common problems after:

- motherboard swaps

- BIOS updates

- driver changes

- hypervisor upgrades

is that one or more offload features become incompatible with the driver or switch.

Since disabling all of them made **no difference**, we can rule that entire class of problems out.
