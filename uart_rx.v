module uart_rx (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,

    output reg  [7:0] data_out,
    output reg        data_ready
);

    //====================================================
    // PARAMETROS
    //====================================================

    parameter CLKS_PER_BIT = 5208;


    //====================================================
    // ESTADOS
    //====================================================

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state;


    //====================================================
    // REGISTROS INTERNOS
    //====================================================

    reg [12:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_data;


    //====================================================
    // SINCRONIZACION DE RX
    //====================================================

    reg rx_sync_1;
    reg rx_sync_2;

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;

        end
        else begin

            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;

        end

    end


    //====================================================
    // MAQUINA DE ESTADOS UART RX
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state      <= IDLE;

            clk_count  <= 13'd0;
            bit_index  <= 3'd0;

            rx_data    <= 8'd0;
            data_out   <= 8'd0;

            data_ready <= 1'b0;

        end
        else begin

            // Se activa solamente un ciclo
            data_ready <= 1'b0;


            case (state)

                //========================================
                // IDLE
                //========================================

                IDLE: begin

                    clk_count <= 13'd0;
                    bit_index <= 3'd0;

                    // UART esta normalmente en 1.
                    // Si baja a 0 comienza START.

                    if (rx_sync_2 == 1'b0) begin

                        state <= START;

                    end

                end


                //========================================
                // START
                //========================================

                START: begin

                    // Verificar el bit START
                    // aproximadamente en su centro.

                    if (clk_count == (CLKS_PER_BIT / 2) - 1) begin

                        clk_count <= 13'd0;

                        if (rx_sync_2 == 1'b0) begin

                            state <= DATA;

                        end
                        else begin

                            // Falso START
                            state <= IDLE;

                        end

                    end
                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                //========================================
                // DATA
                //========================================

                DATA: begin

                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 13'd0;

                        // UART transmite LSB primero
                        rx_data[bit_index] <= rx_sync_2;


                        if (bit_index == 3'd7) begin

                            bit_index <= 3'd0;
                            state     <= STOP;

                        end
                        else begin

                            bit_index <= bit_index + 1'b1;

                        end

                    end
                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                //========================================
                // STOP
                //========================================

                STOP: begin

                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 13'd0;

                        // STOP debe ser 1
                        if (rx_sync_2 == 1'b1) begin

                            data_out   <= rx_data;
                            data_ready <= 1'b1;

                        end

                        state <= IDLE;

                    end
                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                //========================================
                // DEFAULT
                //========================================

                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule