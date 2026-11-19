
`timescale 1ns/1ps

module braille_input_tb;

    //====================================================
    // SEÑALES
    //====================================================

    reg clk;
    reg rst;

    reg [5:0] dots_pressed;
    reg next_pulse;

    wire [5:0] braille_out;
    wire braille_valid;

    integer error_count;


    //====================================================
    // INSTANCIA DEL MODULO
    //====================================================

    braille_input uut (
        .clk(clk),
        .rst(rst),
        .dots_pressed(dots_pressed),
        .next_pulse(next_pulse),
        .braille_out(braille_out),
        .braille_valid(braille_valid)
    );


    //====================================================
    // GENERADOR DE RELOJ
    //====================================================

    initial begin

        clk = 0;

        forever #10 clk = ~clk;

    end


    //====================================================
    // TAREA PARA PROBAR CAPTURA
    //====================================================

    task check_capture;

        input [5:0] pattern;

        begin

            @(negedge clk);

            dots_pressed = pattern;
            next_pulse = 1'b1;

            @(posedge clk);
            #1;

            if (braille_out === pattern && braille_valid === 1'b1) begin

                $display("CAPTURA CORRECTA: %b", braille_out);

            end

            else begin

                $display("ERROR EN CAPTURA: %b", braille_out);

                error_count = error_count + 1;

            end

            @(negedge clk);

            next_pulse = 1'b0;

            @(posedge clk);
            #1;

            if (braille_valid === 1'b0) begin

                $display("PULSO DE UN CICLO CORRECTO");

            end

            else begin

                $display("ERROR: PULSO REPETIDO");

                error_count = error_count + 1;

            end

        end

    endtask


    //====================================================
    // SIMULACION
    //====================================================

    initial begin

        // VALORES INICIALES

        rst = 1'b1;

        dots_pressed = 6'b000000;
        next_pulse = 1'b0;

        error_count = 0;


        // RESET

        #40;

        rst = 1'b0;

        repeat(2) @(negedge clk);


        //============================================
        // PRUEBA 1: SIN NEXT
        //============================================

        $display("");
        $display("PRUEBA 1: ESPERAR NEXT");

        dots_pressed = 6'b100000;

        repeat(3) @(posedge clk);

        #1;

        if (braille_out == 6'b000000 && !braille_valid) begin

            $display("CORRECTO: SIN CAPTURA");

        end

        else begin

            $display("ERROR: CAPTURA SIN NEXT");

            error_count = error_count + 1;

        end


        //============================================
        // PRUEBA 2: CAPTURAR A
        //============================================

        $display("");
        $display("PRUEBA 2: CAPTURAR A");

        check_capture(6'b100000);


        //============================================
        // PRUEBA 3: CONSERVAR CELDA
        //============================================

        $display("");
        $display("PRUEBA 3: CONSERVAR CELDA");

        dots_pressed = 6'b110000;

        repeat(3) @(posedge clk);

        #1;

        if (braille_out == 6'b100000 && !braille_valid) begin

            $display("CORRECTO: CELDA CONSERVADA");

        end

        else begin

            $display("ERROR EN RETENCION");

            error_count = error_count + 1;

        end


        //============================================
        // PRUEBA 4: CAPTURAR C
        //============================================

        $display("");
        $display("PRUEBA 4: CAPTURAR C");

        check_capture(6'b110000);


        //============================================
        // PRUEBA 5: CAPTURAR ESPACIO
        //============================================

        $display("");
        $display("PRUEBA 5: CAPTURAR ESPACIO");

        check_capture(6'b000000);


        //============================================
        // RESULTADO FINAL
        //============================================

        $display("");
        $display("================================");

        if (error_count == 0)

            $display("TODAS LAS PRUEBAS EXITOSAS");

        else

            $display("ERRORES: %0d", error_count);

        $display("================================");

        #50;

        $stop;

    end

endmodule
