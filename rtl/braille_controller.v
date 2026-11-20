//====================================================
// CONTROLADOR PRINCIPAL (FSM DE MODOS)
//
// El modo se elige SOLO con los switches de la tarjeta:
//   SW1 SW0
//    0   0   0 = REPOSO     (celda neutra, no hace nada)
//    0   1   1 = LECTURA    (PC manda texto -> servos, NEXT avanza)
//    1   0   2 = ESCRITURA  (botones -> FPGA decodifica -> PC)
//    1   1   3 = PRACTICA   (FPGA elige letra aleatoria, compara,
//                            cuenta aciertos/errores y avanza sola)
//   SW2 = pista en practica (1 = la letra objetivo se muestra en
//         los servos)
//
// Toda la logica vive en la FPGA. El PC solo:
//   - envia el texto a mostrar en modo lectura,
//   - muestra / dice en voz alta lo que la FPGA le reporta.
//
// Protocolo (todas las lineas terminan en '\n'):
//
//   PC -> FPGA
//     R<texto>  carga palabra (1..MAX_LEN) y muestra el 1er caracter
//               (solo en modo LECTURA; en otro modo responde !M)
//     L<n>      letras por sesion de practica, n = 0..99 en decimal
//               (0 = sin limite). Es solo un ajuste: responde L<hh>
//     Q         consulta el modo actual (responde M<m>)
//     S         consulta el marcador
//     C         borra el marcador
//     N         equivale al boton NEXT (para pruebas)
//
//   FPGA -> PC
//     M<m>          modo actual (m = I, R, W, P); se manda al mover
//                   los switches y como respuesta a Q
//     D<c>          lectura: se esta mostrando el caracter c
//     E             lectura: fin de palabra, celda neutra
//     K<c>          escritura: caracter tecleado ('?' = patron invalido,
//                   ' ' = NEXT, usado como espacio)
//     T<c>          practica: nueva letra objetivo c
//     O<c><hh><mm>  practica: ACIERTO, c = tecleado, hh/mm = aciertos/errores (hex)
//     X<c><hh><mm>  practica: ERROR
//     F<hh><mm>     practica: sesion terminada (resultado final)
//     L<hh>         letras por sesion configuradas (hex)
//     S<hh><mm>     marcador
//     !L / !U / !M  error: palabra muy larga / comando no soportado /
//                   la tarjeta no esta en modo lectura
//
// Practica:
//   - Al entrar al modo se borra el marcador y se elige una letra.
//   - Tras cada intento la celda muestra el patron correcto durante
//     FEEDBACK_DELAY ciclos y luego se elige otra letra sola.
//   - NEXT salta a otra letra sin contar el intento.
//   - Si hay limite (L<n>), al completar n intentos se manda F<hh><mm>
//     y se espera; NEXT empieza otra sesion (manda MP y una letra).
//====================================================

module braille_controller #(
    parameter MAX_LEN        = 16,
    parameter AW             = 4,
    parameter FEEDBACK_DELAY = 100000000,   // 2 s a 50 MHz
    parameter FB_WIDTH       = 27
)(
    input  wire          clk,
    input  wire          rst,

    // Linea de comando recibida
    input  wire          line_ready,
    input  wire [7:0]    line_cmd,
    input  wire [AW:0]   line_len,
    input  wire          line_ovf,
    output reg           line_ack,

    // Lectura del buffer de caracteres
    output wire [AW-1:0] buf_raddr,
    input  wire [7:0]    buf_rdata,

    // Teclado Braille
    input  wire          chord_valid,
    input  wire [5:0]    chord,
    input  wire          next_pulse,

    // Switches (ya sincronizados)
    input  wire [1:0]    sw_mode,
    input  wire          sw_hint,

    // Transmisor de mensajes
    input  wire          msg_busy,
    output reg           msg_start,
    output reg  [2:0]    msg_len,
    output reg  [47:0]   msg_data,

    // Estado visible
    output reg  [1:0]    mode,
    output reg  [5:0]    cell_pattern,   // hacia servo_controller
    output reg  [5:0]    last_chord,
    output reg  [7:0]    hits,
    output reg  [7:0]    misses
);

    //====================================================
    // CONSTANTES
    //====================================================

    localparam MODE_IDLE  = 2'd0;
    localparam MODE_READ  = 2'd1;
    localparam MODE_WRITE = 2'd2;
    localparam MODE_PRACT = 2'd3;

    localparam ST_IDLE   = 3'd0;
    localparam ST_CMD    = 3'd1;
    localparam ST_SHOW   = 3'd2;
    localparam ST_TARGET = 3'd3;
    localparam ST_SEND   = 3'd4;
    localparam ST_GAP    = 3'd5;
    localparam ST_LDIG2  = 3'd6;

    reg [2:0] state;


    //====================================================
    // REGISTROS
    //====================================================

    reg [7:0]    cmd_r;
    reg [AW:0]   len_r;
    reg          ovf_r;

    reg [AW:0]   word_len;      // 0 = no hay palabra cargada
    reg [AW-1:0] char_idx;

    reg [7:0]    target;
    reg          target_valid;  // esperando intento del usuario
    reg          need_target;   // pedir una letra nueva
    reg          fb_wait;       // mostrando retroalimentacion
    reg [FB_WIDTH-1:0] fb_cnt;
    reg [7:0]    rounds_cfg;    // letras por sesion (0 = sin limite)
    reg          last_try;      // el intento actual completa la sesion
    reg          need_final;    // mandar resultado final
    reg          sess_done;     // sesion terminada, esperando NEXT
    reg [3:0]    dig0;          // primer digito de L<n>

    reg          chord_pend;
    reg [5:0]    chord_reg;
    reg          next_pend;

    reg [1:0]    sw_last;


    //====================================================
    // GENERADOR ALEATORIO (LFSR de 16 bits, corre siempre)
    //====================================================

    reg [15:0] lfsr;

    always @(posedge clk or posedge rst) begin
        if (rst)
            lfsr <= 16'hACE1;
        else
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    // Indice 0..25 (a..z) y se evita repetir la letra anterior
    wire [4:0] r5       = lfsr[4:0];
    wire [4:0] rnd_idx  = (r5 >= 5'd26) ? (r5 - 5'd26) : r5;
    wire [7:0] rnd_char = 8'h61 + rnd_idx;
    wire [7:0] new_char = (rnd_char != target) ? rnd_char :
                          (rnd_idx == 5'd25)   ? 8'h61 : (rnd_char + 8'd1);


    //====================================================
    // CONVERSORES (una sola instancia de cada uno)
    //====================================================

    // En practica se convierte el objetivo; en los demas
    // modos, el caracter actual del buffer.
    wire [7:0] lut_in = (mode == MODE_PRACT) ? target : buf_rdata;
    wire [5:0] lut_pattern;
    wire       lut_valid;

    ascii_to_braille A2B (
        .ascii_in   (lut_in),
        .braille_out(lut_pattern),
        .char_valid (lut_valid)
    );

    wire [7:0] typed_ascii;
    wire       typed_valid;

    braille_to_ascii B2A (
        .braille_in(chord_reg),
        .ascii_out (typed_ascii),
        .char_valid(typed_valid)
    );

    // L<n> lee buffer[0] en ST_CMD y buffer[1] en ST_LDIG2
    assign buf_raddr = (state == ST_CMD && cmd_r == "L") ? {AW{1'b0}} :
                       (state == ST_LDIG2)               ? {{(AW-1){1'b0}}, 1'b1} :
                                                           char_idx;
    wire       is_digit  = (buf_rdata >= "0") && (buf_rdata <= "9");
    wire [3:0] digit_val = buf_rdata[3:0];
    wire [7:0] total_new = hits + misses + 1'b1;


    //====================================================
    // FUNCIONES AUXILIARES
    //====================================================

    // Nibble -> caracter hexadecimal ASCII
    function [7:0] hexc;
        input [3:0] n;
        begin
            hexc = (n < 4'd10) ? (8'h30 + n) : (8'h37 + n);
        end
    endfunction

    function [7:0] mode_char;
        input [1:0] m;
        begin
            case (m)
                MODE_READ:  mode_char = "R";
                MODE_WRITE: mode_char = "W";
                MODE_PRACT: mode_char = "P";
                default:    mode_char = "I";
            endcase
        end
    endfunction

    wire [7:0] hits_inc   = hits + 1'b1;
    wire [7:0] misses_inc = misses + 1'b1;
    wire       is_hit     = (chord_reg == lut_pattern);


    //====================================================
    // MAQUINA DE ESTADOS
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            state        <= ST_IDLE;
            line_ack     <= 1'b0;
            msg_start    <= 1'b0;
            msg_len      <= 3'd0;
            msg_data     <= 48'd0;
            mode         <= MODE_IDLE;
            cell_pattern <= 6'b000000;
            last_chord   <= 6'b000000;
            hits         <= 8'd0;
            misses       <= 8'd0;
            cmd_r        <= 8'd0;
            len_r        <= 0;
            ovf_r        <= 1'b0;
            word_len     <= 0;
            char_idx     <= 0;
            target       <= 8'd0;
            target_valid <= 1'b0;
            need_target  <= 1'b0;
            fb_wait      <= 1'b0;
            fb_cnt       <= 0;
            rounds_cfg   <= 8'd10;
            last_try     <= 1'b0;
            need_final   <= 1'b0;
            sess_done    <= 1'b0;
            dig0         <= 4'd0;
            chord_pend   <= 1'b0;
            chord_reg    <= 6'b000000;
            next_pend    <= 1'b0;
            sw_last      <= 2'b00;
        end

        else begin

            line_ack  <= 1'b0;
            msg_start <= 1'b0;

            // Los eventos se guardan aunque la FSM este ocupada
            if (chord_valid) begin
                chord_pend <= 1'b1;
                chord_reg  <= chord;
            end

            if (next_pulse)
                next_pend <= 1'b1;

            // Temporizador de retroalimentacion en practica
            if (fb_wait) begin
                if (fb_cnt == FEEDBACK_DELAY - 1) begin
                    fb_wait <= 1'b0;
                    if (last_try)
                        need_final  <= 1'b1;   // fin de la sesion
                    else
                        need_target <= 1'b1;   // siguiente letra
                end
                else
                    fb_cnt <= fb_cnt + 1'b1;
            end


            case (state)

                //============================================
                // IDLE: atender eventos por prioridad
                //============================================
                ST_IDLE: begin

                    if (line_ready) begin
                        // 1) Comando del PC
                        line_ack <= 1'b1;
                        cmd_r    <= line_cmd;
                        len_r    <= line_len;
                        ovf_r    <= line_ovf;
                        if (line_cmd == "R" && mode == MODE_READ)
                            char_idx <= 0;            // para leer buffer[0]
                        state    <= ST_CMD;
                    end

                    else if (sw_mode != sw_last) begin
                        // 2) Cambio de modo con los switches
                        sw_last      <= sw_mode;
                        mode         <= sw_mode;
                        cell_pattern <= 6'b000000;
                        word_len     <= 0;
                        target_valid <= 1'b0;
                        fb_wait      <= 1'b0;
                        last_try     <= 1'b0;
                        need_final   <= 1'b0;
                        sess_done    <= 1'b0;
                        chord_pend   <= 1'b0;
                        next_pend    <= 1'b0;
                        if (sw_mode == MODE_PRACT) begin
                            hits        <= 8'd0;     // sesion nueva
                            misses      <= 8'd0;
                            need_target <= 1'b1;     // primera letra
                        end
                        else
                            need_target <= 1'b0;
                        msg_data <= {32'd0, mode_char(sw_mode), "M"};
                        msg_len  <= 3'd2;
                        state    <= ST_SEND;
                    end

                    else if (need_final && mode == MODE_PRACT) begin
                        // 3a) Sesion terminada: resultado final
                        need_final <= 1'b0;
                        last_try   <= 1'b0;
                        sess_done  <= 1'b1;
                        msg_data   <= {8'd0, hexc(misses[3:0]), hexc(misses[7:4]),
                                       hexc(hits[3:0]), hexc(hits[7:4]), "F"};
                        msg_len    <= 3'd5;
                        state      <= ST_SEND;
                    end

                    else if (need_target && mode == MODE_PRACT && !sess_done) begin
                        // 3) Nueva letra de practica (aleatoria)
                        need_target <= 1'b0;
                        target      <= new_char;
                        state       <= ST_TARGET;
                    end

                    else if (chord_pend && !chord_valid) begin
                        // 4) Acorde capturado
                        chord_pend <= 1'b0;

                        if (mode == MODE_WRITE) begin
                            last_chord <= chord_reg;
                            msg_data   <= {32'd0, typed_ascii, "K"};
                            msg_len    <= 3'd2;
                            state      <= ST_SEND;
                        end

                        else if (mode == MODE_PRACT && target_valid) begin
                            last_chord   <= chord_reg;
                            target_valid <= 1'b0;
                            fb_wait      <= 1'b1;     // mostrar respuesta
                            fb_cnt       <= 0;
                            last_try     <= (rounds_cfg != 0) &&
                                            (total_new >= rounds_cfg);
                            msg_len      <= 3'd6;
                            if (is_hit) begin
                                hits     <= hits_inc;
                                msg_data <= {hexc(misses[3:0]), hexc(misses[7:4]),
                                             hexc(hits_inc[3:0]), hexc(hits_inc[7:4]),
                                             typed_ascii, "O"};
                            end
                            else begin
                                misses   <= misses_inc;
                                msg_data <= {hexc(misses_inc[3:0]), hexc(misses_inc[7:4]),
                                             hexc(hits[3:0]), hexc(hits[7:4]),
                                             typed_ascii, "X"};
                            end
                            state <= ST_SEND;
                        end
                        // En reposo, lectura o durante la retroalimentacion
                        // los acordes se ignoran
                    end

                    else if (next_pend) begin
                        // 5) Boton NEXT
                        next_pend <= 1'b0;

                        if (mode == MODE_READ) begin
                            if (word_len != 0) begin
                                if (char_idx + 1'b1 < word_len) begin
                                    char_idx <= char_idx + 1'b1;
                                    state    <= ST_SHOW;
                                end
                                else begin
                                    // Fin de palabra
                                    word_len     <= 0;
                                    cell_pattern <= 6'b000000;
                                    msg_data     <= {40'd0, "E"};
                                    msg_len      <= 3'd1;
                                    state        <= ST_SEND;
                                end
                            end
                        end

                        else if (mode == MODE_WRITE) begin
                            msg_data <= {32'd0, " ", "K"};   // espacio
                            msg_len  <= 3'd2;
                            state    <= ST_SEND;
                        end

                        else if (mode == MODE_PRACT) begin
                            if (sess_done) begin
                                // Nueva sesion
                                sess_done   <= 1'b0;
                                hits        <= 8'd0;
                                misses      <= 8'd0;
                                need_target <= 1'b1;
                                msg_data    <= {32'd0, "P", "M"};
                                msg_len     <= 3'd2;
                                state       <= ST_SEND;
                            end
                            else if (!fb_wait) begin
                                // Saltar letra (no cuenta)
                                target_valid <= 1'b0;
                                need_target  <= 1'b1;
                            end
                        end
                    end

                end


                //============================================
                // CMD: ejecutar el comando (buffer[0] valido)
                //============================================
                ST_CMD: begin

                    state <= ST_SEND;      // por defecto se responde

                    case (cmd_r)

                        "R": begin
                            if (mode != MODE_READ) begin
                                msg_data <= {32'd0, "M", "!"};
                                msg_len  <= 3'd2;
                            end
                            else if (ovf_r) begin
                                word_len     <= 0;
                                cell_pattern <= 6'b000000;
                                msg_data     <= {32'd0, "L", "!"};
                                msg_len      <= 3'd2;
                            end
                            else if (len_r == 0) begin
                                msg_data <= {32'd0, "U", "!"};
                                msg_len  <= 3'd2;
                            end
                            else begin
                                word_len <= len_r;
                                state    <= ST_SHOW;   // mostrar buffer[0]
                            end
                        end

                        "N": begin
                            next_pend <= 1'b1;
                            state     <= ST_IDLE;  // sin respuesta propia
                        end

                        "L": begin
                            if (len_r == 0 || len_r > 2 || !is_digit) begin
                                msg_data <= {32'd0, "U", "!"};
                                msg_len  <= 3'd2;
                            end
                            else if (len_r == 1) begin
                                rounds_cfg <= {4'd0, digit_val};
                                msg_data   <= {24'd0, hexc(digit_val), "0", "L"};
                                msg_len    <= 3'd3;
                            end
                            else begin
                                dig0  <= digit_val;
                                state <= ST_LDIG2;     // leer el 2o digito
                            end
                        end

                        "Q": begin
                            msg_data <= {32'd0, mode_char(mode), "M"};
                            msg_len  <= 3'd2;
                        end

                        "S": begin
                            msg_data <= {8'd0, hexc(misses[3:0]), hexc(misses[7:4]),
                                         hexc(hits[3:0]), hexc(hits[7:4]), "S"};
                            msg_len  <= 3'd5;
                        end

                        "C": begin
                            hits     <= 8'd0;
                            misses   <= 8'd0;
                            msg_data <= {8'd0, "0", "0", "0", "0", "S"};
                            msg_len  <= 3'd5;
                        end

                        default: begin
                            msg_data <= {32'd0, "U", "!"};
                            msg_len  <= 3'd2;
                        end

                    endcase

                end


                //============================================
                // LDIG2: segundo digito de L<n> (buffer[1])
                //============================================
                ST_LDIG2: begin
                    if (is_digit) begin
                        rounds_cfg <= dig0 * 8'd10 + digit_val;
                        msg_data   <= {24'd0,
                                       hexc((dig0 * 8'd10 + digit_val) & 8'h0F),
                                       hexc((dig0 * 8'd10 + digit_val) >> 4), "L"};
                        msg_len    <= 3'd3;
                    end
                    else begin
                        msg_data <= {32'd0, "U", "!"};
                        msg_len  <= 3'd2;
                    end
                    state <= ST_SEND;
                end


                //============================================
                // SHOW: mostrar buffer[char_idx] en la celda
                //============================================
                ST_SHOW: begin
                    cell_pattern <= lut_valid ? lut_pattern : 6'b000000;
                    msg_data     <= {32'd0, buf_rdata, "D"};
                    msg_len      <= 3'd2;
                    state        <= ST_SEND;
                end


                //============================================
                // TARGET: anunciar la nueva letra de practica
                //============================================
                ST_TARGET: begin
                    target_valid <= 1'b1;
                    msg_data     <= {32'd0, target, "T"};
                    msg_len      <= 3'd2;
                    state        <= ST_SEND;
                end


                //============================================
                // SEND: lanzar el mensaje cuando el TX este libre
                //============================================
                ST_SEND: begin
                    if (!msg_busy) begin
                        msg_start <= 1'b1;
                        state     <= ST_GAP;
                    end
                end

                // Un ciclo para que msg_busy se active
                ST_GAP: begin
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;

            endcase


            // Celda en practica (se actualiza en vivo):
            //   esperando intento -> pista solo si SW2 = 1
            //   retroalimentacion -> patron correcto
            if (mode == MODE_PRACT) begin
                if (fb_wait)
                    cell_pattern <= lut_pattern;
                else if (target_valid && sw_hint)
                    cell_pattern <= lut_pattern;
                else
                    cell_pattern <= 6'b000000;
            end

        end

    end

endmodule
