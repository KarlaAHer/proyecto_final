# Calibración de servos (mini proyecto)

Proyecto aparte para encontrar los 4 anchos de pulso de `servo_controller.v`
moviendo los servos en vivo con los botones, sin tocar el proyecto completo.

## Archivos para el proyecto de Quartus
Top-level: **`servo_cal_top`**

- `servo_cal_top.v`
- `servo_pwm_runtime.v` (como tu `servo_controller`, pero con anchos ajustables)
- `key_repeat.v`
- `seg7_cal.v`
- `bin12_to_bcd.v`
- `../button_conditioner.v` (tu módulo, se reutiliza)

`servo_cal_top_tb.v` es solo para simular, no lo agregues a Quartus.

**Pines:** los nombres son los de las tarjetas Terasic (`CLOCK_50`, `KEY`, `SW`, `HEX0-5`, `LEDR`).
Asigna `SERVO[0..5]` a **los mismos pines GPIO que usas en el proyecto final**, para no tener que recablear.

## Controles

| Control | Función |
|---|---|
| `SW9` | Reset (1 = vuelve a los valores actuales: 1400 / 1661 / 1600 / 1339 µs) |
| `SW1 SW0` | Parámetro: `00` DOWN_L, `01` UP_L, `10` DOWN_R, `11` UP_R |
| `SW8` | `1` = PREVIEW (los 6 servos van a la posición que editas) · `0` = PRUEBA |
| `SW7..SW2` | En modo PRUEBA: patrón braille (SW2 = punto 1 … SW7 = punto 6) |
| `KEY0` | +5 µs (mantener = repite 10 veces por segundo) |
| `KEY1` | −5 µs |

Displays: `HEX5 HEX4` = parámetro (`L d`, `L U`, `r d`, `r U`), `HEX3..HEX0` = ancho en **µs**.
`LEDR5..0` = patrón que reciben los servos, `LEDR9` = llegaste al límite (1000 o 2000 µs).

5 µs ≈ 1 grado en un SG90.

## Procedimiento
1. `SW9 = 1` y después `0` (reset). `SW8 = 1` (PREVIEW).
2. `SW1 SW0 = 00` → todos los servos van a "abajo". Ajusta **DOWN_L** hasta que los puntos 1, 2, 3 queden justo al ras.
3. `SW1 SW0 = 10` → ajusta **DOWN_R** para los puntos 4, 5, 6.
4. `SW1 SW0 = 01` → todos los servos "arriba". Ajusta **UP_L** hasta la altura que quieres.
5. `SW1 SW0 = 11` → ajusta **UP_R**.
6. `SW8 = 0` y prueba patrones con `SW7..SW2` para verificar.
7. Anota los 4 números. **No muevas `SW9`** o se pierden.

## Pasar los valores al programa original
Multiplica por 50 (a 50 MHz, 1 µs = 50 cuentas):

```verilog
parameter PULSE_DOWN_L = <DOWN_L> * 50,   // ej. 1400 us -> 70000
parameter PULSE_UP_L   = <UP_L>   * 50,
parameter PULSE_DOWN_R = <DOWN_R> * 50,
parameter PULSE_UP_R   = <UP_R>   * 50,
```

## Simular
```bash
iverilog -g2005 -o sim.vvp servo_cal_top_tb.v servo_cal_top.v servo_pwm_runtime.v key_repeat.v seg7_cal.v bin12_to_bcd.v ../button_conditioner.v && vvp sim.vvp
```
