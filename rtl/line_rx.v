//====================================================
// RECEPTOR DE LINEAS DE COMANDO (PC -> FPGA)
//
// Formato:  <CMD><datos opcionales>'\n'   ('\r' tambien termina)
//
//   - El primer byte de la linea es el comando.
//   - Los datos de los comandos 'R', 'P' y 'H' se escriben en
//     char_buffer (maximo MAX_LEN caracteres).
//   - Si llegan mas de MAX_LEN datos se marca overflow.
//   - Las lineas vacias (p. ej. el '\n' de un "\r\n") se ignoran.
//
// Al terminar la linea se levanta line_ready y se mantiene
// hasta que el controlador responde con ack. Mientras
// line_ready = 1 los bytes nuevos se descartan (el PC espera la
// respuesta antes de mandar el siguiente comando).
//====================================================

module line_rx #(
    parameter MAX_LEN = 16,
    parameter AW      = 4
)(
    input  wire          clk,
    input  wire          rst,

    input  wire [7:0]    rx_data,
    input  wire          rx_valid,
    input  wire          ack,

    output reg  [7:0]    cmd,
    output reg  [AW:0]   len,        // numero de datos (0..MAX_LEN)
    output reg           overflow,
    output reg           line_ready,

    // Puerto de escritura hacia char_buffer
    output wire          buf_we,
    output wire [AW-1:0] buf_waddr,
    output wire [7:0]    buf_wdata
);

    localparam LF = 8'h0A;
    localparam CR = 8'h0D;

    reg have_cmd;

    wire is_term   = (rx_data == LF) || (rx_data == CR);
    wire store_cmd = (cmd == "R") || (cmd == "P") || (cmd == "H");
    wire accept    = rx_valid && !line_ready;

    // Escribe el dato en el buffer si cabe
    assign buf_we    = accept && have_cmd && !is_term &&
                       (len < MAX_LEN) && store_cmd;
    assign buf_waddr = len[AW-1:0];
    assign buf_wdata = rx_data;

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            cmd        <= 8'd0;
            len        <= 0;
            overflow   <= 1'b0;
            line_ready <= 1'b0;
            have_cmd   <= 1'b0;
        end

        else begin

            if (ack)
                line_ready <= 1'b0;

            if (accept) begin

                if (is_term) begin
                    if (have_cmd)
                        line_ready <= 1'b1;   // linea completa
                    have_cmd <= 1'b0;
                end

                else if (!have_cmd) begin
                    // Primer byte: comando
                    cmd      <= rx_data;
                    have_cmd <= 1'b1;
                    len      <= 0;
                    overflow <= 1'b0;
                end

                else if (len < MAX_LEN) begin
                    len <= len + 1'b1;
                end

                else begin
                    overflow <= 1'b1;
                end

            end

        end

    end

endmodule
