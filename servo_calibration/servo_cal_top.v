//====================================================
// MINI PROYECTO: CALIBRACION DE SERVOS
//
// Ajusta en vivo los 4 anchos de pulso de servo_controller.v
// y los muestra en los displays en MICROSEGUNDOS.
//
// CONTROLES
//   SW[9]    reset (1 = reset, vuelve a los valores de fabrica)
//   SW[1:0]  parametro a editar:
//              00 = PULSE_DOWN_L   (HEX5-4 muestra "L d")
//              01 = PULSE_UP_L     ("L U")
//              10 = PULSE_DOWN_R   ("r d")
//              11 = PULSE_UP_R     ("r U")
//   SW[8]    modo:
//              1 = PREVIEW: los 6 servos van a la posicion
//                  que estas editando (todos abajo si editas
//                  DOWN, todos arriba si editas UP)
//              0 = PRUEBA: SW[7:2] es el patron braille
//                  (SW2 = punto 1 ... SW7 = punto 6)
//   KEY[0]   + paso (mantener = repite)
//   KEY[1]   - paso (mantener = repite)
//
// DISPLAYS
//   HEX5 HEX4 = parametro (L/r, d/U)
//   HEX3..HEX0 = ancho de pulso en us (ej. 1400)
//   LEDR[5:0]  = patron que reciben los servos
//   LEDR[9]    = el valor llego al limite (MIN_US o MAX_US)
//
// PARA PASAR AL PROGRAMA ORIGINAL:
//   valor del parametro = (us en el display) * 50
//   ej. 1400 us -> PULSE_DOWN_L = 70000
//====================================================

module servo_cal_top #(
    parameter CLKS_PER_US    = 50,
    parameter PERIOD         = 1000000,   // 20 ms
    parameter DEBOUNCE_COUNT = 500000,    // 10 ms
    parameter HOLD_DELAY     = 25000000,  // 0.5 s
    parameter REPEAT_DELAY   = 5000000,   // 0.1 s
    parameter STEP_US        = 5,         // ~1 grado en un SG90
    parameter MIN_US         = 1000,
    parameter MAX_US         = 2000,
    // Valores de arranque = los de tu servo_controller.v
    parameter INIT_DOWN_L    = 1400,
    parameter INIT_UP_L      = 1661,
    parameter INIT_DOWN_R    = 1600,
    parameter INIT_UP_R      = 1339
)(
    input  wire       CLOCK_50,
    input  wire [1:0] KEY,       // activos en bajo
    input  wire [9:0] SW,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,
    output wire [9:0] LEDR,
    output wire [5:0] SERVO      // misma asignacion de pines que en el proyecto final
);

    wire clk = CLOCK_50;
    wire rst = SW[9];

    //------------------------------------------------
    // Botones: debounce (tu modulo) + auto-repeticion
    //------------------------------------------------
    wire [1:0] key_level, key_pulse;
    wire       step_up, step_down;

    button_conditioner #(
        .N_BUTTONS      (2),
        .DEBOUNCE_COUNT (DEBOUNCE_COUNT),
        .COUNTER_WIDTH  (20)
    ) u_buttons (
        .clk             (clk),
        .rst             (rst),
        .buttons_n       (KEY),
        .buttons_pressed (key_level),
        .press_pulse     (key_pulse)
    );

    key_repeat #(.HOLD_DELAY(HOLD_DELAY), .REPEAT_DELAY(REPEAT_DELAY)) u_rep_up (
        .clk(clk), .rst(rst),
        .pressed(key_level[0] & ~key_level[1]), .press_pulse(key_pulse[0]),
        .step(step_up)
    );

    key_repeat #(.HOLD_DELAY(HOLD_DELAY), .REPEAT_DELAY(REPEAT_DELAY)) u_rep_down (
        .clk(clk), .rst(rst),
        .pressed(key_level[1] & ~key_level[0]), .press_pulse(key_pulse[1]),
        .step(step_down)
    );

    //------------------------------------------------
    // Registros de los 4 anchos (en us)
    //------------------------------------------------
    reg  [11:0] pulse_us [0:3];   // 0=DOWN_L 1=UP_L 2=DOWN_R 3=UP_R
    wire [1:0]  sel = SW[1:0];
    wire [11:0] cur = pulse_us[sel];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pulse_us[0] <= INIT_DOWN_L;
            pulse_us[1] <= INIT_UP_L;
            pulse_us[2] <= INIT_DOWN_R;
            pulse_us[3] <= INIT_UP_R;
        end
        else if (step_up) begin
            pulse_us[sel] <= (cur + STEP_US > MAX_US) ? MAX_US : cur + STEP_US;
        end
        else if (step_down) begin
            pulse_us[sel] <= (cur < MIN_US + STEP_US) ? MIN_US : cur - STEP_US;
        end
    end

    //------------------------------------------------
    // Patron hacia los servos
    //------------------------------------------------
    wire [5:0] pattern = SW[8] ? {6{sel[0]}}   // PREVIEW: UP si editas UP_x
                               : SW[7:2];      // PRUEBA: patron manual

    servo_pwm_runtime #(
        .PERIOD      (PERIOD),
        .CLKS_PER_US (CLKS_PER_US)
    ) u_pwm (
        .clk             (clk),
        .rst             (rst),
        .down_l_us       (pulse_us[0]),
        .up_l_us         (pulse_us[1]),
        .down_r_us       (pulse_us[2]),
        .up_r_us         (pulse_us[3]),
        .braille_pattern (pattern),
        .servo_pwm       (SERVO)
    );

    //------------------------------------------------
    // Displays
    //------------------------------------------------
    wire [3:0] d3, d2, d1, d0;
    bin12_to_bcd u_bcd (.bin(cur), .thousands(d3), .hundreds(d2), .tens(d1), .ones(d0));

    seg7_cal s0 (.code(d0), .seg(HEX0));
    seg7_cal s1 (.code(d1), .seg(HEX1));
    seg7_cal s2 (.code(d2), .seg(HEX2));
    seg7_cal s3 (.code(d3), .seg(HEX3));
    seg7_cal s4 (.code(sel[0] ? 4'd13 : 4'd12), .seg(HEX4));  // U / d
    seg7_cal s5 (.code(sel[1] ? 4'd11 : 4'd10), .seg(HEX5));  // r / L

    assign LEDR[5:0] = pattern;
    assign LEDR[8:6] = 3'b000;
    assign LEDR[9]   = (cur == MIN_US) || (cur == MAX_US);

endmodule
