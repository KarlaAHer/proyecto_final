
module servo_controller #(
    parameter PERIOD = 1000000,
    parameter PULSE_DOWN = 70000,
    parameter PULSE_UP = 82500,
    parameter COUNTER_WIDTH = 20
)(
    input wire clk,
    input wire rst,

    input wire [5:0] braille_pattern,
    input wire pattern_update,

    output wire [5:0] servo_pwm
);

    //====================================================
    // REGISTROS
    //====================================================

    reg [COUNTER_WIDTH-1:0] pwm_count;

    reg [5:0] pattern_pending;
    reg [5:0] pattern_active;


    //====================================================
    // GENERACION DEL PERIODO PWM
    //====================================================

    always @(posedge clk or posedge rst) begin

        if (rst) begin

            pwm_count <= 0;

            pattern_pending <= 6'b000000;
            pattern_active <= 6'b000000;

        end

        else begin

            // GUARDAR NUEVO PATRON

            if (pattern_update)
                pattern_pending <= braille_pattern;


            // CONTROL DEL PERIODO PWM

            if (pwm_count == PERIOD - 1) begin

                pwm_count <= 0;

                // ACTUALIZAR AL INICIO DEL PERIODO

                if (pattern_update)
                    pattern_active <= braille_pattern;

                else
                    pattern_active <= pattern_pending;

            end

            else begin

                pwm_count <= pwm_count + 1'b1;

            end

        end

    end


    //====================================================
    // GENERACION DE SEIS SALIDAS PWM
    //====================================================

    genvar i;

    generate

        for (i = 0; i < 6; i = i + 1) begin: SERVO_CHANNELS

            assign servo_pwm[i] =
                (pwm_count < (pattern_active[i] ? PULSE_UP : PULSE_DOWN));

        end

    endgenerate

endmodule

