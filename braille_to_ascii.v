
module braille_to_ascii(

    input wire [5:0] braille_in,

    output reg [7:0] ascii_out,
    output reg char_valid

);

    //====================================================
    // CONVERSION BRAILLE A ASCII
    //====================================================

    always @(*) begin

        ascii_out = 8'h00;
        char_valid = 1'b0;

        case (braille_in)

            // LETRAS

            6'b100000: begin ascii_out = 8'h61; char_valid = 1'b1; end // a
            6'b101000: begin ascii_out = 8'h62; char_valid = 1'b1; end // b
            6'b110000: begin ascii_out = 8'h63; char_valid = 1'b1; end // c
            6'b110100: begin ascii_out = 8'h64; char_valid = 1'b1; end // d
            6'b100100: begin ascii_out = 8'h65; char_valid = 1'b1; end // e
            6'b111000: begin ascii_out = 8'h66; char_valid = 1'b1; end // f
            6'b111100: begin ascii_out = 8'h67; char_valid = 1'b1; end // g
            6'b101100: begin ascii_out = 8'h68; char_valid = 1'b1; end // h
            6'b011000: begin ascii_out = 8'h69; char_valid = 1'b1; end // i
            6'b011100: begin ascii_out = 8'h6A; char_valid = 1'b1; end // j
            6'b100010: begin ascii_out = 8'h6B; char_valid = 1'b1; end // k
            6'b101010: begin ascii_out = 8'h6C; char_valid = 1'b1; end // l
            6'b110010: begin ascii_out = 8'h6D; char_valid = 1'b1; end // m
            6'b110110: begin ascii_out = 8'h6E; char_valid = 1'b1; end // n
            6'b100110: begin ascii_out = 8'h6F; char_valid = 1'b1; end // o
            6'b111010: begin ascii_out = 8'h70; char_valid = 1'b1; end // p
            6'b111110: begin ascii_out = 8'h71; char_valid = 1'b1; end // q
            6'b101110: begin ascii_out = 8'h72; char_valid = 1'b1; end // r
            6'b011010: begin ascii_out = 8'h73; char_valid = 1'b1; end // s
            6'b011110: begin ascii_out = 8'h74; char_valid = 1'b1; end // t
            6'b100011: begin ascii_out = 8'h75; char_valid = 1'b1; end // u
            6'b101011: begin ascii_out = 8'h76; char_valid = 1'b1; end // v
            6'b011101: begin ascii_out = 8'h77; char_valid = 1'b1; end // w
            6'b110011: begin ascii_out = 8'h78; char_valid = 1'b1; end // x
            6'b110111: begin ascii_out = 8'h79; char_valid = 1'b1; end // y
            6'b100111: begin ascii_out = 8'h7A; char_valid = 1'b1; end // z


            // ESPACIO

            6'b000000: begin
                ascii_out = 8'h20;
                char_valid = 1'b1;
            end


            // PATRON NO RECONOCIDO

            default: begin
                ascii_out = 8'h00;
                char_valid = 1'b0;
            end

        endcase

    end

endmodule
