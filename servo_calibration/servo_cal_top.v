//====================================================
// CALIBRACION CON 2 SERVOS (archivo unico, no necesita otros)
// SERVO_L = servo de la izquierda  (SW0: 1 = arriba, 0 = abajo)
// SERVO_R = servo de la derecha    (SW1: 1 = arriba, 0 = abajo)
// Cambia los 4 valores de abajo, compila y prueba.
// 50 000 cuentas = 1 ms ; ~278 cuentas = 1 grado
//====================================================

module servo_cal_top #(
    parameter PULSE_DOWN_L = 70000,   // <-- IZQUIERDA abajo
    parameter PULSE_UP_L   = 83056,   // <-- IZQUIERDA arriba
    parameter PULSE_DOWN_R = 80000,   // <-- DERECHA abajo
    parameter PULSE_UP_R   = 66944    // <-- DERECHA arriba
)(
    input  wire       CLOCK_50,
    input  wire [1:0] SW,
    output wire       SERVO_L,
    output wire       SERVO_R
);

    localparam PERIOD = 1000000;      // 20 ms

    reg [19:0] pwm_count = 0;
    reg [1:0]  sw_active = 2'b00;

    always @(posedge CLOCK_50) begin
        if (pwm_count == PERIOD - 1) begin
            pwm_count <= 0;
            sw_active <= SW;          // cambia solo al inicio del periodo
        end
        else
            pwm_count <= pwm_count + 1'b1;
    end

    assign SERVO_L = (pwm_count < (sw_active[0] ? PULSE_UP_L : PULSE_DOWN_L));
    assign SERVO_R = (pwm_count < (sw_active[1] ? PULSE_UP_R : PULSE_DOWN_R));

endmodule
