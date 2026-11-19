
`timescale 1ns/1ps

module packet_parser_tb;

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

    reg [7:0] rx_data;
    reg rx_valid;

    wire [7:0] cmd_out;
    wire [7:0] length_out;

    wire [MAX_DATA*8-1:0] payload_out;

    wire packet_valid;
    wire packet_error;

    integer error_count;


    //====================================================
    // INSTANCIA DEL MODULO
    //====================================================

    packet_parser #(
        .MAX_DATA(MAX_DATA)
    ) uut (
        .clk(clk),
        .rst(rst),

        .rx_data(rx_data),
        .rx_valid(rx_valid),

        .cmd_out(cmd_out),
        .length_out(length_out),
        .payload_out(payload_out),

        .packet_valid(packet_valid),
        .packet_error(packet_error)
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
    // TAREA PARA ENVIAR UN BYTE
    //====================================================

    task send_byte;

        input [7:0] value;

        begin

            @(negedge clk);

            rx_data = value;
            rx_valid = 1'b1;

            @(negedge clk);

            rx_valid = 1'b0;
            rx_data = 8'd0;

        end

    endtask


    //====================================================
    // SIMULACION
    //====================================================

    initial begin

        // VALORES INICIALES

        rst = 1'b1;

        rx_data = 8'd0;
        rx_valid = 1'b0;

        error_count = 0;


        // RESET

        #100;

        rst = 1'b0;


        //============================================
        // PRUEBA 1: PAQUETE CORRECTO
        // CMD = 03
        // LEN = 04
        // DATA = CASA
        // CHECK = 17
        //============================================

        $display("");
        $display("PRUEBA 1: PAQUETE CORRECTO");

        send_byte(8'hAA);
        send_byte(8'h03);
        send_byte(8'h04);

        send_byte(8'h43); // C
        send_byte(8'h41); // A
        send_byte(8'h53); // S
        send_byte(8'h41); // A

        send_byte(8'h17); // CHECK


        if (packet_valid == 1'b1) begin

            $display("PAQUETE VALIDO");

            $display("CMD = %h", cmd_out);
            $display("LEN = %d", length_out);

            $display("DATA[0] = %h", payload_out[7:0]);
            $display("DATA[1] = %h", payload_out[15:8]);
            $display("DATA[2] = %h", payload_out[23:16]);
            $display("DATA[3] = %h", payload_out[31:24]);

        end
        else begin

            $display("ERROR: PAQUETE NO RECONOCIDO");

            error_count = error_count + 1;

        end


        // VERIFICAR DATOS

        if (cmd_out !== 8'h03 ||
            length_out !== 8'd4 ||
            payload_out[7:0] !== 8'h43 ||
            payload_out[15:8] !== 8'h41 ||
            payload_out[23:16] !== 8'h53 ||
            payload_out[31:24] !== 8'h41) begin

            $display("ERROR: DATOS INCORRECTOS");

            error_count = error_count + 1;

        end


        //============================================
        // PRUEBA 2: CHECKSUM INCORRECTO
        //============================================

        $display("");
        $display("PRUEBA 2: CHECKSUM INCORRECTO");

        send_byte(8'hAA);
        send_byte(8'h03);
        send_byte(8'h04);

        send_byte(8'h43);
        send_byte(8'h41);
        send_byte(8'h53);
        send_byte(8'h41);

        send_byte(8'h00); // CHECK INCORRECTO


        if (packet_error == 1'b1) begin

            $display("ERROR DETECTADO CORRECTAMENTE");

        end
        else begin

            $display("ERROR: NO DETECTO EL CHECKSUM");

            error_count = error_count + 1;

        end


        //============================================
        // PRUEBA 3: PAQUETE SIN DATOS
        // CMD = 05
        // LEN = 00
        // CHECK = 05
        //============================================

        $display("");
        $display("PRUEBA 3: PAQUETE SIN DATOS");

        send_byte(8'hAA);
        send_byte(8'h05);
        send_byte(8'h00);
        send_byte(8'h05);


        if (packet_valid == 1'b1 &&
            cmd_out == 8'h05 &&
            length_out == 8'd0) begin

            $display("PAQUETE SIN DATOS VALIDO");

        end
        else begin

            $display("ERROR EN PAQUETE SIN DATOS");

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

        $stop;

    end

endmodule
