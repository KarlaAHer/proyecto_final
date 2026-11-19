
`timescale 1ns/1ps

module exercise_buffer_tb;

    //====================================================
    // PARAMETROS
    //====================================================

    parameter MAX_DATA = 32;
    parameter CLK_PERIOD = 20;


    //====================================================
    // SEÑALES
    //====================================================

    reg clk;
    reg rst;

    reg load;
    reg [7:0] length_in;
    reg [MAX_DATA*8-1:0] payload_in;

    reg [4:0] index_in;

    wire [7:0] char_out;
    wire [5:0] buffer_length;

    wire buffer_loaded;
    wire char_valid;
    wire load_error;

    integer error_count;


    //====================================================
    // INSTANCIA DEL MODULO
    //====================================================

    exercise_buffer #(
        .MAX_DATA(MAX_DATA)
    ) uut (
        .clk(clk),
        .rst(rst),

        .load(load),
        .length_in(length_in),
        .payload_in(payload_in),

        .index_in(index_in),

        .char_out(char_out),
        .buffer_length(buffer_length),

        .buffer_loaded(buffer_loaded),
        .char_valid(char_valid),
        .load_error(load_error)
    );


    //====================================================
    // GENERADOR DE RELOJ
    //====================================================

    initial begin

        clk = 1'b0;

        forever begin

            #(CLK_PERIOD/2);
            clk = ~clk;

        end

    end


    //====================================================
    // TAREA PARA VERIFICAR CARACTERES
    //====================================================

    task check_char;

        input [4:0] index;
        input [7:0] expected;

        begin

            @(negedge clk);

            index_in = index;

            #1;

            if (char_valid && char_out == expected) begin

                $display(
                    "INDEX %0d CORRECTO: %h",
                    index,
                    char_out
                );

            end

            else begin

                $display(
                    "ERROR INDEX %0d: esperado %h, recibido %h",
                    index,
                    expected,
                    char_out
                );

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

        load = 1'b0;

        length_in = 8'd0;
        payload_in = 0;

        index_in = 5'd0;

        error_count = 0;


        // RESET

        #100;

        rst = 1'b0;

        repeat(2) @(negedge clk);


        //============================================
        // PRUEBA 1: CARGAR CASA
        //============================================

        $display("");
        $display("PRUEBA 1: CARGAR CASA");


        length_in = 8'd4;

        payload_in = 0;

        payload_in[7:0]   = 8'h43;
        payload_in[15:8]  = 8'h41;
        payload_in[23:16] = 8'h53;
        payload_in[31:24] = 8'h41;


        load = 1'b1;

        @(negedge clk);

        load = 1'b0;

        #1;


        if (buffer_loaded && buffer_length == 6'd4) begin

            $display("BUFFER CARGADO CORRECTAMENTE");

        end

        else begin

            $display("ERROR AL CARGAR BUFFER");

            error_count = error_count + 1;

        end


        //============================================
        // PRUEBA 2: SELECCIONAR CARACTERES
        //============================================

        $display("");
        $display("PRUEBA 2: LEER CASA");


        check_char(5'd0, 8'h43);
        check_char(5'd1, 8'h41);
        check_char(5'd2, 8'h53);
        check_char(5'd3, 8'h41);


        //============================================
        // PRUEBA 3: INDICE FUERA DE RANGO
        //============================================

        $display("");
        $display("PRUEBA 3: INDICE FUERA DE RANGO");


        @(negedge clk);

        index_in = 5'd4;

        #1;


        if (char_valid == 1'b0) begin

            $display("INDICE INVALIDO DETECTADO");

        end

        else begin

            $display("ERROR: INDICE INVALIDO ACEPTADO");

            error_count = error_count + 1;

        end


        //============================================
        // PRUEBA 4: LONGITUD EXCEDIDA
        //============================================

        $display("");
        $display("PRUEBA 4: LONGITUD EXCEDIDA");


        @(negedge clk);

        length_in = 8'd33;

        load = 1'b1;

        @(negedge clk);

        load = 1'b0;

        #1;


        if (load_error && !buffer_loaded) begin

            $display("LONGITUD EXCEDIDA DETECTADA");

        end

        else begin

            $display("ERROR: LONGITUD EXCEDIDA ACEPTADA");

            error_count = error_count + 1;

        end


        //============================================
        // RESULTADO FINAL
        //============================================

        $display("");
        $display("================================");

        if (error_count == 0) begin

            $display("TODAS LAS PRUEBAS EXITOSAS");

        end

        else begin

            $display("ERRORES ENCONTRADOS: %0d",
                     error_count);

        end

        $display("================================");

        #100;

        $stop;

    end

endmodule
