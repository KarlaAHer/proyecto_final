# Sistema bidireccional Texto ↔ Braille (DE10-Lite)

The FPGA is the local controller. It talks to the PC/MATLAB over **UART at 9600 baud, 8N1** (FT232RL now, HC-05 later with no RTL change), drives a **6-servo Braille cell** and reads a **6-button Braille keypad + NEXT**.

## Repository layout

| Path | Contents |
|---|---|
| `rtl/` | Synthesizable Verilog (top: `braille_top`) |
| `tb/` | Testbenches (`braille_top_tb.v` = full system, 3 modes) |
| `matlab/braille_app.m` | MATLAB interface: menu, 3 modes, score plot, text-to-speech |
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

## Operating modes

Select a mode with a PC command or with `SW[1:0]` (`01` reading, `10` writing, `11` practice, `00` PC only). Whichever was used last wins.

* **A. Reading.** `RCASA\n` → the cell shows `C`. Each NEXT advances to `A`, `S`, `A`. NEXT after the last letter → `E`, and the cell returns to neutral.
* **B. Writing.** Press a chord (e.g. dots 1+4). On release, the FPGA sends `Kc`. NEXT sends a space (`K `).
* **C. Practice.** `Pc` sets the target `c` (cell neutral). `Hc` shows the target on the servos as a hint. The next chord is compared with the target:
  * Match → `O<typed><hits><misses>`.
  * Mismatch → `X…`.

  After the attempt, the cell shows the correct pattern as tactile feedback. NEXT sends `N` (the PC answers with a new letter).

## Protocol (every line ends in `\n`)

| PC → FPGA | Meaning | Reply |
|---|---|---|
| `R<text>` | Reading mode, load a word (1–16 chars) | `D<c>` (or `!L` if too long) |
| `R` / `W` / `P` | Change mode only | `MR` / `MW` / `MP` |
| `P<c>` / `H<c>` | Practice target without / with a hint | `T<c>` (or `!U`) |
| `N` | Software NEXT | depends on the mode |
| `S` | Read the score | `S<hh><mm>` (hex) |
| `C` | Clear the score | `S0000` |

| FPGA → PC | Meaning |
|---|---|
| `D<c>` / `E` | Reading: showing `c` / end of word |
| `K<c>` | Writing: typed character (`?` = invalid pattern, space = NEXT) |
| `O<c><hh><mm>` / `X<c><hh><mm>` | Practice: hit / miss + counters |
| `N` | Practice: the user asked for the next letter |
| `M<m>` | Mode changed from the board switch |
| `!L` `!U` `!T` | Word too long / unsupported / no practice target |

Everything is printable ASCII, so you can test from any serial terminal before using MATLAB.

## Hardware notes

* Default GPIO header wiring: see `quartus/pins_de10lite.tcl` (verify against the DE10-Lite manual).
* The buttons connect to GND and use the FPGA's internal pull-ups.
* Power the servos from an **external 5 V supply** with a common GND. The 3.3 V PWM signal drives SG90 servos without problems.
* `PULSE_DOWN` / `PULSE_UP` (1.40 / 1.65 ms) are parameters of `braille_top`. Adjust them to suit the cell's mechanism.
* **HC-05:** configure it for 9600 baud (AT+UART=9600,0,0), and use 3.3 V logic or a divider on its RX pin. In MATLAB, only `PORT` changes.

## Simulation

```bash
iverilog -g2005 -o sim tb/braille_top_tb.v rtl/*.v && vvp sim
```

The testbench drives the UART, presses chords with staggered timing and bounce, measures the servo pulse widths and checks every reply. It covers all 3 modes, the hardware switch and the error cases.
