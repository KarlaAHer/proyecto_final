`timescale 1ns/1ps

//====================================================
// PRUEBA DEL SISTEMA COMPLETO (3 MODOS)
//
// Usa tiempos reducidos (UART de 16 ciclos por bit,
// antirrebote de 20 ciclos, periodo de servo de 400 ciclos)
// para que la simulacion sea rapida. La logica es la misma.
//
//   iverilog -g2005 -o sim tb/braille_top_tb.v rtl/*.v && vvp sim
//====================================================

module braille_top_tb;

    localparam CPB    = 16;
    localparam DEB    = 20;
    localparam PERIOD = 400;
    localparam P_DOWN = 20;    // izquierda
    localparam P_UP   = 40;
    localparam R_DOWN = 35;    // derecha (espejo)
    localparam R_UP   = 15;

    reg        clk = 0;
    reg  [1:0] KEY = 2'b10;   // reset activo
    reg  [2:0] SW  = 3'd0;
    reg        UART_RX = 1'b1;
    wire       UART_TX;
    reg  [5:0] DOT_N  = 6'b111111;
    wire [5:0] SERVO;
    wire [9:0] LEDR;
    wire [7:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;

    always #10 clk = ~clk;   // 50 MHz

    braille_top #(
        .CLKS_PER_BIT  (CPB),
        .DEBOUNCE_COUNT(DEB),
        .DEB_WIDTH     (8),
        .SERVO_PERIOD  (PERIOD),
        .PULSE_DOWN_L  (P_DOWN),
        .PULSE_UP_L    (P_UP),
        .PULSE_DOWN_R  (R_DOWN),
        .PULSE_UP_R    (R_UP),
        .SERVO_WIDTH   (10),
        .FEEDBACK_DELAY(5000),
        .FB_WIDTH      (13)
    ) dut (
        .CLOCK_50(clk), .KEY(KEY), .SW(SW),
        .UART_RX(UART_RX), .UART_TX(UART_TX),
        .DOT_N(DOT_N),
        .SERVO(SERVO), .LEDR(LEDR),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5)
    );

    integer errors = 0;

    //====================================================
    // PC -> FPGA
    //====================================================

    task send_byte(input [7:0] b);
        integer i;
        begin
            UART_RX = 1'b0;  repeat (CPB) @(posedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                UART_RX = b[i]; repeat (CPB) @(posedge clk);
            end
            UART_RX = 1'b1;  repeat (CPB) @(posedge clk);
        end
    endtask

    // Envia una cadena (maximo 24 caracteres) seguida de '\n'
    task send_line(input [8*24-1:0] s);
        integer i;
        reg started;
        begin
            started = 0;
            for (i = 23; i >= 0; i = i - 1) begin
                if (s[i*8 +: 8] != 8'd0) started = 1;
                if (started) send_byte(s[i*8 +: 8]);
            end
            send_byte(8'h0A);
        end
    endtask


    //====================================================
    // FPGA -> PC: monitor que arma lineas
    //====================================================

    reg [8*16-1:0] lines [0:63];
    integer        n_lines = 0;
    integer        rd_ptr  = 0;
    reg [8*16-1:0] cur = 0;

    initial begin : MONITOR
        reg [7:0] b;
        integer i;
        forever begin
            @(negedge UART_TX);
            repeat (CPB/2) @(posedge clk);          // centro del START
            for (i = 0; i < 8; i = i + 1) begin
                repeat (CPB) @(posedge clk);
                b[i] = UART_TX;
            end
            repeat (CPB) @(posedge clk);             // STOP
            if (b == 8'h0A) begin
                lines[n_lines] = cur;
                n_lines = n_lines + 1;
                cur = 0;
            end
            else
                cur = {cur[8*15-1:0], b};
        end
    end

    task expect_line(input [8*16-1:0] exp);
        integer t;
        begin
            t = 0;
            while (n_lines <= rd_ptr && t < 20000) begin
                @(posedge clk); t = t + 1;
            end
            if (n_lines <= rd_ptr) begin
                $display("FALLA: se esperaba \"%0s\" y no llego nada", exp);
                errors = errors + 1;
            end
            else begin
                if (lines[rd_ptr] === exp)
                    $display("  ok   <- \"%0s\"", lines[rd_ptr]);
                else begin
                    $display("FALLA: se esperaba \"%0s\", llego \"%0s\"",
                             exp, lines[rd_ptr]);
                    errors = errors + 1;
                end
                rd_ptr = rd_ptr + 1;
            end
        end
    endtask

    task expect_silence;
        begin
            repeat (CPB * 40) @(posedge clk);
            if (n_lines > rd_ptr) begin
                $display("FALLA: mensaje inesperado \"%0s\"", lines[rd_ptr]);
                errors = errors + 1;
                rd_ptr = n_lines;
            end
            else
                $display("  ok   (sin respuesta, como se esperaba)");
        end
    endtask


    //====================================================
    // TECLADO
    //====================================================

    // Presiona los puntos de forma escalonada y con rebote,
    // luego los suelta tambien escalonados (como un dedo real).
    task press_chord(input [5:0] dots);
        integer i;
        begin
            for (i = 0; i < 6; i = i + 1) begin
                if (dots[i]) begin
                    DOT_N[i] = 1'b0; repeat (3) @(posedge clk);
                    DOT_N[i] = 1'b1; repeat (2) @(posedge clk);  // rebote
                    DOT_N[i] = 1'b0; repeat (DEB/2) @(posedge clk);
                end
            end
            repeat (DEB * 4) @(posedge clk);
            for (i = 0; i < 6; i = i + 1) begin
                if (dots[i]) begin
                    DOT_N[i] = 1'b1; repeat (2) @(posedge clk);
                    DOT_N[i] = 1'b0; repeat (2) @(posedge clk);  // rebote
                    DOT_N[i] = 1'b1; repeat (DEB/2) @(posedge clk);
                end
            end
            repeat (DEB * 4) @(posedge clk);
        end
    endtask

    task press_next;
        begin
            KEY[1] = 1'b0; repeat (DEB * 3) @(posedge clk);
            KEY[1] = 1'b1; repeat (DEB * 3) @(posedge clk);
        end
    endtask


    //====================================================
    // SERVOS
    //====================================================

    task expect_cell(input [5:0] exp);
        integer i, k;
        integer width [0:5];
        reg [5:0] got;
        begin
            // Esperar dos periodos para que el patron se registre
            @(posedge clk);
            while (dut.SERVO0.pwm_count != 0) @(posedge clk);
            @(posedge clk);
            while (dut.SERVO0.pwm_count != 0) @(posedge clk);
            for (i = 0; i < 6; i = i + 1) width[i] = 0;
            for (k = 0; k < PERIOD; k = k + 1) begin
                for (i = 0; i < 6; i = i + 1)
                    if (SERVO[i]) width[i] = width[i] + 1;
                @(posedge clk);
            end
            for (i = 0; i < 6; i = i + 1) begin
                got[i] = (i < 3) ? (width[i] == P_UP) : (width[i] == R_UP);
                if ((i < 3 && width[i] != P_UP && width[i] != P_DOWN) ||
                    (i >= 3 && width[i] != R_UP && width[i] != R_DOWN)) begin
                    $display("FALLA: ancho de pulso invalido en servo %0d: %0d", i, width[i]);
                    errors = errors + 1;
                end
            end
            if (got === exp)
                $display("  ok   celda = %b", got);
            else begin
                $display("FALLA: celda = %b, se esperaba %b", got, exp);
                errors = errors + 1;
            end
        end
    endtask


    // Espera una linea "T<c>" y devuelve la letra
    task get_target(output [7:0] c);
        integer t;
        begin
            t = 0;
            while (n_lines <= rd_ptr && t < 40000) begin
                @(posedge clk); t = t + 1;
            end
            if (n_lines <= rd_ptr || lines[rd_ptr][15:8] !== "T") begin
                $display("FALLA: se esperaba T<c>, llego \"%0s\"", lines[rd_ptr]);
                errors = errors + 1;
                c = "a";
            end
            else begin
                c = lines[rd_ptr][7:0];
                $display("  ok   <- \"%0s\"  (letra aleatoria de la FPGA)", lines[rd_ptr]);
            end
            if (n_lines > rd_ptr) rd_ptr = rd_ptr + 1;
            repeat (4) @(posedge clk);
        end
    endtask

    //====================================================
    // SECUENCIA DE PRUEBA
    //====================================================

    reg [7:0] tgt, tgt2;
    reg [5:0] pat, wrong;

    initial begin
        repeat (10) @(posedge clk);
        KEY = 2'b11;
        repeat (10) @(posedge clk);

        //------------------------------------------------
        $display("\n== REPOSO (SW = 00) ==");
        send_line("Q");        expect_line("MI");
        send_line("RHOLA");    expect_line("!M");     // no esta en lectura
        press_chord(6'b000001); expect_silence;
        press_next;             expect_silence;

        //------------------------------------------------
        $display("\n== A. MODO LECTURA (SW = 01) ==");
        SW[1:0] = 2'b01;       expect_line("MR");
        send_line("RCASA");
        expect_line("DC");
        expect_cell(6'b001001);           // c = puntos 1,4
        press_next;  expect_line("DA");  expect_cell(6'b000001);
        press_next;  expect_line("DS");  expect_cell(6'b001110);
        send_line("N"); expect_line("DA"); // NEXT por software
        press_next;  expect_line("E");   expect_cell(6'b000000);
        press_next;  expect_silence;      // sin palabra: nada
        send_line("R0123456789ABCDEFG");  // 17 caracteres
        expect_line("!L");
        send_line("Rhola");
        expect_line("Dh");
        send_line("S");                    // consulta no pierde la posicion
        expect_line("S0000");
        press_next;  expect_line("Do");
        press_chord(6'b000001); expect_silence;   // lectura ignora acordes

        //------------------------------------------------
        $display("\n== B. MODO ESCRITURA (SW = 10) ==");
        SW[1:0] = 2'b10;       expect_line("MW");
        expect_cell(6'b000000);
        send_line("Rhola");    expect_line("!M");
        press_chord(6'b000111); expect_line("Kl");   // l = 123
        press_chord(6'b001010); expect_line("Ki");   // i = 24
        press_chord(6'b000011); expect_line("Kb");   // b = 12
        press_chord(6'b010111); expect_line("Kr");   // r = 1235
        press_chord(6'b010101); expect_line("Ko");   // o = 135
        press_next;             expect_line("K ");   // espacio
        press_chord(6'b111011); expect_line({"K", 8'hF1}); // n tilde
        press_chord(6'b100000); expect_line("K?");   // solo punto 6: invalido
        press_chord(6'b000111);                       // l y d seguidas
        press_chord(6'b011001);
        expect_line("Kl");
        expect_line("Kd");

        //------------------------------------------------
        $display("\n== C. MODO PRACTICA (SW = 11), todo en la FPGA ==");
        SW[1:0] = 2'b11;       expect_line("MP");
        get_target(tgt);                              // primera letra
        pat = dut.CTRL0.lut_pattern;
        expect_cell(6'b000000);                       // SW2 = 0: sin pista
        press_chord(pat);       expect_line({"O", tgt, "0100"});   // acierto
        expect_cell(pat);                             // retroalimentacion
        press_chord(pat);       expect_silence;       // ignorado durante la pausa
        get_target(tgt2);                             // la FPGA avanza sola
        if (tgt2 == tgt) begin
            $display("FALLA: letra repetida"); errors = errors + 1;
        end
        pat = dut.CTRL0.lut_pattern;
        SW[2] = 1'b1;                                 // pista encendida
        expect_cell(pat);
        wrong = (tgt2 == "a") ? 6'b000011 : 6'b000001;  // b o a
        press_chord(wrong);
        expect_line({"X", (tgt2 == "a") ? "b" : "a", "0101"});    // error
        get_target(tgt);
        press_next;                                   // saltar letra
        get_target(tgt2);
        send_line("S");        expect_line("S0101");
        SW[2] = 1'b0;
        if (HEX2[6:0] !== 7'b1111001 || HEX0[6:0] !== 7'b1111001) begin
            $display("FALLA: displays de marcador"); errors = errors + 1;
        end else $display("  ok   HEX muestra 01 / 01");

        //------------------------------------------------
        $display("\n== CAMBIOS DE MODO Y ERRORES ==");
        SW[1:0] = 2'b00;       expect_line("MI");
        expect_cell(6'b000000);
        SW[1:0] = 2'b11;       expect_line("MP");     // sesion nueva
        get_target(tgt);
        send_line("S");        expect_line("S0000");  // marcador borrado
        SW[1:0] = 2'b01;       expect_line("MR");
        send_line("Q");        expect_line("MR");
        send_line("W");        expect_line("!U");     // el PC ya no cambia modos
        send_line("Pa");       expect_line("!U");
        UART_RX = 1'b1;
        send_byte(8'h0D); send_byte(8'h0A);           // lineas vacias
        expect_silence;

        //------------------------------------------------
        if (errors == 0)
            $display("\n*** TODAS LAS PRUEBAS PASARON ***\n");
        else
            $display("\n*** %0d FALLAS ***\n", errors);
        $finish;
    end

    initial begin
        #200_000_000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
