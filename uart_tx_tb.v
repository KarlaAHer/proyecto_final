`timescale 1ns/1ps

module uart_tx_tb;

    //====================================================
    // PARAMETROS
    //====================================================

    parameter CLKS_PER_BIT = 5208;

    // Reloj de 50 MHz
    // T = 20 ns
    parameter CLK_PERIOD = 20;

    // Duracion de un bit UART
    parameter BIT_TIME = CLKS_PER_BIT * CLK_PERIOD;


    //====================================================
    // SEÑALES
    //====================================================

    reg        clk;
    reg        rst;
    reg  [7:0] data_in;
    reg        tx_start;

    wire       tx;
    wire       tx_busy;
    wire       tx_done;

    integer error_count;


    //====================================================
    // INSTANCIA DEL MODULO UART TX
    //====================================================

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uut (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .tx_start(tx_start),
        .tx(tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done)
    );


    //====================================================
    // GENERADOR DE RELOJ DE 50 MHz
    //====================================================

    initial begin

        clk = 1'b0;

        forever begin

            #(CLK_PERIOD / 2);
            clk = ~clk;

        end

    end


    //====================================================
    // TAREA PARA TRANSMITIR Y VERIFICAR UN BYTE
    //====================================================

    task send_and_check;

        input [7:0] expected_data;

        integer i;

        begin

            // Esperar a que UART este libre
            wait(tx_busy == 1'b0);


            // -----------------------------------------
            // CARGAR BYTE
            // -----------------------------------------

            data_in = expected_data;

            tx_start = 1'b1;

            @(posedge clk);

            #1;

            tx_start = 1'b0;


            // -----------------------------------------
            // ESPERAR BIT START
            // -----------------------------------------

            wait(tx == 1'b0);


            // Ir al centro del bit START
            #(BIT_TIME / 2);


            if (tx == 1'b0) begin

                $display("START correcto");

            end
            else begin

                $display("ERROR en START");

                error_count = error_count + 1;

            end


            // -----------------------------------------
            // VERIFICAR LOS 8 BITS
            // -----------------------------------------

            for (i = 0; i < 8; i = i + 1) begin

                // Avanzar al centro del siguiente bit
                #(BIT_TIME);

                if (tx == expected_data[i]) begin

                    $display(
                        "Bit %0d correcto = %b",
                        i,
                        tx
                    );

                end
                else begin

                    $display(
                        "ERROR Bit %0d: esperado %b, recibido %b",
                        i,
                        expected_data[i],
                        tx
                    );

                    error_count = error_count + 1;

                end

            end


            // -----------------------------------------
            // VERIFICAR BIT STOP
            // -----------------------------------------

            #(BIT_TIME);

            if (tx == 1'b1) begin

                $display("STOP correcto");

            end
            else begin

                $display("ERROR en STOP");

                error_count = error_count + 1;

            end


            // Esperar a que termine la transmision
            wait(tx_done == 1'b1);

            @(posedge clk);


            $display("-----------------------------------");

        end

    endtask


    //====================================================
    // SIMULACION
    //====================================================

    initial begin

        // -----------------------------------------
        // VALORES INICIALES
        // -----------------------------------------

        rst         = 1'b1;
        data_in     = 8'd0;
        tx_start    = 1'b0;
        error_count = 0;


        // -----------------------------------------
        // RESET
        // -----------------------------------------

        #100;

        rst = 1'b0;


        #(BIT_TIME);


        //==========================================
        // PRUEBA 1
        // A = 0x41
        //==========================================

        $display("");
        $display("-----------------------------------");
        $display("Transmitiendo A = 8'h41");

        send_and_check(8'h41);


        #(BIT_TIME * 2);


        //==========================================
        // PRUEBA 2
        // C = 0x43
        //==========================================

        $display("");
        $display("-----------------------------------");
        $display("Transmitiendo C = 8'h43");

        send_and_check(8'h43);


        #(BIT_TIME * 2);


        //==========================================
        // PRUEBA 3
        // START DEL PROTOCOLO = 0xAA
        //==========================================

        $display("");
        $display("-----------------------------------");
        $display("Transmitiendo START = 8'hAA");

        send_and_check(8'hAA);


        #(BIT_TIME * 2);


        //==========================================
        // RESULTADO FINAL
        //==========================================

        $display("");
        $display("===================================");

        if (error_count == 0) begin

            $display("PRUEBA COMPLETADA CORRECTAMENTE");

        end
        else begin

            $display("SE DETECTARON %0d ERRORES",
                     error_count);

        end

        $display("===================================");


        $stop;

    end

endmodule