
module exercise_buffer #(
    parameter MAX_DATA = 32
)(
    input wire clk,
    input wire rst,

    input wire load,
    input wire [7:0] length_in,
    input wire [MAX_DATA*8-1:0] payload_in,

    input wire [4:0] index_in,

    output reg [7:0] char_out,
    output reg [5:0] buffer_length,

    output reg buffer_loaded,
    output reg char_valid,
    output reg load_error
);

    //====================================================
    // REGISTRO DEL BUFFER
    //====================================================

    reg [MAX_DATA*8-1:0] text_buffer;


    //====================================================
    // ALMACENAMIENTO DE TEXTO
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            text_buffer <= 0;
            buffer_length <= 0;
            buffer_loaded <= 1'b0;
            load_error <= 1'b0;

        end

        else begin

            load_error <= 1'b0;

            if (load) begin

                if (length_in <= MAX_DATA) begin

                    text_buffer <= payload_in;
                    buffer_length <= length_in[5:0];
                    buffer_loaded <= 1'b1;

                end

                else begin

                    text_buffer <= 0;
                    buffer_length <= 0;
                    buffer_loaded <= 1'b0;
                    load_error <= 1'b1;

                end

            end

        end

    end


    //====================================================
    // SELECCION DE CARACTER
    //====================================================

    always @(*) begin

        char_out = 8'h00;
        char_valid = 1'b0;

        if (buffer_loaded && index_in < buffer_length) begin

            char_out = text_buffer[index_in*8 +: 8];
            char_valid = 1'b1;

        end

    end

endmodule
