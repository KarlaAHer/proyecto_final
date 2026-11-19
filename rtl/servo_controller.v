//====================================================
// CONTROLADOR DE 6 SERVOS (PWM 50 Hz)
//
// Un solo contador de periodo compartido por los 6 canales.
// Cada canal compara el contador contra PULSE_UP (punto
// levantado) o PULSE_DOWN (punto abajo).
//
// El patron se registra solo al inicio de cada periodo para
// que ningun pulso salga recortado a la mitad.
//
// Valores a 50 MHz:
//   PERIOD     = 1 000 000  -> 20 ms
//   PULSE_DOWN =    70 000  -> 1.40 ms
//   PULSE_UP   =    82 500  -> 1.65 ms
// Ajustar PULSE_DOWN / PULSE_UP segun el mecanismo de la celda
// (rango tipico de un SG90: 50 000 a 100 000 = 1 ms a 2 ms).
//====================================================

module servo_controller #(
    parameter PERIOD        = 1000000,
    parameter PULSE_DOWN    = 70000,
    parameter PULSE_UP      = 82500,
    parameter COUNTER_WIDTH = 20
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [5:0] braille_pattern,   // bit[i] = punto i+1 (1 = arriba)
    output wire [5:0] servo_pwm
);

    reg [COUNTER_WIDTH-1:0] pwm_count;
    reg [5:0]               pattern_active;

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            pwm_count      <= 0;
            pattern_active <= 6'b000000;
        end

        else if (pwm_count == PERIOD - 1) begin
            pwm_count      <= 0;
            pattern_active <= braille_pattern;
        end

        else begin
            pwm_count <= pwm_count + 1'b1;
        end

    end

    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin : SERVO_CHANNELS
            assign servo_pwm[i] =
                (pwm_count < (pattern_active[i] ? PULSE_UP : PULSE_DOWN));
        end
    endgenerate

endmodule
