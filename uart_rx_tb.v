`timescale 1ns/1ps

module uart_rx_tb;

    //====================================================
    // PARAMETROS
    //====================================================

    parameter CLKS_PER_BIT = 5208;

    // Reloj de 50 MHz
    // T = 1 / 50 MHz = 20 ns
    parameter CLK_PERIOD = 20;

    // Duracion aproximada de cada bit UART
    parameter BIT_TIME = CLKS_PER_BIT * CLK_PERIOD;


    //====================================================
    // SEÑALES
    //====================================================

    reg        clk;
    reg        rst;
    reg        rx;

    wire [7:0] data_out;
    wire       data_ready;


    //====================================================
    // INSTANCIA DEL MODULO
    //====================================================

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data_out(data_out),
        .data_ready(data_ready)
    );


    //====================================================
    // GENERADOR DE RELOJ
    //====================================================

    initial begin

        clk = 1'b0;

        forever begin

            #(CLK_PERIOD / 2);
            clk = ~clk;

        end

    end


    //====================================================
    // TAREA PARA ENVIAR UN BYTE UART
    //====================================================

    task send_uart_byte;

        input [7:0] data;

        integer i;

        begin

            // -----------------------------------------
            // BIT START
            // -----------------------------------------

            rx = 1'b0;

            #(BIT_TIME);


            // -----------------------------------------
            // 8 BITS DE DATOS
            // UART envia LSB primero
            // -----------------------------------------

            for (i = 0; i < 8; i = i + 1) begin

                rx = data[i];

                #(BIT_TIME);

            end


            // -----------------------------------------
            // BIT STOP
            // -----------------------------------------

            rx = 1'b1;

            #(BIT_TIME);


            // UART regresa al estado de reposo
            rx = 1'b1;

        end

    endtask


    //====================================================
    // MONITOREO
    //====================================================

    always @(posedge clk) begin

        if (data_ready == 1'b1) begin

            $display("-----------------------------------");
            $display("Tiempo = %0t ns", $time);
            $display("Dato recibido = %h", data_out);
            $display("-----------------------------------");

        end

    end


    //====================================================
    // SIMULACION
    //====================================================

    initial begin

        // -----------------------------------------
        // VALORES INICIALES
        // -----------------------------------------

        rst = 1'b1;

        // UART en reposo
        rx = 1'b1;


        // -----------------------------------------
        // RESET
        // -----------------------------------------

        #100;

        rst = 1'b0;


        // Esperar antes de transmitir
        #(BIT_TIME);


        //==========================================
        // PRUEBA 1
        // A = 0x41
        //==========================================

        $display("");
        $display("Enviando A = 8'h41");

        send_uart_byte(8'h41);


        // Separacion entre bytes
        #(BIT_TIME * 2);


        //==========================================
        // PRUEBA 2
        // C = 0x43
        //==========================================

        $display("");
        $display("Enviando C = 8'h43");

        send_uart_byte(8'h43);


        #(BIT_TIME * 2);


        //==========================================
        // PRUEBA 3
        // START DEL PROTOCOLO = 0xAA
        //==========================================

        $display("");
        $display("Enviando START = 8'hAA");

        send_uart_byte(8'hAA);


        #(BIT_TIME * 2);


        //==========================================
        // FIN DE SIMULACION
        //==========================================

        $display("");
        $display("FIN DE LA SIMULACION");

        $stop;

    end

endmodule