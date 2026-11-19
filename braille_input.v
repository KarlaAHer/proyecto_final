
module braille_input(

    input wire clk,
    input wire rst,

    input wire [5:0] dots_pressed,
    input wire next_pulse,

    output reg [5:0] braille_out,
    output reg braille_valid

);

    //====================================================
    // CAPTURA DE CELDA BRAILLE
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            braille_out <= 6'b000000;
            braille_valid <= 1'b0;

        end

        else begin

            braille_valid <= 1'b0;

            if (next_pulse) begin

                braille_out <= dots_pressed;
                braille_valid <= 1'b1;

            end

        end

    end

endmodule
