//====================================================
// BUFFER DE CARACTERES (MAX_LEN x 8 bits)
//
// Escritura sincrona (la hace line_rx al recibir).
// Lectura combinacional (la hace el controlador).
//====================================================

module char_buffer #(
    parameter MAX_LEN = 16,
    parameter AW      = 4          // log2(MAX_LEN)
)(
    input  wire          clk,

    input  wire          wr_en,
    input  wire [AW-1:0] wr_addr,
    input  wire [7:0]    wr_data,

    input  wire [AW-1:0] rd_addr,
    output wire [7:0]    rd_data
);

    reg [7:0] mem [0:MAX_LEN-1];

    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    assign rd_data = mem[rd_addr];

endmodule
