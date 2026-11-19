
module ascii_to_braille(

    input wire [7:0] ascii_in,

    output reg [5:0] braille_out,
    output reg char_valid,
    output reg is_uppercase,
    output reg is_digit,
    output reg is_space

);

    //====================================================
    // CONVERSION ASCII A BRAILLE
    //====================================================

    always @(*) begin

        braille_out = 6'b000000;
        char_valid = 1'b0;
        is_uppercase = 1'b0;
        is_digit = 1'b0;
        is_space = 1'b0;

        case (ascii_in)

            // LETRAS

            8'h41, 8'h61: begin braille_out = 6'b100000; char_valid = 1'b1; end // A
            8'h42, 8'h62: begin braille_out = 6'b101000; char_valid = 1'b1; end // B
            8'h43, 8'h63: begin braille_out = 6'b110000; char_valid = 1'b1; end // C
            8'h44, 8'h64: begin braille_out = 6'b110100; char_valid = 1'b1; end // D
            8'h45, 8'h65: begin braille_out = 6'b100100; char_valid = 1'b1; end // E
            8'h46, 8'h66: begin braille_out = 6'b111000; char_valid = 1'b1; end // F
            8'h47, 8'h67: begin braille_out = 6'b111100; char_valid = 1'b1; end // G
            8'h48, 8'h68: begin braille_out = 6'b101100; char_valid = 1'b1; end // H
            8'h49, 8'h69: begin braille_out = 6'b011000; char_valid = 1'b1; end // I
            8'h4A, 8'h6A: begin braille_out = 6'b011100; char_valid = 1'b1; end // J
            8'h4B, 8'h6B: begin braille_out = 6'b100010; char_valid = 1'b1; end // K
            8'h4C, 8'h6C: begin braille_out = 6'b101010; char_valid = 1'b1; end // L
            8'h4D, 8'h6D: begin braille_out = 6'b110010; char_valid = 1'b1; end // M
            8'h4E, 8'h6E: begin braille_out = 6'b110110; char_valid = 1'b1; end // N
            8'h4F, 8'h6F: begin braille_out = 6'b100110; char_valid = 1'b1; end // O
            8'h50, 8'h70: begin braille_out = 6'b111010; char_valid = 1'b1; end // P
            8'h51, 8'h71: begin braille_out = 6'b111110; char_valid = 1'b1; end // Q
            8'h52, 8'h72: begin braille_out = 6'b101110; char_valid = 1'b1; end // R
            8'h53, 8'h73: begin braille_out = 6'b011010; char_valid = 1'b1; end // S
            8'h54, 8'h74: begin braille_out = 6'b011110; char_valid = 1'b1; end // T
            8'h55, 8'h75: begin braille_out = 6'b100011; char_valid = 1'b1; end // U
            8'h56, 8'h76: begin braille_out = 6'b101011; char_valid = 1'b1; end // V
            8'h57, 8'h77: begin braille_out = 6'b011101; char_valid = 1'b1; end // W
            8'h58, 8'h78: begin braille_out = 6'b110011; char_valid = 1'b1; end // X
            8'h59, 8'h79: begin braille_out = 6'b110111; char_valid = 1'b1; end // Y
            8'h5A, 8'h7A: begin braille_out = 6'b100111; char_valid = 1'b1; end // Z


            // NUMEROS

            8'h31: begin braille_out = 6'b100000; char_valid = 1'b1; is_digit = 1'b1; end // 1
            8'h32: begin braille_out = 6'b101000; char_valid = 1'b1; is_digit = 1'b1; end // 2
            8'h33: begin braille_out = 6'b110000; char_valid = 1'b1; is_digit = 1'b1; end // 3
            8'h34: begin braille_out = 6'b110100; char_valid = 1'b1; is_digit = 1'b1; end // 4
            8'h35: begin braille_out = 6'b100100; char_valid = 1'b1; is_digit = 1'b1; end // 5
            8'h36: begin braille_out = 6'b111000; char_valid = 1'b1; is_digit = 1'b1; end // 6
            8'h37: begin braille_out = 6'b111100; char_valid = 1'b1; is_digit = 1'b1; end // 7
            8'h38: begin braille_out = 6'b101100; char_valid = 1'b1; is_digit = 1'b1; end // 8
            8'h39: begin braille_out = 6'b011000; char_valid = 1'b1; is_digit = 1'b1; end // 9
            8'h30: begin braille_out = 6'b011100; char_valid = 1'b1; is_digit = 1'b1; end // 0


            // ESPACIO

            8'h20: begin
                braille_out = 6'b000000;
                char_valid = 1'b1;
                is_space = 1'b1;
            end


            // CARACTER NO SOPORTADO

            default: begin
                braille_out = 6'b000000;
                char_valid = 1'b0;
            end

        endcase

        // IDENTIFICAR MAYUSCULAS

        if (ascii_in >= 8'h41 && ascii_in <= 8'h5A)
            is_uppercase = 1'b1;

    end

endmodule
