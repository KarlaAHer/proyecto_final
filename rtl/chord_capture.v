//====================================================
// CAPTURA DE ACORDE BRAILLE (6 BOTONES)
//
// Los dedos nunca presionan todos los botones en el mismo
// instante. Por eso:
//   1) mientras cualquier boton este presionado se acumula
//      (OR) todo lo que se haya presionado,
//   2) cuando TODOS se sueltan se entrega el patron completo
//      con un pulso chord_valid de un ciclo.
//
// La entrada dots_pressed ya debe venir sin rebote
// (button_conditioner), por lo que la liberacion es limpia.
//====================================================

module chord_capture (
    input  wire       clk,
    input  wire       rst,
    input  wire [5:0] dots_pressed,   // 1 = boton presionado (sin rebote)

    output reg  [5:0] chord,          // patron capturado
    output reg        chord_valid     // pulso de 1 ciclo
);

    reg [5:0] acc;

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            acc         <= 6'b000000;
            chord       <= 6'b000000;
            chord_valid <= 1'b0;
        end

        else begin

            chord_valid <= 1'b0;

            if (dots_pressed != 6'b000000) begin
                // Algun boton presionado: acumular
                acc <= acc | dots_pressed;
            end

            else if (acc != 6'b000000) begin
                // Todos sueltos: confirmar el caracter
                chord       <= acc;
                chord_valid <= 1'b1;
                acc         <= 6'b000000;
            end

        end

    end

endmodule
