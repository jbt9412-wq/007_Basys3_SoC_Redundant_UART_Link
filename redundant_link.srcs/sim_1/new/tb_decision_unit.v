`timescale 1ns / 1ps

module tb_decision_unit;

    localparam [1:0] PAIR     = 2'b01;
    localparam [1:0] SINGLE_A = 2'b10;
    localparam [1:0] SINGLE_B = 2'b11;

    reg         clk;
    reg         reset_p;
    reg         result_valid;
    reg  [1:0]  result_kind;
    reg         result_pair_equal;
    reg  [3:0]  mismatch_flags;
    reg  [7:0]  in_sequence;

    wire        decision_valid;
    wire        decision_accept;
    wire [1:0]  decision_kind;
    wire        decision_degraded;
    wire [3:0]  decision_mismatch_flags;
    wire [7:0]  out_sequence;

    integer error_count;

    decision_unit dut (
        .clk                     (clk),
        .reset_p                 (reset_p),
        .result_valid            (result_valid),
        .result_kind             (result_kind),
        .result_pair_equal       (result_pair_equal),
        .mismatch_flags          (mismatch_flags),
        .in_frame_length         (8'd4),
        .in_device_id            (8'h01),
        .in_command              (8'h10),
        .in_sequence             (in_sequence),
        .in_payload_data         (128'hAA),
        .in_received_crc         (16'h1234),
        .in_seq_gap              (1'b0),
        .decision_valid          (decision_valid),
        .decision_accept         (decision_accept),
        .decision_kind           (decision_kind),
        .decision_degraded       (decision_degraded),
        .decision_mismatch_flags (decision_mismatch_flags),
        .out_frame_length        (),
        .out_device_id           (),
        .out_command             (),
        .out_sequence            (out_sequence),
        .out_payload_data        (),
        .out_received_crc        (),
        .out_seq_gap             ()
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task send_and_check;
        input [1:0] kind;
        input       pair_equal;
        input [3:0] mismatch;
        input [7:0] sequence_value;
        input       expected_accept;
        input       expected_degraded;
        begin
            @(negedge clk);
            result_valid      = 1'b1;
            result_kind       = kind;
            result_pair_equal = pair_equal;
            mismatch_flags    = mismatch;
            in_sequence       = sequence_value;

            @(negedge clk);
            result_valid = 1'b0;
            #1;

            if ((decision_valid    !== 1'b1)              ||
                (decision_accept   !== expected_accept)   ||
                (decision_kind     !== kind)              ||
                (decision_degraded !== expected_degraded) ||
                (out_sequence !==
                    (expected_accept ? sequence_value : 8'd0))) begin
                error_count = error_count + 1;
                $display("[FAIL] kind=%b accept=%b degraded=%b",
                         kind, decision_accept, decision_degraded);
            end

            if ((kind == PAIR) &&
                (decision_mismatch_flags !== mismatch)) begin
                error_count = error_count + 1;
                $display("[FAIL] mismatch flag capture");
            end

            @(negedge clk);
            #1;
            if ((decision_valid    !== 1'b0) ||
                (decision_accept   !== 1'b0) ||
                (decision_degraded !== 1'b0)) begin
                error_count = error_count + 1;
                $display("[FAIL] decision output is not a one-cycle pulse");
            end
        end
    endtask

    initial begin
        reset_p          = 1'b1;
        result_valid     = 1'b0;
        result_kind      = 2'b00;
        result_pair_equal = 1'b0;
        mismatch_flags   = 4'b0000;
        in_sequence      = 8'd0;
        error_count      = 0;

        repeat (2) @(negedge clk);
        reset_p = 1'b0;

        // 일치 Pair 채택
        send_and_check(PAIR, 1'b1, 4'b0000, 8'd10, 1'b1, 1'b0);

        // 불일치 Pair 폐기
        send_and_check(PAIR, 1'b0, 4'b1000, 8'd11, 1'b0, 1'b0);

        // Single은 채택하되 degraded 표시
        send_and_check(SINGLE_A, 1'b0, 4'b0000, 8'd12, 1'b1, 1'b1);
        send_and_check(SINGLE_B, 1'b0, 4'b0000, 8'd13, 1'b1, 1'b1);

        if (error_count == 0)
            $display("[PASS] All decision_unit tests passed.");
        else
            $display("[FAIL] error_count=%0d", error_count);

        $finish;
    end

endmodule
