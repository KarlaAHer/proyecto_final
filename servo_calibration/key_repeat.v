//====================================================
// AUTO-REPETICION PARA UN BOTON YA LIMPIO (DEBOUNCED)
//
// - Al presionar: un pulso de paso inmediato.
// - Si se mantiene presionado HOLD_DELAY ciclos: un pulso
//   cada REPEAT_DELAY ciclos mientras siga presionado.
//====================================================

module key_repeat #(
    parameter HOLD_DELAY   = 25000000,  // 0.5 s a 50 MHz
    parameter REPEAT_DELAY = 5000000,   // 0.1 s a 50 MHz (10 pasos/s)
    parameter WIDTH        = 26
)(
    input  wire clk,
    input  wire rst,
    input  wire pressed,      // nivel limpio (1 = presionado)
    input  wire press_pulse,  // pulso de 1 ciclo al presionar
    output reg  step
);

    reg [WIDTH-1:0] hold_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hold_count <= 0;
            step       <= 1'b0;
        end
        else begin
            step <= 1'b0;
            if (!pressed) begin
                hold_count <= 0;
            end
            else if (press_pulse) begin
                hold_count <= 0;
                step       <= 1'b1;
            end
            else if (hold_count >= HOLD_DELAY - 1) begin
                hold_count <= HOLD_DELAY - REPEAT_DELAY;
                step       <= 1'b1;
            end
            else begin
                hold_count <= hold_count + 1'b1;
            end
        end
    end

endmodule
