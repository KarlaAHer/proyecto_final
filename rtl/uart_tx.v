module uart_tx (
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] data_in,
    input  wire       tx_start,

    output reg        tx,
    output reg        tx_busy,
    output reg        tx_done
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
    reg [7:0]  tx_data;


    //====================================================
    // MAQUINA DE ESTADOS UART TX
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state     <= IDLE;

            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            tx_done   <= 1'b0;

            clk_count <= 13'd0;
            bit_index <= 3'd0;

            tx_data   <= 8'd0;

        end
        else begin

            // tx_done solo se activa durante un ciclo
            tx_done <= 1'b0;


            case (state)

                //========================================
                // IDLE
                //========================================

                IDLE: begin

                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;

                    clk_count <= 13'd0;
                    bit_index <= 3'd0;


                    // Si se solicita una transmision
                    if (tx_start == 1'b1) begin

                        // Guardar el byte
                        tx_data <= data_in;

                        // Indicar que UART esta ocupada
                        tx_busy <= 1'b1;

                        // Comenzar transmision
                        state <= START;

                    end

                end


                //========================================
                // START
                //========================================

                START: begin

                    tx_busy <= 1'b1;

                    // Bit START siempre es 0
                    tx <= 1'b0;


                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 13'd0;

                        state <= DATA;

                    end
                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                //========================================
                // DATA
                //========================================

                DATA: begin

                    tx_busy <= 1'b1;

                    // UART transmite primero el LSB
                    tx <= tx_data[bit_index];


                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 13'd0;


                        // Si ya se transmitieron
                        // los 8 bits
                        if (bit_index == 3'd7) begin

                            bit_index <= 3'd0;

                            state <= STOP;

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

                    tx_busy <= 1'b1;

                    // Bit STOP siempre es 1
                    tx <= 1'b1;


                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 13'd0;

                        tx_busy <= 1'b0;

                        // Indicar fin de transmision
                        tx_done <= 1'b1;

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

                    tx      <= 1'b1;
                    tx_busy <= 1'b0;

                end

            endcase

        end

    end

endmodule
