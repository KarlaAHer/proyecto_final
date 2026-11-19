create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_clock_uncertainty
# Entradas asincronas (botones, switches, UART) se sincronizan en RTL
set_false_path -from [get_ports {KEY[*] SW[*] DOT_N[*] UART_RX}]
set_false_path -to   [get_ports {LEDR[*] HEX*[*] SERVO[*] UART_TX}]
