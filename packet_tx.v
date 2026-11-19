
module packet_tx #(
    parameter MAX_DATA = 32
)(
    input wire clk,
    input wire rst,

    input wire packet_start,
    input wire [7:0] cmd_in,
    input wire [7:0] length_in,
    input wire [MAX_DATA*8-1:0] payload_in,

    input wire uart_busy,
    input wire uart_done,

    output reg [7:0] uart_data,
    output reg uart_start,

    output reg packet_busy,
    output reg packet_done,
    output reg packet_error
);

    //====================================================
    // PARAMETROS
    //====================================================

    localparam START_BYTE = 8'hAA;


    //====================================================
    // ESTADOS
    //====================================================

    localparam IDLE       = 4'd0;
    localparam SEND_START = 4'd1;
    localparam WAIT_START = 4'd2;
    localparam SEND_CMD   = 4'd3;
    localparam WAIT_CMD   = 4'd4;
    localparam SEND_LEN   = 4'd5;
    localparam WAIT_LEN   = 4'd6;
    localparam SEND_DATA  = 4'd7;
    localparam WAIT_DATA  = 4'd8;
    localparam SEND_CHECK = 4'd9;
    localparam WAIT_CHECK = 4'd10;
    localparam FINISH     = 4'd11;

    reg [3:0] state;


    //====================================================
    // REGISTROS INTERNOS
    //====================================================

    reg [7:0] cmd_reg;
    reg [7:0] length_reg;
    reg [7:0] data_index;
    reg [7:0] checksum;

    reg [MAX_DATA*8-1:0] payload_reg;


    //====================================================
    // MAQUINA DE ESTADOS
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state <= IDLE;

            cmd_reg <= 8'd0;
            length_reg <= 8'd0;
            data_index <= 8'd0;
            checksum <= 8'd0;

            payload_reg <= {(MAX_DATA*8){1'b0}};

            uart_data <= 8'd0;
            uart_start <= 1'b0;

            packet_busy <= 1'b0;
            packet_done <= 1'b0;
            packet_error <= 1'b0;

        end

        else begin

            uart_start <= 1'b0;
            packet_done <= 1'b0;
            packet_error <= 1'b0;


            case (state)

                //========================================
                // IDLE
                //========================================

                IDLE: begin

                    packet_busy <= 1'b0;

                    if (packet_start == 1'b1) begin

                        if (uart_busy || length_in > MAX_DATA) begin

                            packet_error <= 1'b1;

                        end

                        else begin

                            cmd_reg <= cmd_in;
                            length_reg <= length_in;
                            payload_reg <= payload_in;

                            data_index <= 8'd0;
                            checksum <= 8'd0;

                            packet_busy <= 1'b1;

                            state <= SEND_START;

                        end

                    end

                end


                //========================================
                // START
                //========================================

                SEND_START: begin

                    uart_data <= START_BYTE;
                    uart_start <= 1'b1;

                    state <= WAIT_START;

                end


                WAIT_START: begin

                    if (uart_done == 1'b1) begin

                        state <= SEND_CMD;

                    end

                end


                //========================================
                // CMD
                //========================================

                SEND_CMD: begin

                    uart_data <= cmd_reg;
                    uart_start <= 1'b1;

                    checksum <= cmd_reg;

                    state <= WAIT_CMD;

                end


                WAIT_CMD: begin

                    if (uart_done == 1'b1) begin

                        state <= SEND_LEN;

                    end

                end


                //========================================
                // LEN
                //========================================

                SEND_LEN: begin

                    uart_data <= length_reg;
                    uart_start <= 1'b1;

                    checksum <= checksum ^ length_reg;

                    state <= WAIT_LEN;

                end


                WAIT_LEN: begin

                    if (uart_done == 1'b1) begin

                        if (length_reg == 8'd0) begin

                            state <= SEND_CHECK;

                        end

                        else begin

                            state <= SEND_DATA;

                        end

                    end

                end


                //========================================
                // DATA
                //========================================

                SEND_DATA: begin

                    uart_data <= payload_reg[data_index*8 +: 8];
                    uart_start <= 1'b1;

                    checksum <= checksum ^
                                payload_reg[data_index*8 +: 8];

                    state <= WAIT_DATA;

                end


                WAIT_DATA: begin

                    if (uart_done == 1'b1) begin

                        if (data_index == length_reg - 1'b1) begin

                            state <= SEND_CHECK;

                        end

                        else begin

                            data_index <= data_index + 1'b1;

                            state <= SEND_DATA;

                        end

                    end

                end


                //========================================
                // CHECK
                //========================================

                SEND_CHECK: begin

                    uart_data <= checksum;
                    uart_start <= 1'b1;

                    state <= WAIT_CHECK;

                end


                WAIT_CHECK: begin

                    if (uart_done == 1'b1) begin

                        state <= FINISH;

                    end

                end


                //========================================
                // FINISH
                //========================================

                FINISH: begin

                    packet_busy <= 1'b0;
                    packet_done <= 1'b1;

                    state <= IDLE;

                end


                //========================================
                // DEFAULT
                //========================================

                default: begin

                    state <= IDLE;
                    packet_busy <= 1'b0;

                end

            endcase

        end

    end

endmodule

