//====================================================
// DECODIFICADOR 7 SEGMENTOS (ACTIVO EN BAJO, {g,f,e,d,c,b,a})
// 0-9 = digitos, 10 = L, 11 = r, 12 = d, 13 = U, otro = apagado
//====================================================

module seg7_cal (
    input  wire [3:0] code,
    output reg  [6:0] seg
);
    always @(*) begin
        case (code)
            4'd0:  seg = 7'b1000000;
            4'd1:  seg = 7'b1111001;
            4'd2:  seg = 7'b0100100;
            4'd3:  seg = 7'b0110000;
            4'd4:  seg = 7'b0011001;
            4'd5:  seg = 7'b0010010;
            4'd6:  seg = 7'b0000010;
            4'd7:  seg = 7'b1111000;
            4'd8:  seg = 7'b0000000;
            4'd9:  seg = 7'b0010000;
            4'd10: seg = 7'b1000111;  // L
            4'd11: seg = 7'b0101111;  // r
            4'd12: seg = 7'b0100001;  // d
            4'd13: seg = 7'b1000001;  // U
            default: seg = 7'b1111111;
        endcase
    end
endmodule
