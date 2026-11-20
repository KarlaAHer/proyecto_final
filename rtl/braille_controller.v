//====================================================
// CONTROLADOR PRINCIPAL (FSM DE MODOS)
//
// Modos:
//   1 = LECTURA    (PC -> FPGA -> servos)
//   2 = ESCRITURA  (botones -> FPGA -> PC)
//   3 = PRACTICA   (PC <-> FPGA, aciertos / errores)
//
// Seleccion de modo: por comando del PC o con SW[1:0]
// (01 = lectura, 10 = escritura, 11 = practica, 00 = solo PC).
// Gana la ultima accion.
//
// Protocolo (todas las lineas terminan en '\n'):
//
//   PC -> FPGA
//     R<texto>  lectura: carga palabra (1..MAX_LEN) y muestra el 1er caracter
//     R         lectura sin palabra (celda neutra)
//     W         escritura
//     P<c>      practica: objetivo c, celda neutra (el usuario no lo ve)
//     H<c>      practica: objetivo c mostrado en los servos (pista)
//     P         practica sin objetivo
//     N         equivale a presionar el boton NEXT
//     S         consulta el marcador
//     C         borra el marcador
//     Q         consulta el modo actual (responde M<m>)
//
//   FPGA -> PC
//     D<c>          lectura: se esta mostrando el caracter c
//     E             lectura: fin de palabra, celda neutra
//     K<c>          escritura: caracter tecleado ('?' = patron invalido,
//                   ' ' = NEXT, usado como espacio)
//     T<c>          practica: objetivo aceptado
//     O<c><hh><mm>  practica: ACIERTO, c = tecleado, hh/mm = aciertos/errores (hex)
//     X<c><hh><mm>  practica: ERROR
//     N             practica: el usuario pide la siguiente letra (NEXT)
//     S<hh><mm>     marcador
//     M<m>          cambio de modo por el switch, o respuesta a Q (m = R, W o P)
//     !L / !U / !T  error: palabra muy larga / comando o caracter no
//                   soportado / no hay objetivo de practica
//====================================================

module braille_controller #(
    parameter MAX_LEN = 16,
    parameter AW      = 4
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

    // Selector de modo por hardware (ya sincronizado)
    input  wire [1:0]    sw_mode,

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

    localparam MODE_READ  = 2'd1;
    localparam MODE_WRITE = 2'd2;
    localparam MODE_PRACT = 2'd3;

    localparam ST_IDLE   = 3'd0;
    localparam ST_CMD    = 3'd1;
    localparam ST_SHOW   = 3'd2;
    localparam ST_TARGET = 3'd3;
    localparam ST_SEND   = 3'd4;
    localparam ST_GAP    = 3'd5;

    reg [2:0] state;


    //====================================================
    // REGISTROS
    //====================================================

    reg [7:0]  cmd_r;
    reg [AW:0] len_r;
    reg        ovf_r;

    reg [AW:0] word_len;      // 0 = no hay palabra cargada
    reg [AW-1:0] char_idx;

    reg [7:0]  target;
    reg        target_valid;
    reg        hint;

    reg        chord_pend;
    reg [5:0]  chord_reg;
    reg        next_pend;

    reg [1:0]  sw_last;


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

    assign buf_raddr = char_idx;


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
                default:    mode_char = "P";
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
            mode         <= MODE_READ;
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
            hint         <= 1'b0;
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
                        // Solo R/P/H leen buffer[0]; los demas comandos
                        // (N, S, C...) no pierden la posicion de lectura
                        if (line_cmd == "R" || line_cmd == "P" || line_cmd == "H")
                            char_idx <= 0;
                        state    <= ST_CMD;
                    end

                    else if (sw_mode != sw_last) begin
                        // 2) Cambio del selector de modo
                        sw_last <= sw_mode;
                        if (sw_mode != 2'b00) begin
                            mode         <= sw_mode;
                            cell_pattern <= 6'b000000;
                            word_len     <= 0;
                            target_valid <= 1'b0;
                            msg_data     <= {32'd0, mode_char(sw_mode), "M"};
                            msg_len      <= 3'd2;
                            state        <= ST_SEND;
                        end
                    end

                    else if (chord_pend && !chord_valid) begin
                        // 3) Acorde capturado
                        chord_pend <= 1'b0;

                        if (mode == MODE_WRITE) begin
                            last_chord <= chord_reg;
                            msg_data   <= {32'd0, typed_ascii, "K"};
                            msg_len    <= 3'd2;
                            state      <= ST_SEND;
                        end

                        else if (mode == MODE_PRACT) begin
                            last_chord <= chord_reg;
                            if (!target_valid) begin
                                msg_data <= {32'd0, "T", "!"};
                                msg_len  <= 3'd2;
                            end
                            else begin
                                target_valid <= 1'b0;
                                // Retroalimentacion tactil: mostrar el
                                // patron correcto tras el intento
                                cell_pattern <= lut_pattern;
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
                            end
                            state <= ST_SEND;
                        end
                        // En lectura los acordes se ignoran
                    end

                    else if (next_pend) begin
                        // 4) Boton NEXT
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

                        else begin
                            msg_data <= {40'd0, "N"};        // siguiente letra
                            msg_len  <= 3'd1;
                            state    <= ST_SEND;
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
                            mode         <= MODE_READ;
                            target_valid <= 1'b0;
                            cell_pattern <= 6'b000000;
                            if (ovf_r) begin
                                word_len <= 0;
                                msg_data <= {32'd0, "L", "!"};
                                msg_len  <= 3'd2;
                            end
                            else if (len_r == 0) begin
                                word_len <= 0;
                                msg_data <= {32'd0, "R", "M"};
                                msg_len  <= 3'd2;
                            end
                            else begin
                                word_len <= len_r;
                                state    <= ST_SHOW;   // mostrar buffer[0]
                            end
                        end

                        "W": begin
                            mode         <= MODE_WRITE;
                            word_len     <= 0;
                            target_valid <= 1'b0;
                            cell_pattern <= 6'b000000;
                            msg_data     <= {32'd0, "W", "M"};
                            msg_len      <= 3'd2;
                        end

                        "P", "H": begin
                            mode         <= MODE_PRACT;
                            word_len     <= 0;
                            target_valid <= 1'b0;
                            cell_pattern <= 6'b000000;
                            hint         <= (cmd_r == "H");
                            if (len_r == 0) begin
                                msg_data <= {32'd0, "P", "M"};
                                msg_len  <= 3'd2;
                            end
                            else begin
                                target <= buf_rdata;
                                state  <= ST_TARGET;
                            end
                        end

                        "N": begin
                            next_pend <= 1'b1;
                            state     <= ST_IDLE;  // sin respuesta propia
                        end

                        "S": begin
                            msg_data <= {8'd0, hexc(misses[3:0]), hexc(misses[7:4]),
                                         hexc(hits[3:0]), hexc(hits[7:4]), "S"};
                            msg_len  <= 3'd5;
                        end

                        "Q": begin
                            msg_data <= {32'd0, mode_char(mode), "M"};
                            msg_len  <= 3'd2;
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
                // SHOW: mostrar buffer[char_idx] en la celda
                //============================================
                ST_SHOW: begin
                    cell_pattern <= lut_valid ? lut_pattern : 6'b000000;
                    msg_data     <= {32'd0, buf_rdata, "D"};
                    msg_len      <= 3'd2;
                    state        <= ST_SEND;
                end


                //============================================
                // TARGET: validar objetivo de practica
                //============================================
                ST_TARGET: begin
                    // lut_in = target porque mode ya es PRACTICA
                    if (lut_valid && target != " ") begin
                        target_valid <= 1'b1;
                        cell_pattern <= hint ? lut_pattern : 6'b000000;
                        msg_data     <= {32'd0, target, "T"};
                    end
                    else begin
                        msg_data <= {32'd0, "U", "!"};
                    end
                    msg_len <= 3'd2;
                    state   <= ST_SEND;
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

        end

    end

endmodule
