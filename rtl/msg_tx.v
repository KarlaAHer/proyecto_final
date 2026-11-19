//====================================================
// TRANSMISOR DE MENSAJES (FPGA -> PC)
//
// Envia msg_len bytes (1..6) de msg_data y agrega '\n'.
// El byte 0 esta en msg_data[7:0] y se envia primero.
// Copia el mensaje al iniciar, asi el controlador puede
// preparar el siguiente mientras este se transmite.
//====================================================

module msg_tx #(
    parameter CLKS_PER_BIT = 5208
)(
    input  wire        clk,
    input  wire        rst,

    input  wire        start,
    input  wire [2:0]  msg_len,
    input  wire [47:0] msg_data,

    output wire        tx,
    output reg         busy
);

    localparam IDLE = 2'd0;
    localparam SEND = 2'd1;
    localparam WAIT = 2'd2;

    reg [1:0]  state;
    reg [2:0]  idx;
    reg [2:0]  len_reg;
    reg [47:0] data_reg;

    reg  [7:0] uart_data;
    reg        uart_start;
    wire       uart_busy;
    wire       uart_done;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) TX0 (
        .clk     (clk),
        .rst     (rst),
        .data_in (uart_data),
        .tx_start(uart_start),
        .tx      (tx),
        .tx_busy (uart_busy),
        .tx_done (uart_done)
    );

    always @(posedge clk or posedge rst) begin

        if (rst) begin
            state      <= IDLE;
            idx        <= 3'd0;
            len_reg    <= 3'd0;
            data_reg   <= 48'd0;
            uart_data  <= 8'd0;
            uart_start <= 1'b0;
            busy       <= 1'b0;
        end

        else begin

            uart_start <= 1'b0;

            case (state)

                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        data_reg <= msg_data;
                        len_reg  <= msg_len;
                        idx      <= 3'd0;
                        busy     <= 1'b1;
                        state    <= SEND;
                    end
                end

                SEND: begin
                    // Ultimo byte: fin de linea
                    uart_data  <= (idx == len_reg) ? 8'h0A
                                                   : data_reg[idx*8 +: 8];
                    uart_start <= 1'b1;
                    state      <= WAIT;
                end

                WAIT: begin
                    if (uart_done) begin
                        if (idx == len_reg) begin
                            busy  <= 1'b0;
                            state <= IDLE;
                        end
                        else begin
                            idx   <= idx + 1'b1;
                            state <= SEND;
                        end
                    end
                end

                default: state <= IDLE;

            endcase

        end

    end

endmodule
