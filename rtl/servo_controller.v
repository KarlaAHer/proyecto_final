//====================================================
// CONTROLADOR DE 6 SERVOS (PWM 50 Hz)
//
// Un solo contador de periodo compartido por los 6 canales.
// Cada canal compara el contador contra su ancho de pulso de
// "arriba" (punto levantado) o "abajo" (punto abajo).
//
// Los servos estan montados encontrados (en espejo):
//   - Columna izquierda (puntos 1,2,3 = SERVO[0..2]) usa
//     PULSE_DOWN_L / PULSE_UP_L
//   - Columna derecha  (puntos 4,5,6 = SERVO[3..5]) usa
//     PULSE_DOWN_R / PULSE_UP_R
// Valores calibrados en la celda real (servo_cal_top).
//
// El patron se registra solo al inicio de cada periodo para
// que ningun pulso salga recortado a la mitad.
//
// A 50 MHz: 50 000 cuentas = 1 ms; 1 grado ~ 278 cuentas (SG90).
// Mantener todos los valores entre 50 000 y 100 000 (1 a 2 ms).
//====================================================

module servo_controller #(
    parameter PERIOD        = 1000000,   // 20 ms
    parameter PULSE_DOWN_L  = 70000,     // 1.400 ms
    parameter PULSE_UP_L    = 82000,     // 1.64 ms
    parameter PULSE_DOWN_R  = 80000,     // 1.60 ms
    parameter PULSE_UP_R    = 60000,     // 1.20 ms
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
            if (i < 3) begin : LEFT
                // Puntos 1, 2, 3
                assign servo_pwm[i] =
                    (pwm_count < (pattern_active[i] ? PULSE_UP_L : PULSE_DOWN_L));
            end
            else begin : RIGHT
                // Puntos 4, 5, 6 (en espejo)
                assign servo_pwm[i] =
                    (pwm_count < (pattern_active[i] ? PULSE_UP_R : PULSE_DOWN_R));
            end
        end
    endgenerate

endmodule
