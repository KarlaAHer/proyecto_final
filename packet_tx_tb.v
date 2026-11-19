
`timescale 1ns/1ps

module packet_tx_tb;

    //====================================================
    // PARAMETROS
    //====================================================

    parameter CLKS_PER_BIT = 5208;
    parameter MAX_DATA = 32;
    parameter CLK_PERIOD = 20;


    //====================================================
    // SEÑALES DE ENTRADA
    //====================================================

    reg clk;
    reg rst;

    reg packet_start;
    reg [7:0] cmd_in;
    reg [7:0] length_in;

    reg [MAX_DATA*8-1:0] payload_in;


    //====================================================
    // SEÑALES INTERNAS
    //====================================================

    wire [7:0] uart_data;
    wire uart_start;

    wire uart_busy;
    wire uart_done;

    wire tx_line;

    wire [7:0] rx_data;
    wire rx_valid;


    //====================================================
    // SALIDAS DEL PARSER
    //====================================================

    wire [7:0] cmd_out;
    wire [7:0] length_out;

    wire [MAX_DATA*8-1:0] payload_out;

    wire packet_valid;
    wire packet_error;


    //====================================================
    // SALIDAS PACKET TX
    //====================================================

    wire packet_busy;
    wire packet_done;
    wire packet_tx_error;

    integer error_count;

    reg done_seen;


    //====================================================
    // INSTANCIA PACKET TX
    //====================================================

    packet_tx #(
        .MAX_DATA(MAX_DATA)
    ) uut_tx (
        .clk(clk),
        .rst(rst),

        .packet_start(packet_start),
        .cmd_in(cmd_in),
        .length_in(length_in),
        .payload_in(payload_in),

        .uart_busy(uart_busy),
        .uart_done(uart_done),

        .uart_data(uart_data),
        .uart_start(uart_start),

        .packet_busy(packet_busy),
        .packet_done(packet_done),
        .packet_error(packet_tx_error)
    );


    //====================================================
    // INSTANCIA UART TX
    //====================================================

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uut_uart_tx (
        .clk(clk),
        .rst(rst),

        .data_in(uart_data),
        .tx_start(uart_start),

        .tx(tx_line),
        .tx_busy(uart_busy),
        .tx_done(uart_done)
    );


    //====================================================
    // INSTANCIA UART RX
    //====================================================

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uut_uart_rx (
        .clk(clk),
        .rst(rst),

        .rx(tx_line),

        .data_out(rx_data),
        .data_ready(rx_valid)
    );


    //====================================================
    // INSTANCIA PACKET PARSER
    //====================================================

    packet_parser #(
        .MAX_DATA(MAX_DATA)
    ) uut_parser (
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
    // MONITOREO
    //====================================================

    always @(posedge clk) begin

        if (packet_done)
            done_seen <= 1'b1;

    end


    //====================================================
    // SIMULACION
    //====================================================

    initial begin

        // VALORES INICIALES

        rst = 1'b1;

        packet_start = 1'b0;

        cmd_in = 8'd0;
        length_in = 8'd0;

        payload_in = 0;

        error_count = 0;
        done_seen = 1'b0;


        // RESET

        #100;

        rst = 1'b0;

        repeat(20) @(posedge clk);


        //============================================
        // PRUEBA 1: TRANSMITIR CASA
        //============================================

        $display("");
        $display("PRUEBA 1: TRANSMITIENDO CASA");


        @(negedge clk);

        cmd_in = 8'h03;
        length_in = 8'd4;

        payload_in = 0;

        payload_in[7:0]   = 8'h43;
        payload_in[15:8]  = 8'h41;
        payload_in[23:16] = 8'h53;
        payload_in[31:24] = 8'h41;

        packet_start = 1'b1;

        @(negedge clk);

        packet_start = 1'b0;


        // ESPERAR PAQUETE RECIBIDO

        wait(packet_valid == 1'b1);

        #1;


        if (cmd_out == 8'h03 &&
            length_out == 8'd4 &&
            payload_out[7:0] == 8'h43 &&
            payload_out[15:8] == 8'h41 &&
            payload_out[23:16] == 8'h53 &&
            payload_out[31:24] == 8'h41) begin

            $display("CASA RECIBIDO CORRECTAMENTE");

        end

        else begin

            $display("ERROR EN PAQUETE CASA");

            error_count = error_count + 1;

        end


        wait(done_seen == 1'b1);

        repeat(20) @(posedge clk);


        //============================================
        // PRUEBA 2: PAQUETE SIN DATOS
        //============================================

        $display("");
        $display("PRUEBA 2: PAQUETE SIN DATOS");


        @(negedge clk);

        done_seen = 1'b0;

        cmd_in = 8'h05;
        length_in = 8'd0;

        payload_in = 0;

        packet_start = 1'b1;

        @(negedge clk);

        packet_start = 1'b0;


        wait(packet_valid == 1'b1);

        #1;


        if (cmd_out == 8'h05 &&
            length_out == 8'd0) begin

            $display("PAQUETE SIN DATOS CORRECTO");

        end

        else begin

            $display("ERROR EN PAQUETE SIN DATOS");

            error_count = error_count + 1;

        end


        wait(done_seen == 1'b1);


        //============================================
        // RESULTADO FINAL
        //============================================

        $display("");
        $display("================================");

        if (error_count == 0) begin

            $display("TODAS LAS PRUEBAS EXITOSAS");

        end

        else begin

            $display("ERRORES: %0d", error_count);

        end

        $display("================================");

        #100;

        $stop;

    end

endmodule
