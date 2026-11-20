# =====================================================================
# Asignacion de pines DE10-Lite para braille_top
#
# Uso en Quartus: Tools > Tcl Scripts... > Run  (con el proyecto abierto)
#   o:  quartus_sh -t quartus/pins_de10lite.tcl
#
# Pines verificados contra el DE10-Lite User Manual (Terasic, 5/jun/2020),
# tablas 3-2 a 3-7.
#
# Controles de la tarjeta:
#   KEY0 = reset, KEY1 = NEXT, SW1..SW0 = modo, SW2 = pista en practica
#
# Conexiones externas en el header GPIO 2x20 (JP1, 3.3 V):
#   GPIO_0  (pin 1)  UART_RX  <- TX del FT232RL / HC-05 (modo 3.3 V)
#   GPIO_1  (pin 2)  UART_TX  -> RX del FT232RL / HC-05
#   GPIO_2..7  (pines 3..8)          SERVO[0..5]  PWM de los puntos 1..6
#   GPIO_8..13 (pines 9,10,13..16)   DOT_N[0..5]  botones a GND
#   pin 12 / 30 = GND, pin 29 = 3.3 V, pin 11 = 5 V
# Los botones usan el pull-up interno; los servos se alimentan con
# una fuente de 5 V EXTERNA con GND comun con la FPGA.
# =====================================================================

set_global_assignment -name TOP_LEVEL_ENTITY braille_top
set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G

foreach f {
    rtl/braille_top.v rtl/braille_controller.v rtl/line_rx.v
    rtl/char_buffer.v rtl/msg_tx.v rtl/uart_rx.v rtl/uart_tx.v
    rtl/button_conditioner.v rtl/chord_capture.v
    rtl/ascii_to_braille.v rtl/braille_to_ascii.v
    rtl/servo_controller.v rtl/hex7seg.v
} {
    set_global_assignment -name VERILOG_FILE $f
}

set_global_assignment -name SDC_FILE quartus/braille_top.sdc

# --- Reloj, botones y switches de la tarjeta -------------------------
set_location_assignment PIN_P11 -to CLOCK_50
set_location_assignment PIN_B8  -to KEY[0]
set_location_assignment PIN_A7  -to KEY[1]
set_location_assignment PIN_C10 -to SW[0]
set_location_assignment PIN_C11 -to SW[1]
set_location_assignment PIN_D12 -to SW[2]

# --- LEDs ------------------------------------------------------------
set_location_assignment PIN_A8  -to LEDR[0]
set_location_assignment PIN_A9  -to LEDR[1]
set_location_assignment PIN_A10 -to LEDR[2]
set_location_assignment PIN_B10 -to LEDR[3]
set_location_assignment PIN_D13 -to LEDR[4]
set_location_assignment PIN_C13 -to LEDR[5]
set_location_assignment PIN_E14 -to LEDR[6]
set_location_assignment PIN_D14 -to LEDR[7]
set_location_assignment PIN_A11 -to LEDR[8]
set_location_assignment PIN_B11 -to LEDR[9]

# --- Displays de 7 segmentos (bit 7 = punto decimal) -----------------
set hex_pins {
    HEX0 {C14 E15 C15 C16 E16 D17 C17 D15}
    HEX1 {C18 D18 E18 B16 A17 A18 B17 A16}
    HEX2 {B20 A20 B19 A21 B21 C22 B22 A19}
    HEX3 {F21 E22 E21 C19 C20 D19 E17 D22}
    HEX4 {F18 E20 E19 J18 H19 F19 F20 F17}
    HEX5 {J20 K20 L18 N18 M20 N19 N20 L19}
}
foreach {name pins} $hex_pins {
    for {set i 0} {$i < 8} {incr i} {
        set_location_assignment PIN_[lindex $pins $i] -to ${name}[$i]
    }
}

# --- Header GPIO -----------------------------------------------------
set_location_assignment PIN_V10 -to UART_RX
set_location_assignment PIN_W10 -to UART_TX
set_location_assignment PIN_V9  -to SERVO[0]
set_location_assignment PIN_W9  -to SERVO[1]
set_location_assignment PIN_V8  -to SERVO[2]
set_location_assignment PIN_W8  -to SERVO[3]
set_location_assignment PIN_V7  -to SERVO[4]
set_location_assignment PIN_W7  -to SERVO[5]
set_location_assignment PIN_W6  -to DOT_N[0]
set_location_assignment PIN_V5  -to DOT_N[1]
set_location_assignment PIN_W5  -to DOT_N[2]
set_location_assignment PIN_AA15 -to DOT_N[3]
set_location_assignment PIN_AA14 -to DOT_N[4]
set_location_assignment PIN_W13 -to DOT_N[5]

# Pull-ups internos en las entradas externas
foreach s {UART_RX DOT_N[0] DOT_N[1] DOT_N[2] DOT_N[3] DOT_N[4] DOT_N[5]} {
    set_instance_assignment -name WEAK_PULL_UP_RESISTOR ON -to $s
}

# Todo en 3.3 V LVTTL, salvo los KEY (Schmitt trigger segun el manual)
set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to KEY[0]
set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to KEY[1]
