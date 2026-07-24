`timescale 1ns / 1ps

module tb_pair_matcher;

    localparam [1:0] NONE     = 2'b00;
    localparam [1:0] PAIR     = 2'b01;
    localparam [1:0] SINGLE_A = 2'b10;
    localparam [1:0] SINGLE_B = 2'b11;

    reg       clk;
    reg       reset_p;

    reg       a_empty;
    reg [7:0] a_sequence;
    reg [7:0] a_command;

    reg       b_empty;
    reg [7:0] b_sequence;
    reg [7:0] b_command;

    wire       pop_a;
    wire       pop_b;
    wire       result_valid;
    wire [1:0] result_kind;
    wire       result_pair_equal;
    wire [3:0] mismatch_flags;
    wire       result_timeout;
    wire       result_seq_skew;
    wire       result_seq_ambiguous;

    integer error_count;

    pair_matcher #(
        .PAIR_TIMEOUT_CYCLES (3),
        .TIMEOUT_COUNT_WIDTH (2)
    ) dut (
        .clk                  (clk),
        .reset_p              (reset_p),

        .a_empty              (a_empty),
        .a_frame_length       (8'd3),
        .a_device_id          (8'h01),
        .a_command            (a_command),
        .a_sequence           (a_sequence),
        .a_payload_data       (128'd0),
        .a_received_crc       (16'd0),
        .a_seq_gap            (1'b0),

        .b_empty              (b_empty),
        .b_frame_length       (8'd3),
        .b_device_id          (8'h01),
        .b_command            (b_command),
        .b_sequence           (b_sequence),
        .b_payload_data       (128'd0),
        .b_received_crc       (16'd0),
        .b_seq_gap            (1'b0),

        .pop_a                (pop_a),
        .pop_b                (pop_b),

        .result_valid         (result_valid),
        .result_kind          (result_kind),
        .result_pair_equal    (result_pair_equal),
        .mismatch_flags       (mismatch_flags),

        .result_timeout       (result_timeout),
        .result_seq_skew      (result_seq_skew),
        .result_seq_ambiguous (result_seq_ambiguous),

        .out_frame_length     (),
        .out_device_id        (),
        .out_command          (),
        .out_sequence         (),
        .out_payload_data     (),
        .out_received_crc     (),
        .out_seq_gap          ()
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task check;
        input [1:0] expected_kind;
        input       expected_pop_a;
        input       expected_pop_b;
        input       expected_equal;
        input [3:0] expected_mismatch;
        input       expected_timeout;
        input       expected_skew;
        input       expected_ambiguous;
        begin
            #1;

            if ((result_valid         !== (expected_kind != NONE)) ||
                (result_kind          !== expected_kind)           ||
                (pop_a                !== expected_pop_a)          ||
                (pop_b                !== expected_pop_b)          ||
                (result_pair_equal    !== expected_equal)          ||
                (mismatch_flags       !== expected_mismatch)       ||
                (result_timeout       !== expected_timeout)        ||
                (result_seq_skew      !== expected_skew)           ||
                (result_seq_ambiguous !== expected_ambiguous)) begin

                error_count = error_count + 1;

                $display(
                    "[FAIL] time=%0t kind=%b/%b mismatch=%b/%b",
                    $time,
                    result_kind,
                    expected_kind,
                    mismatch_flags,
                    expected_mismatch
                );
            end
        end
    endtask

    initial begin
        reset_p     = 1'b1;

        a_empty     = 1'b1;
        a_sequence  = 8'd0;
        a_command   = 8'h10;

        b_empty     = 1'b1;
        b_sequence  = 8'd0;
        b_command   = 8'h10;

        error_count = 0;

        repeat (2) @(negedge clk);
        reset_p = 1'b0;

        check(
            NONE, 1'b0, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b0, 1'b0
        );

        // -------------------------------------------------------------
        // 1. 같은 SEQ, 같은 내용
        //    Pair 성립, A/B 모두 Pop
        // -------------------------------------------------------------
        @(negedge clk);
        a_empty     = 1'b0;
        b_empty     = 1'b0;
        a_sequence  = 8'd10;
        b_sequence  = 8'd10;
        a_command   = 8'h10;
        b_command   = 8'h10;

        check(
            PAIR, 1'b1, 1'b1, 1'b1, 4'b0000,
            1'b0, 1'b0, 1'b0
        );

        // -------------------------------------------------------------
        // 2. 같은 SEQ이지만 CMD 불일치
        //    Pair는 성립하지만 pair_equal=0
        //    mismatch_flags[2]=1
        // -------------------------------------------------------------
        @(negedge clk);
        a_sequence = 8'd20;
        b_sequence = 8'd20;
        a_command  = 8'h10;
        b_command  = 8'h20;

        check(
            PAIR, 1'b1, 1'b1, 1'b0, 4'b0100,
            1'b0, 1'b0, 1'b0
        );

        // 이후 테스트를 위해 CMD 복구
        @(negedge clk);
        a_command  = 8'h10;
        b_command  = 8'h10;

        // -------------------------------------------------------------
        // 3. SEQ 순환 검증
        //    FF 다음은 00이므로 A=FF가 더 오래된 프레임
        // -------------------------------------------------------------
        a_sequence = 8'hFF;
        b_sequence = 8'h00;

        check(
            SINGLE_A, 1'b1, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b1, 1'b0
        );

        // -------------------------------------------------------------
        // 4. 일반적인 A가 오래된 경우
        // -------------------------------------------------------------
        @(negedge clk);
        a_sequence = 8'd11;
        b_sequence = 8'd15;

        check(
            SINGLE_A, 1'b1, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b1, 1'b0
        );

        // -------------------------------------------------------------
        // 5. 일반적인 B가 오래된 경우
        // -------------------------------------------------------------
        @(negedge clk);
        a_sequence = 8'd20;
        b_sequence = 8'd16;

        check(
            SINGLE_B, 1'b0, 1'b1, 1'b0, 4'b0000,
            1'b0, 1'b1, 1'b0
        );

        // -------------------------------------------------------------
        // 6. SEQ 차이가 정확히 128
        //    순서 판단 불가 → A 처리 + ambiguous
        // -------------------------------------------------------------
        @(negedge clk);
        a_sequence = 8'h20;
        b_sequence = 8'hA0;

        check(
            SINGLE_A, 1'b1, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b1, 1'b1
        );

        // -------------------------------------------------------------
        // 7. A만 존재: 3클럭 대기 후 Timeout
        // -------------------------------------------------------------
        @(negedge clk);
        a_sequence = 8'd30;
        b_empty    = 1'b1;

        check(
            NONE, 1'b0, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b0, 1'b0
        );

        @(negedge clk);
        check(
            NONE, 1'b0, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b0, 1'b0
        );

        @(negedge clk);
        check(
            SINGLE_A, 1'b1, 1'b0, 1'b0, 4'b0000,
            1'b1, 1'b0, 1'b0
        );

        // A FIFO에서 Pop된 상황 반영
        @(negedge clk);
        a_empty = 1'b1;

        check(
            NONE, 1'b0, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b0, 1'b0
        );

        // -------------------------------------------------------------
        // 8. B만 존재: 3클럭 대기 후 Timeout
        // -------------------------------------------------------------
        @(negedge clk);
        b_empty    = 1'b0;
        b_sequence = 8'd40;

        check(
            NONE, 1'b0, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b0, 1'b0
        );

        @(negedge clk);
        check(
            NONE, 1'b0, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b0, 1'b0
        );

        @(negedge clk);
        check(
            SINGLE_B, 1'b0, 1'b1, 1'b0, 4'b0000,
            1'b1, 1'b0, 1'b0
        );

        @(negedge clk);
        b_empty = 1'b1;

        check(
            NONE, 1'b0, 1'b0, 1'b0, 4'b0000,
            1'b0, 1'b0, 1'b0
        );

        if (error_count == 0)
            $display("[PASS] All pair_matcher core tests passed.");
        else
            $display("[FAIL] error_count=%0d", error_count);

        $finish;
    end

    // 무한 시뮬레이션 방지
    initial begin
        #1000;
        $display("[FAIL] Simulation timeout");
        $finish;
    end

endmodule