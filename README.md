# uart-sv-fpga

A configurable UART (RX/TX) with 16x oversampling and FWFT FIFOs, written in SystemVerilog. Verified in simulation (ModelSim) and on hardware: a **Terasic DE2-115** board (Intel **Cyclone IV E, EP4CE115F29C7**) running a loopback echo at **9600 baud, 8N1**, tested from a PC terminal (Tera Term).

![Tera Term echo test](docs/tera_term_echo.png)

> Demo video: `<add link here>`

## Features

- Full-duplex UART transmitter and receiver, built as FSMs (`idle → start → data → stop`).
- 16x oversampling: the receiver finds the middle of the start bit and samples each data bit at mid-bit.
- **Runtime-configurable baud rate** through an 11-bit divisor input (`dvsr`).
- Separate RX and TX **FIFOs with first-word fall-through (FWFT)** reads, split into control (`fifo_ctrl`) and storage (`reg_file`).
- Parameterized data width, stop-bit ticks and FIFO depth.
- FPGA top-level (`uart_echo_top`) with a 2-flip-flop synchronizer on the asynchronous RX input.

## Architecture

```
                    ┌──────────────────────── uart ────────────────────────┐
                    │                                                       │
 clk, rst_n ───────►│  baud_gen ──tick──┬────────────┐                      │
 dvsr[10:0] ───────►│                   ▼            ▼                      │
                    │              ┌─────────┐  ┌─────────┐                 │
 rx ───────────────►│─────────────►│ uart_rx │  │ uart_tx │────────────────►│ tx
                    │              └────┬────┘  └────▲────┘                 │
                    │        rx_done_tick│            │ tx_start (~empty)   │
                    │                    ▼            │                     │
                    │              ┌──────────┐  ┌──────────┐              │
 rd_uart ──────────►│─────────────►│ FIFO RX  │  │ FIFO TX  │◄─────────────│◄── wr_uart
 r_data  ◄──────────│◄─────────────│  (FWFT)  │  │  (FWFT)  │              │◄── w_data
 rx_empty ◄─────────│              └──────────┘  └──────────┘              │
 tx_full  ◄─────────│                                                       │
                    └───────────────────────────────────────────────────────┘
```

Each FIFO is `fifo` = `fifo_ctrl` (read/write pointers, `full`/`empty` flags) + `reg_file` (storage array with combinational read, which gives the FWFT behavior: `r_data` already shows the oldest word while `empty` is low, and `rd` just pops it).

## Repository layout

```
rtl/
  uart.sv             UART top: baud generator + RX + TX + two FIFOs
  uart_rx.sv          Receiver FSM
  uart_tx.sv          Transmitter FSM
  baud_generator.sv   Programmable tick generator (16x baud rate)
  fifo.sv             FIFO top (wraps fifo_ctrl + reg_file)
  fifo_ctrl.sv        FIFO pointers and full/empty flags
  reg_file.sv         FIFO storage array
fpga/
  uart_echo_top.sv    DE2-115 top-level: echoes every received byte
tb/
  uart_tb.sv          Testbench (9600 baud, 8N1)
docs/
  tera_term_echo.png  Hardware validation
```

## Parameters and ports

### `uart` parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DBIT`    | 8       | Data bits per frame (see [Limitations](#limitations)) |
| `SB_TICK` | 16      | Stop-bit length in 16x ticks (16 = 1 stop bit) |
| `FIFO_W`  | 4       | FIFO depth in words (use a power of two; the FPGA top uses 16) |

### `uart` ports

| Port | Dir | Description |
|------|-----|-------------|
| `clk`, `rst_n` | in | System clock and asynchronous active-low reset |
| `dvsr[10:0]` | in | Baud divisor |
| `rx` | in | Serial input |
| `tx` | out | Serial output |
| `wr_uart`, `w_data` | in | Push a byte into the TX FIFO |
| `rd_uart` | in | Pop a byte from the RX FIFO |
| `r_data` | out | Oldest received byte (FWFT, valid when `rx_empty` = 0) |
| `rx_empty` | out | RX FIFO empty |
| `tx_full` | out | TX FIFO full |

### Baud rate

```
dvsr = f_clk / (16 × baud) − 1
```

For the DE2-115 50 MHz clock at 9600 baud: `dvsr = 50 000 000 / (16 × 9600) − 1 = 324`. The `uart_echo_top` module computes this from its `CLK_FREQ` and `BAUD` parameters.

## Simulation (ModelSim)

From the repository root:

```bash
vlib work
vlog -sv rtl/*.sv tb/uart_tb.sv
vsim -c uart_tb -do "run -all; quit"
```

The testbench transmits and receives at 9600 baud, 8N1. Remove `-c` to open the GUI and inspect the waveforms.

## FPGA build and test (DE2-115)

1. Create a Quartus Prime project for the device **EP4CE115F29C7** with `uart_echo_top` as the top-level entity and add all files from `rtl/` and `fpga/`.
2. Assign pins for `CLOCK_50`, `KEY0` (reset, active low), `UART_RXD` and `UART_TXD` according to the DE2-115 user manual.
3. Compile and program the board with the Quartus Programmer.
4. Connect the board's DB9 RS-232 port to the PC with a USB-to-RS232 adapter (a Prolific PL2303 cable was used here).
5. Open a terminal (Tera Term) on the adapter's COM port at **9600 baud, 8 data bits, no parity, 1 stop bit, no flow control**.
6. Type characters: each one is echoed back through the RX FIFO → TX FIFO → TX path.

`uart_echo_top` pops a byte from the RX FIFO and pushes it into the TX FIFO in the same cycle, only when the RX FIFO is not empty and the TX FIFO is not full, so no bytes are lost.

## Verification status

| Item | Status |
|------|--------|
| Simulation, 8N1 at 9600 baud | Done (ModelSim) |
| Hardware loopback echo, 8N1 at 9600 baud | Done (DE2-115 + Tera Term) |
| Other baud rates, data widths, stop-bit settings | Parameterized, not verified |
| Self-checking testbench, assertions, coverage | Not implemented yet |

## Limitations

- Only **8N1 at 9600 baud** has been verified.
- The receiver's shift uses a fixed `b_reg[7:1]` slice and a 3-bit bit counter, so `DBIT` works for 8 bits only. A fix is to size the counter with `$clog2(DBIT)` and shift with `{rx, b_reg[DBIT-1:1]}`.
- The tick counter inside each frame is 4 bits wide, so `SB_TICK` above 16 does not fit.
- No parity bit, framing-error or overrun flags. If the RX FIFO is full, incoming bytes are dropped silently.

## Possible next steps

- Self-checking testbench (compare transmitted vs. received bytes) with SystemVerilog assertions.
- Parity and error flags (framing, overrun).
- Fix the `DBIT` and `SB_TICK` limitations above and verify more baud rates.

## Tools

SystemVerilog · ModelSim · Quartus Prime · Terasic DE2-115 (Cyclone IV E EP4CE115F29C7) · Tera Term · VS Code

## License

MIT License. See [LICENSE](LICENSE).

## Author

Adrian Valle · Embedded Computer Systems Engineering, Universidad Politécnica de Yucatán · [LinkedIn](https://www.linkedin.com/in/adrianvalle-388920389)
