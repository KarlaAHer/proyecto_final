//====================================================
// BRAILLE (6 PUNTOS) -> ASCII
//
// Misma convencion que ascii_to_braille: bit[i] = punto (i+1).
// Devuelve letras minusculas (y 0xF1 para la n con tilde).
// El patron 000000 no es valido aqui: el espacio se escribe
// con el boton NEXT en modo escritura.
//====================================================

module braille_to_ascii (
    input  wire [5:0] braille_in,
    output reg  [7:0] ascii_out,
    output reg        char_valid
);

    always @(*) begin

        ascii_out  = 8'h3F;   // '?'
        char_valid = 1'b1;

        case (braille_in)
            6'b000001: ascii_out = 8'h61; // a
            6'b000011: ascii_out = 8'h62; // b
            6'b001001: ascii_out = 8'h63; // c
            6'b011001: ascii_out = 8'h64; // d
            6'b010001: ascii_out = 8'h65; // e
            6'b001011: ascii_out = 8'h66; // f
            6'b011011: ascii_out = 8'h67; // g
            6'b010011: ascii_out = 8'h68; // h
            6'b001010: ascii_out = 8'h69; // i
            6'b011010: ascii_out = 8'h6A; // j
            6'b000101: ascii_out = 8'h6B; // k
            6'b000111: ascii_out = 8'h6C; // l
            6'b001101: ascii_out = 8'h6D; // m
            6'b011101: ascii_out = 8'h6E; // n
            6'b010101: ascii_out = 8'h6F; // o
            6'b001111: ascii_out = 8'h70; // p
            6'b011111: ascii_out = 8'h71; // q
            6'b010111: ascii_out = 8'h72; // r
            6'b001110: ascii_out = 8'h73; // s
            6'b011110: ascii_out = 8'h74; // t
            6'b100101: ascii_out = 8'h75; // u
            6'b100111: ascii_out = 8'h76; // v
            6'b111010: ascii_out = 8'h77; // w
            6'b101101: ascii_out = 8'h78; // x
            6'b111101: ascii_out = 8'h79; // y
            6'b110101: ascii_out = 8'h7A; // z
            6'b111011: ascii_out = 8'hF1; // n tilde

            default: begin
                ascii_out  = 8'h3F;   // '?'
                char_valid = 1'b0;
            end
        endcase

    end

endmodule
