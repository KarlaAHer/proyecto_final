
module packet_parser #(
    parameter MAX_DATA = 32
)(
    input wire clk,
    input wire rst,

    input wire [7:0] rx_data,
    input wire rx_valid,

    output reg [7:0] cmd_out,
    output reg [7:0] length_out,
    output reg [MAX_DATA*8-1:0] payload_out,

    output reg packet_valid,
    output reg packet_error
);

    //====================================================
    // PARAMETROS
    //====================================================

    localparam START_BYTE = 8'hAA;


    //====================================================
    // ESTADOS
    //====================================================

    localparam IDLE  = 3'b000;
    localparam CMD   = 3'b001;
    localparam LEN   = 3'b010;
    localparam DATA  = 3'b011;
    localparam CHECK = 3'b100;

    reg [2:0] state;


    //====================================================
    // REGISTROS INTERNOS
    //====================================================

    reg [7:0] byte_count;
    reg [7:0] checksum;


    //====================================================
    // MAQUINA DE ESTADOS
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            state        <= IDLE;

            cmd_out      <= 8'd0;
            length_out   <= 8'd0;
            payload_out  <= {(MAX_DATA*8){1'b0}};

            byte_count   <= 8'd0;
            checksum     <= 8'd0;

            packet_valid <= 1'b0;
            packet_error <= 1'b0;

        end

        else begin

            packet_valid <= 1'b0;
            packet_error <= 1'b0;


            if (rx_valid) begin

                case (state)

                    //====================================
                    // IDLE: BUSCAR START
                    //====================================

                    IDLE: begin

                        if (rx_data == START_BYTE) begin

                            state <= CMD;

                            payload_out <= {(MAX_DATA*8){1'b0}};

                            byte_count <= 8'd0;
                            checksum <= 8'd0;

                        end

                    end


                    //====================================
                    // CMD: RECIBIR COMANDO
                    //====================================

                    CMD: begin

                        cmd_out <= rx_data;

                        checksum <= rx_data;

                        state <= LEN;

                    end


                    //====================================
                    // LEN: RECIBIR LONGITUD
                    //====================================

                    LEN: begin

                        length_out <= rx_data;

                        checksum <= checksum ^ rx_data;

                        byte_count <= 8'd0;

                        if (rx_data > MAX_DATA) begin

                            packet_error <= 1'b1;

                            state <= IDLE;

                        end

                        else if (rx_data == 8'd0) begin

                            state <= CHECK;

                        end

                        else begin

                            state <= DATA;

                        end

                    end


                    //====================================
                    // DATA: RECIBIR INFORMACION
                    //====================================

                    DATA: begin

                        payload_out[byte_count*8 +: 8] <= rx_data;

                        checksum <= checksum ^ rx_data;

                        if (byte_count == length_out - 1'b1) begin

                            byte_count <= 8'd0;

                            state <= CHECK;

                        end

                        else begin

                            byte_count <= byte_count + 1'b1;

                        end

                    end


                    //====================================
                    // CHECK: VALIDAR PAQUETE
                    //====================================

                    CHECK: begin

                        if (rx_data == checksum) begin

                            packet_valid <= 1'b1;

                        end

                        else begin

                            packet_error <= 1'b1;

                        end

                        state <= IDLE;

                    end


                    //====================================
                    // DEFAULT
                    //====================================

                    default: begin

                        state <= IDLE;

                    end

                endcase

            end

        end

    end

endmodule
