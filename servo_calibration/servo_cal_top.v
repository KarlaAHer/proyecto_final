//====================================================
// CALIBRACION DE SERVOS
// SW[5:0] = patron (1 = punto arriba, 0 = punto abajo)
// Cambia los 4 valores de abajo, compila y prueba.
// 50 000 cuentas = 1 ms ; ~278 cuentas = 1 grado
//====================================================

module servo_cal_top (
    input  wire       CLOCK_50,
    input  wire [5:0] SW,
    output wire [5:0] SERVO
);

    servo_controller #(
        .PULSE_DOWN_L (70000),   // <-- puntos 1,2,3 ABAJO
        .PULSE_UP_L   (83056),   // <-- puntos 1,2,3 ARRIBA
        .PULSE_DOWN_R (80000),   // <-- puntos 4,5,6 ABAJO
        .PULSE_UP_R   (66944)    // <-- puntos 4,5,6 ARRIBA
    ) u_servos (
        .clk             (CLOCK_50),
        .rst             (1'b0),
        .braille_pattern (SW),
        .servo_pwm       (SERVO)
    );

endmodule
