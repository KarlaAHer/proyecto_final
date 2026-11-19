//====================================================
// ASCII -> BRAILLE (6 PUNTOS)
//
// Convencion de bits (estandar):
//   braille_out[i] = punto (i+1)
//
//      punto 1  o o  punto 4        bit0  bit3
//      punto 2  o o  punto 5        bit1  bit4
//      punto 3  o o  punto 6        bit2  bit5
//
// Asi el boton i, el servo i y el bit i son el mismo punto.
//
// Soporta: a-z / A-Z, n con tilde (Latin-1 0xD1/0xF1) y espacio.
// Cualquier otro caracter -> char_valid = 0 y celda vacia.
//====================================================

module ascii_to_braille (
    input  wire [7:0] ascii_in,
    output reg  [5:0] braille_out,
    output reg        char_valid
);

    always @(*) begin

        braille_out = 6'b000000;
        char_valid  = 1'b1;

        case (ascii_in)
            //                      654321   puntos
            8'h41, 8'h61: braille_out = 6'b000001; // a  1
            8'h42, 8'h62: braille_out = 6'b000011; // b  12
            8'h43, 8'h63: braille_out = 6'b001001; // c  14
            8'h44, 8'h64: braille_out = 6'b011001; // d  145
            8'h45, 8'h65: braille_out = 6'b010001; // e  15
            8'h46, 8'h66: braille_out = 6'b001011; // f  124
            8'h47, 8'h67: braille_out = 6'b011011; // g  1245
            8'h48, 8'h68: braille_out = 6'b010011; // h  125
            8'h49, 8'h69: braille_out = 6'b001010; // i  24
            8'h4A, 8'h6A: braille_out = 6'b011010; // j  245
            8'h4B, 8'h6B: braille_out = 6'b000101; // k  13
            8'h4C, 8'h6C: braille_out = 6'b000111; // l  123
            8'h4D, 8'h6D: braille_out = 6'b001101; // m  134
            8'h4E, 8'h6E: braille_out = 6'b011101; // n  1345
            8'h4F, 8'h6F: braille_out = 6'b010101; // o  135
            8'h50, 8'h70: braille_out = 6'b001111; // p  1234
            8'h51, 8'h71: braille_out = 6'b011111; // q  12345
            8'h52, 8'h72: braille_out = 6'b010111; // r  1235
            8'h53, 8'h73: braille_out = 6'b001110; // s  234
            8'h54, 8'h74: braille_out = 6'b011110; // t  2345
            8'h55, 8'h75: braille_out = 6'b100101; // u  136
            8'h56, 8'h76: braille_out = 6'b100111; // v  1236
            8'h57, 8'h77: braille_out = 6'b111010; // w  2456
            8'h58, 8'h78: braille_out = 6'b101101; // x  1346
            8'h59, 8'h79: braille_out = 6'b111101; // y  13456
            8'h5A, 8'h7A: braille_out = 6'b110101; // z  1356
            8'hD1, 8'hF1: braille_out = 6'b111011; // n tilde  12456
            8'h20:        braille_out = 6'b000000; // espacio (celda vacia)

            default: begin
                braille_out = 6'b000000;
                char_valid  = 1'b0;
            end
        endcase

    end

endmodule
