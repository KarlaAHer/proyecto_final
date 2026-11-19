
module button_conditioner #(
    parameter N_BUTTONS = 7,
    parameter DEBOUNCE_COUNT = 500000,
    parameter COUNTER_WIDTH = 19
)(
    input wire clk,
    input wire rst,

    input wire [N_BUTTONS-1:0] buttons_n,

    output reg [N_BUTTONS-1:0] buttons_pressed,
    output reg [N_BUTTONS-1:0] press_pulse
);

    //====================================================
    // REGISTROS DE SINCRONIZACION
    //====================================================

    reg [N_BUTTONS-1:0] sync_ff1;
    reg [N_BUTTONS-1:0] sync_ff2;

    //====================================================
    // CONTADORES DE DEBOUNCE
    //====================================================

    reg [COUNTER_WIDTH-1:0] debounce_count [0:N_BUTTONS-1];

    integer i;

    //====================================================
    // SINCRONIZACION Y DEBOUNCE
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            sync_ff1 <= {N_BUTTONS{1'b1}};
            sync_ff2 <= {N_BUTTONS{1'b1}};

            buttons_pressed <= {N_BUTTONS{1'b0}};
            press_pulse <= {N_BUTTONS{1'b0}};

            for (i = 0; i < N_BUTTONS; i = i + 1) begin
                debounce_count[i] <= 0;
            end

        end

        else begin

            // SINCRONIZACION

            sync_ff1 <= buttons_n;
            sync_ff2 <= sync_ff1;

            // DEBOUNCE INDIVIDUAL

            for (i = 0; i < N_BUTTONS; i = i + 1) begin

                press_pulse[i] <= 1'b0;

                if ((~sync_ff2[i]) == buttons_pressed[i]) begin

                    debounce_count[i] <= 0;

                end

                else if (debounce_count[i] >= DEBOUNCE_COUNT - 1) begin

                    buttons_pressed[i] <= ~sync_ff2[i];

                    debounce_count[i] <= 0;

                    if (~sync_ff2[i])
                        press_pulse[i] <= 1'b1;

                end

                else begin

                    debounce_count[i] <= debounce_count[i] + 1'b1;

                end

            end

        end

    end

endmodule
