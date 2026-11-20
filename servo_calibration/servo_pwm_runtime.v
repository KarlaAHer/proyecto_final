//====================================================
// PWM DE 6 SERVOS CON ANCHOS AJUSTABLES EN TIEMPO REAL
//
// Igual que servo_controller.v, pero los 4 anchos de pulso
// entran como senales (en microsegundos) en lugar de
// parametros fijos, para poder moverlos con los botones.
//
// Los anchos y el patron se registran al inicio de cada
// periodo, asi ningun pulso sale recortado.
//====================================================

module servo_pwm_runtime #(
    parameter PERIOD        = 1000000,   // 20 ms a 50 MHz
    parameter CLKS_PER_US   = 50,        // 50 MHz -> 50 cuentas por us
    parameter COUNTER_WIDTH = 20
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] down_l_us,
    input  wire [11:0] up_l_us,
    input  wire [11:0] down_r_us,
    input  wire [11:0] up_r_us,
    input  wire [5:0]  braille_pattern,  // bit[i] = punto i+1 (1 = arriba)
    output wire [5:0]  servo_pwm
);

    reg [COUNTER_WIDTH-1:0] pwm_count;
    reg [5:0]               pattern_active;
    reg [COUNTER_WIDTH-1:0] w_down_l, w_up_l, w_down_r, w_up_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pwm_count      <= 0;
            pattern_active <= 6'b000000;
            w_down_l       <= 0;
            w_up_l         <= 0;
            w_down_r       <= 0;
            w_up_r         <= 0;
        end
        else if (pwm_count == PERIOD - 1) begin
            pwm_count      <= 0;
            pattern_active <= braille_pattern;
            w_down_l       <= down_l_us * CLKS_PER_US;
            w_up_l         <= up_l_us   * CLKS_PER_US;
            w_down_r       <= down_r_us * CLKS_PER_US;
            w_up_r         <= up_r_us   * CLKS_PER_US;
        end
        else begin
            pwm_count <= pwm_count + 1'b1;
        end
    end

    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin : SERVO_CHANNELS
            if (i < 3) begin : LEFT
                assign servo_pwm[i] =
                    (pwm_count < (pattern_active[i] ? w_up_l : w_down_l));
            end
            else begin : RIGHT
                assign servo_pwm[i] =
                    (pwm_count < (pattern_active[i] ? w_up_r : w_down_r));
            end
        end
    endgenerate

endmodule
