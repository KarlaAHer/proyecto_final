//====================================================
// TOP - SISTEMA BIDIRECCIONAL TEXTO <-> BRAILLE (DE10-Lite)
//
//   PC/MATLAB <-> FT232RL (o HC-05) <-> UART 9600 8N1 <-> FPGA
//   FPGA -> 6 servos (celda Braille)
//   6 botones Braille + NEXT -> FPGA
//
// Entradas fisicas:
//   KEY[0]  reset (activo en bajo)
//   KEY[1]  NEXT (boton de la tarjeta, activo en bajo)
//   SW[1:0] selector de modo: 00 = reposo, 01 = lectura,
//           10 = escritura, 11 = practica
//   SW[2]   pista en practica (1 = mostrar la letra en los servos)
//   DOT_N[5:0] botones externos de los puntos 1..6 (a GND,
//           con pull-up; DOT_N[0] = punto 1)
//
// Salidas:
//   SERVO[5:0] PWM de los puntos 1..6 (SERVO[0] = punto 1)
//   LEDR[5:0]  patron en la celda (escritura: ultimo acorde)
//   LEDR[7:6]  modo, LEDR[8] NEXT presionado, LEDR[9] TX activo
//   HEX5 modo (0/1/2/3), HEX3-HEX2 aciertos, HEX1-HEX0 errores (hex)
//====================================================

module braille_top #(
    parameter CLKS_PER_BIT   = 5208,      // 50 MHz / 9600
    parameter DEBOUNCE_COUNT = 500000,    // 10 ms
    parameter DEB_WIDTH      = 19,
    parameter SERVO_PERIOD   = 1000000,   // 20 ms
    // Servos izquierda (puntos 1,2,3) y derecha (4,5,6, en espejo)
    // Valores calibrados con servo_cal_top
    // Abajo = posicion calibrada; arriba = mismo recorrido que en la
    // calibracion pero en el sentido contrario (izq -12000, der +20000)
    parameter PULSE_DOWN_L   = 70000,     // 1.40 ms  izquierda abajo (reposo)
    parameter PULSE_UP_L     = 58000,     // 1.16 ms  izquierda arriba
    parameter PULSE_DOWN_R   = 80000,     // 1.60 ms  derecha abajo (reposo)
    parameter PULSE_UP_R     = 100000,    // 2.00 ms  derecha arriba
    parameter SERVO_WIDTH    = 20,
    parameter MAX_LEN        = 16,
    parameter AW             = 4,
    parameter FEEDBACK_DELAY = 100000000, // 2 s mostrando la respuesta
    parameter FB_WIDTH       = 27
)(
    input  wire       CLOCK_50,
    input  wire [1:0] KEY,
    input  wire [2:0] SW,

    input  wire       UART_RX,
    output wire       UART_TX,

    input  wire [5:0] DOT_N,

    output wire [5:0] SERVO,

    output wire [9:0] LEDR,
    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2,
    output wire [7:0] HEX3,
    output wire [7:0] HEX4,
    output wire [7:0] HEX5
);

    wire clk = CLOCK_50;
    wire rst = ~KEY[0];


    //====================================================
    // UART RX + LINEAS DE COMANDO + BUFFER
    //====================================================

    wire [7:0] rx_byte;
    wire       rx_ready;

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) RX0 (
        .clk       (clk),
        .rst       (rst),
        .rx        (UART_RX),
        .data_out  (rx_byte),
        .data_ready(rx_ready)
    );

    wire [7:0]    line_cmd;
    wire [AW:0]   line_len;
    wire          line_ovf;
    wire          line_ready;
    wire          line_ack;
    wire          buf_we;
    wire [AW-1:0] buf_waddr;
    wire [7:0]    buf_wdata;
    wire [AW-1:0] buf_raddr;
    wire [7:0]    buf_rdata;

    line_rx #(.MAX_LEN(MAX_LEN), .AW(AW)) LINE0 (
        .clk       (clk),
        .rst       (rst),
        .rx_data   (rx_byte),
        .rx_valid  (rx_ready),
        .ack       (line_ack),
        .cmd       (line_cmd),
        .len       (line_len),
        .overflow  (line_ovf),
        .line_ready(line_ready),
        .buf_we    (buf_we),
        .buf_waddr (buf_waddr),
        .buf_wdata (buf_wdata)
    );

    char_buffer #(.MAX_LEN(MAX_LEN), .AW(AW)) BUF0 (
        .clk    (clk),
        .wr_en  (buf_we),
        .wr_addr(buf_waddr),
        .wr_data(buf_wdata),
        .rd_addr(buf_raddr),
        .rd_data(buf_rdata)
    );


    //====================================================
    // BOTONES: SINCRONIZACION, ANTIRREBOTE Y ACORDE
    //====================================================

    wire [6:0] btn_pressed;
    wire [6:0] btn_pulse;

    // bit 6 = NEXT (KEY[1]); bits 5..0 = puntos 6..1
    button_conditioner #(
        .N_BUTTONS     (7),
        .DEBOUNCE_COUNT(DEBOUNCE_COUNT),
        .COUNTER_WIDTH (DEB_WIDTH)
    ) BTN0 (
        .clk            (clk),
        .rst            (rst),
        .buttons_n      ({KEY[1], DOT_N}),
        .buttons_pressed(btn_pressed),
        .press_pulse    (btn_pulse)
    );

    wire [5:0] chord;
    wire       chord_valid;

    chord_capture CHORD0 (
        .clk         (clk),
        .rst         (rst),
        .dots_pressed(btn_pressed[5:0]),
        .chord       (chord),
        .chord_valid (chord_valid)
    );


    //====================================================
    // SWITCHES: MODO (SW1..SW0) Y PISTA (SW2), sincronizados
    //====================================================

    reg [2:0] sw_s1, sw_s2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sw_s1 <= 3'b000;
            sw_s2 <= 3'b000;
        end
        else begin
            sw_s1 <= SW;
            sw_s2 <= sw_s1;
        end
    end


    //====================================================
    // CONTROLADOR
    //====================================================

    wire        msg_busy;
    wire        msg_start;
    wire [2:0]  msg_len;
    wire [47:0] msg_data;
    wire [1:0]  mode;
    wire [5:0]  cell_pattern;
    wire [5:0]  last_chord;
    wire [7:0]  hits;
    wire [7:0]  misses;

    braille_controller #(
        .MAX_LEN       (MAX_LEN),
        .AW            (AW),
        .FEEDBACK_DELAY(FEEDBACK_DELAY),
        .FB_WIDTH      (FB_WIDTH)
    ) CTRL0 (
        .clk         (clk),
        .rst         (rst),
        .line_ready  (line_ready),
        .line_cmd    (line_cmd),
        .line_len    (line_len),
        .line_ovf    (line_ovf),
        .line_ack    (line_ack),
        .buf_raddr   (buf_raddr),
        .buf_rdata   (buf_rdata),
        .chord_valid (chord_valid),
        .chord       (chord),
        .next_pulse  (btn_pulse[6]),
        .sw_mode     (sw_s2[1:0]),
        .sw_hint     (sw_s2[2]),
        .msg_busy    (msg_busy),
        .msg_start   (msg_start),
        .msg_len     (msg_len),
        .msg_data    (msg_data),
        .mode        (mode),
        .cell_pattern(cell_pattern),
        .last_chord  (last_chord),
        .hits        (hits),
        .misses      (misses)
    );


    //====================================================
    // UART TX (mensajes de linea)
    //====================================================

    msg_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) MSG0 (
        .clk     (clk),
        .rst     (rst),
        .start   (msg_start),
        .msg_len (msg_len),
        .msg_data(msg_data),
        .tx      (UART_TX),
        .busy    (msg_busy)
    );


    //====================================================
    // SERVOS (un contador compartido para los 6 canales)
    //====================================================

    servo_controller #(
        .PERIOD       (SERVO_PERIOD),
        .PULSE_DOWN_L (PULSE_DOWN_L),
        .PULSE_UP_L   (PULSE_UP_L),
        .PULSE_DOWN_R (PULSE_DOWN_R),
        .PULSE_UP_R   (PULSE_UP_R),
        .COUNTER_WIDTH(SERVO_WIDTH)
    ) SERVO0 (
        .clk            (clk),
        .rst            (rst),
        .braille_pattern(cell_pattern),
        .servo_pwm      (SERVO)
    );


    //====================================================
    // LEDS Y DISPLAYS (depuracion)
    //====================================================

    // En escritura los LEDs muestran los botones presionados en
    // vivo o, si no hay ninguno, el ultimo acorde enviado.
    assign LEDR[5:0] = (mode == 2'd2) ?
                       ((btn_pressed[5:0] != 0) ? btn_pressed[5:0] : last_chord) :
                       cell_pattern;
    assign LEDR[7:6] = mode;
    assign LEDR[8]   = btn_pressed[6];
    assign LEDR[9]   = msg_busy;

    hex7seg H0 (.hex(misses[3:0]),     .blank(1'b0), .seg(HEX0[6:0]));
    hex7seg H1 (.hex(misses[7:4]),     .blank(1'b0), .seg(HEX1[6:0]));
    hex7seg H2 (.hex(hits[3:0]),       .blank(1'b0), .seg(HEX2[6:0]));
    hex7seg H3 (.hex(hits[7:4]),       .blank(1'b0), .seg(HEX3[6:0]));
    hex7seg H4 (.hex(4'h0),            .blank(1'b1), .seg(HEX4[6:0]));
    hex7seg H5 (.hex({2'b00, mode}),   .blank(1'b0), .seg(HEX5[6:0]));

    // Puntos decimales apagados
    assign HEX0[7] = 1'b1;
    assign HEX1[7] = 1'b1;
    assign HEX2[7] = 1'b1;
    assign HEX3[7] = 1'b1;
    assign HEX4[7] = 1'b1;
    assign HEX5[7] = 1'b1;

endmodule
