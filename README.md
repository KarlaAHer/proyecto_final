# Sistema bidireccional Texto ↔ Braille (DE10-Lite)

The FPGA is the local controller. It talks to the PC/MATLAB over **UART at 9600 baud, 8N1** (FT232RL now, HC-05 later with no RTL change), drives a **6-servo Braille cell** and reads a **6-button Braille keypad + NEXT**.

## Repository layout

| Path | Contents |
|---|---|
| `rtl/` | Synthesizable Verilog (top: `braille_top`) |
| `tb/` | Testbenches (`braille_top_tb.v` = full system, 3 modes) |
| `matlab/braille_gui.m` | MATLAB display: passive window that shows/speaks what the FPGA reports; it only sends the word in reading mode |
| `quartus/` | DE10-Lite pin assignments (`pins_de10lite.tcl`) and `.sdc` |
| `legacy/` | Previous packet-based modules (0xAA + checksum), kept for reference only |

## Modules

| Module | Responsibility |
|---|---|
| `uart_rx` / `uart_tx` | UART 9600 8N1, mid-bit sampling, 2-FF RX synchronizer |
| `line_rx` | Assembles `\n`/`\r`-terminated command lines, writes the payload into the buffer, flags overflow |
| `char_buffer` | `MAX_LEN` × 8-bit word storage (default 16) |
| `msg_tx` | Sends short reply lines (1–6 bytes + `\n`) |
| `button_conditioner` | Synchronizer + 10 ms debounce for the 7 buttons |
| `chord_capture` | OR-latches the dots while any key is held; commits the 6-bit pattern when all keys are released |
| `ascii_to_braille` / `braille_to_ascii` | Lookup tables (a–z, ñ, space) |
| `servo_controller` | 50 Hz PWM, **one shared counter** for all 6 channels; the pattern updates only at the start of a period |
| `braille_controller` | Mode FSM (reading / writing / practice) and hit/miss counters |
| `hex7seg` | 7-segment decoder for the score display |

**Bit convention:** `pattern[i]` = Braille dot *i+1* = button `DOT_N[i]` = `SERVO[i]`.

```
dot1 o o dot4      bit0 bit3
dot2 o o dot5      bit1 bit4
dot3 o o dot6      bit2 bit5
```

## Operating modes (selected ONLY with the board switches)

| SW1 SW0 | Mode | What the FPGA does |
|---|---|---|
| 00 | Idle | Cell neutral, keypad ignored |
| 01 | **Reading** | PC sends `R<word>`; the cell shows the first letter; KEY1 (NEXT) advances; `E` at the end |
| 10 | **Writing** | Chord on the 6 buttons → decoded on the FPGA → `K<c>`; NEXT = space |
| 11 | **Practice** | The FPGA clears the score, picks a random letter (LFSR) and sends `T<c>`, compares the chord, counts hits/misses, shows the correct pattern for 2 s and picks the next letter by itself. NEXT skips. **SW2 = 1** shows the target on the servos as a hint |

The PC never changes the mode; it only displays, speaks and sends the reading text.

## Protocol (every line ends in `\n`)

| PC → FPGA | Meaning | Reply |
|---|---|---|
| `R<text>` | Load a word (1–16 chars), only in reading mode | `D<c>` (`!L` too long, `!M` not in reading mode) |
| `Q` | Query the current mode | `M<m>` |
| `S` / `C` | Read / clear the score | `S<hh><mm>` |
| `N` | Software NEXT (testing) | depends on the mode |

| FPGA → PC | Meaning |
|---|---|
| `M<m>` | Mode from the switches (`I`, `R`, `W`, `P`) |
| `D<c>` / `E` | Reading: showing `c` / end of word |
| `K<c>` | Writing: typed character (`?` = invalid pattern, space = NEXT) |
| `T<c>` | Practice: new random target letter |
| `O<c><hh><mm>` / `X<c><hh><mm>` | Practice: hit / miss + counters (hex) |
| `!L` `!U` `!M` | Too long / unsupported command / not in reading mode |

## Hardware notes

* Default GPIO header wiring: see `quartus/pins_de10lite.tcl` (verify against the DE10-Lite manual).
* The buttons connect to GND and use the FPGA's internal pull-ups.
* Power the servos from an **external 5 V supply** with a common GND. The 3.3 V PWM signal drives SG90 servos without problems.
* Servo pulse widths are parameters of `braille_top`: left column (dots 1–3) `PULSE_DOWN_L`/`PULSE_UP_L` = 1.400/1.661 ms; right column (dots 4–6) is mirrored, `PULSE_DOWN_R`/`PULSE_UP_R` = 1.600/1.339 ms (150000 − left value). 278 counts ≈ 1°.
* **HC-05:** configure it for 9600 baud (AT+UART=9600,0,0), and use 3.3 V logic or a divider on its RX pin. In MATLAB, only `PORT` changes.

## Simulation

```bash
iverilog -g2005 -o sim tb/braille_top_tb.v rtl/*.v && vvp sim
```

The testbench drives the UART, presses chords with staggered timing and bounce, measures the servo pulse widths and checks every reply. It covers all 3 modes, the hardware switch and the error cases.
