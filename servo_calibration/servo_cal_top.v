//====================================================
// CALIBRACION CON 2 SERVOS
// SERVO_L = servo de la izquierda  (SW0: 1 = arriba, 0 = abajo)
// SERVO_R = servo de la derecha    (SW1: 1 = arriba, 0 = abajo)
// Cambia los 4 valores de abajo, compila y prueba.
// 50 000 cuentas = 1 ms ; ~278 cuentas = 1 grado
//====================================================

module servo_cal_top (
    input  wire       CLOCK_50,
    input  wire [1:0] SW,
    output wire       SERVO_L,
    output wire       SERVO_R
);

    wire [5:0] pwm;

    servo_controller #(
        .PULSE_DOWN_L (70000),   // <-- IZQUIERDA abajo
        .PULSE_UP_L   (83056),   // <-- IZQUIERDA arriba
        .PULSE_DOWN_R (80000),   // <-- DERECHA abajo
        .PULSE_UP_R   (66944)    // <-- DERECHA arriba
    ) u_servos (
        .clk             (CLOCK_50),
        .rst             (1'b0),
        .braille_pattern ({2'b00, SW[1], 2'b00, SW[0]}),  // punto 1 = izq, punto 4 = der
        .servo_pwm       (pwm)
    );

    assign SERVO_L = pwm[0];   // canal izquierdo (punto 1)
    assign SERVO_R = pwm[3];   // canal derecho   (punto 4)

endmodule
