`timescale 1ns/1ps
// Testbench con tiempos reducidos (1 cuenta por us, periodo de 3000 cuentas)
module servo_cal_top_tb;
    reg        clk = 0;
    reg  [1:0] KEY = 2'b11;
    reg  [9:0] SW  = 10'b1000000000;   // reset activo
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire [9:0] LEDR;
    wire [5:0] SERVO;

    always #10 clk = ~clk;

    servo_cal_top #(
        .CLKS_PER_US(1), .PERIOD(3000), .DEBOUNCE_COUNT(4),
        .HOLD_DELAY(200), .REPEAT_DELAY(50)
    ) dut (.CLOCK_50(clk), .KEY(KEY), .SW(SW),
           .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
           .LEDR(LEDR), .SERVO(SERVO));

    integer errors = 0;
    task check(input [11:0] got, input [11:0] exp, input [8*24-1:0] name);
        if (got !== exp) begin
            $display("FAIL %0s: got %0d expected %0d", name, got, exp); errors = errors + 1;
        end else $display("ok   %0s = %0d", name, got);
    endtask

    // mide el ancho del pulso de un canal
    task measure(input integer ch, output integer width);
        begin
            @(posedge SERVO[ch]); t0 = $realtime;
            @(negedge SERVO[ch]); width = ($realtime - t0) / 20.0;  // periodo de reloj = 20 ns
        end
    endtask

    integer w;
    real t0;
    initial begin
        repeat (5) @(posedge clk);
        SW = 10'b0_1_000000_00;           // PREVIEW, editar DOWN_L
        repeat (10) @(posedge clk);
        check(dut.cur, 1400, "init DOWN_L");

        // 3 toques de +  -> 1415
        repeat (3) begin
            KEY[0] = 0; repeat (20) @(posedge clk); KEY[0] = 1; repeat (20) @(posedge clk);
        end
        check(dut.cur, 1415, "DOWN_L after 3x +");

        // un toque de -  -> 1410
        KEY[1] = 0; repeat (20) @(posedge clk); KEY[1] = 1; repeat (20) @(posedge clk);
        check(dut.cur, 1410, "DOWN_L after 1x -");

        // mantener +: 1 paso inmediato + repeticiones
        KEY[0] = 0; repeat (400) @(posedge clk); KEY[0] = 1; repeat (20) @(posedge clk);
        $display("     DOWN_L after hold = %0d", dut.cur);
        if (dut.cur <= 1415) begin $display("FAIL hold repeat"); errors = errors + 1; end

        // display: digitos de 1400 + pasos
        $display("     HEX3..0 codes = %0d%0d%0d%0d", dut.d3, dut.d2, dut.d1, dut.d0);

        // ancho real del PWM en preview DOWN (todos abajo)
        measure(0, w); measure(0, w);
        check(w, dut.pulse_us[0], "PWM ch0 width");
        measure(3, w);
        check(w, 1600, "PWM ch3 width (DOWN_R)");

        // editar UP_R y bajar hasta el limite
        SW = 10'b0_1_000000_11;
        repeat (10) @(posedge clk);
        check(dut.cur, 1339, "init UP_R");
        KEY[1] = 0; repeat (20000) @(posedge clk); KEY[1] = 1; repeat (20) @(posedge clk);
        check(dut.cur, 1000, "UP_R clamped at MIN");
        if (!LEDR[9]) begin $display("FAIL LEDR9 limit"); errors = errors + 1; end
        measure(4, w); measure(4, w);
        check(w, 1000, "PWM ch4 width (UP_R)");

        // modo PRUEBA: patron 000001 -> ch0 arriba (UP_L), ch1 abajo
        SW = 10'b0_0_000001_00;
        measure(0, w); measure(0, w);
        check(w, 1661, "TEST ch0 UP_L");
        measure(1, w);
        check(w, dut.pulse_us[0], "TEST ch1 DOWN_L");

        if (errors == 0) $display("ALL TESTS PASSED"); else $display("%0d ERRORS", errors);
        $finish;
    end
endmodule
