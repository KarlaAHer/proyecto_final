//====================================================
// BINARIO 12 BITS -> 4 DIGITOS BCD (double dabble, combinacional)
//====================================================

module bin12_to_bcd (
    input  wire [11:0] bin,
    output reg  [3:0]  thousands,
    output reg  [3:0]  hundreds,
    output reg  [3:0]  tens,
    output reg  [3:0]  ones
);
    integer i;
    reg [27:0] sh;

    always @(*) begin
        sh = {16'd0, bin};
        for (i = 0; i < 12; i = i + 1) begin
            if (sh[15:12] >= 5) sh[15:12] = sh[15:12] + 4'd3;
            if (sh[19:16] >= 5) sh[19:16] = sh[19:16] + 4'd3;
            if (sh[23:20] >= 5) sh[23:20] = sh[23:20] + 4'd3;
            if (sh[27:24] >= 5) sh[27:24] = sh[27:24] + 4'd3;
            sh = sh << 1;
        end
        thousands = sh[27:24];
        hundreds  = sh[23:20];
        tens      = sh[19:16];
        ones      = sh[15:12];
    end
endmodule
