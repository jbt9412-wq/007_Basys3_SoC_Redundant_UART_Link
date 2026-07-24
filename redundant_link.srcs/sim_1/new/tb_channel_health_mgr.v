`timescale 1ns / 1ps

// channel_health_mgr 핵심 정책 확인용 Self-checking Testbench
//
// 검증 항목
//   1. Fail 2회 뒤 Good이 오면 Fail Count 초기화
//   2. 연속 Fail 3회에서 Fault 진입
//   3. Fault 후 정상 Pair 5회에서만 복구
//   4. Single A 3회이면 B만 Fault
//   5. Local Fail 3회이면 해당 채널만 Fault

module tb_channel_health_mgr;

    localparam [1:0] NONE     = 2'b00;
    localparam [1:0] PAIR     = 2'b01;
    localparam [1:0] SINGLE_A = 2'b10;
    localparam [1:0] SINGLE_B = 2'b11;

    reg       clk;
    reg       reset_p;

    reg       matcher_result_valid;
    reg [1:0] matcher_result_kind;
    reg       matcher_pair_equal;

    reg       a_local_fail_event;
    reg       b_local_fail_event;

    wire       a_fault;
    wire       b_fault;
    wire [7:0] a_fail_count;
    wire [7:0] b_fail_count;
    wire [7:0] a_recover_count;
    wire [7:0] b_recover_count;
    wire       a_fault_enter_pulse;
    wire       b_fault_enter_pulse;
    wire       a_recovered_pulse;
    wire       b_recovered_pulse;

    integer error_count;
    integer test_index;

    channel_health_mgr #(
        .FAIL_THRESHOLD    (3),
        .RECOVER_THRESHOLD (5)
    ) dut (
        .clk                  (clk),
        .reset_p              (reset_p),

        .matcher_result_valid (matcher_result_valid),
        .matcher_result_kind  (matcher_result_kind),
        .matcher_pair_equal   (matcher_pair_equal),

        .a_local_fail_event   (a_local_fail_event),
        .b_local_fail_event   (b_local_fail_event),

        .a_fault              (a_fault),
        .b_fault              (b_fault),
        .a_fail_count         (a_fail_count),
        .b_fail_count         (b_fail_count),
        .a_recover_count      (a_recover_count),
        .b_recover_count      (b_recover_count),

        .a_fault_enter_pulse  (a_fault_enter_pulse),
        .b_fault_enter_pulse  (b_fault_enter_pulse),
        .a_recovered_pulse    (a_recovered_pulse),
        .b_recovered_pulse    (b_recovered_pulse)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // pair_matcher 결과를 1클럭 동안 입력한다.
    task send_matcher_result;
        input [1:0] result_kind;
        input       pair_equal;
        begin
            @(negedge clk);
            matcher_result_valid = 1'b1;
            matcher_result_kind  = result_kind;
            matcher_pair_equal   = pair_equal;

            @(negedge clk);
            matcher_result_valid = 1'b0;
            matcher_result_kind  = NONE;
            matcher_pair_equal   = 1'b0;
        end
    endtask

    // 채널별 Local Fail을 1클럭 동안 입력한다.
    task send_local_fail;
        input fail_a;
        input fail_b;
        begin
            @(negedge clk);
            a_local_fail_event = fail_a;
            b_local_fail_event = fail_b;

            @(negedge clk);
            a_local_fail_event = 1'b0;
            b_local_fail_event = 1'b0;
        end
    endtask

    task check_state;
        input       expected_a_fault;
        input       expected_b_fault;
        input [7:0] expected_a_fail_count;
        input [7:0] expected_b_fail_count;
        input [7:0] expected_a_recover_count;
        input [7:0] expected_b_recover_count;
        input       expected_a_fault_pulse;
        input       expected_b_fault_pulse;
        input       expected_a_recover_pulse;
        input       expected_b_recover_pulse;
        begin
            #1;

            if ((a_fault             !== expected_a_fault)         ||
                (b_fault             !== expected_b_fault)         ||
                (a_fail_count        !== expected_a_fail_count)    ||
                (b_fail_count        !== expected_b_fail_count)    ||
                (a_recover_count     !== expected_a_recover_count) ||
                (b_recover_count     !== expected_b_recover_count) ||
                (a_fault_enter_pulse !== expected_a_fault_pulse)   ||
                (b_fault_enter_pulse !== expected_b_fault_pulse)   ||
                (a_recovered_pulse   !== expected_a_recover_pulse) ||
                (b_recovered_pulse   !== expected_b_recover_pulse)) begin

                error_count = error_count + 1;

                $display(
                    "[FAIL] time=%0t fault=%b%b fail=%0d/%0d recover=%0d/%0d",
                    $time,
                    a_fault,
                    b_fault,
                    a_fail_count,
                    b_fail_count,
                    a_recover_count,
                    b_recover_count
                );
            end
        end
    endtask

    task apply_reset;
        begin
            reset_p = 1'b1;
            repeat (2) @(negedge clk);
            reset_p = 1'b0;
            @(negedge clk);
        end
    endtask

    initial begin
        reset_p               = 1'b1;
        matcher_result_valid  = 1'b0;
        matcher_result_kind   = NONE;
        matcher_pair_equal    = 1'b0;
        a_local_fail_event    = 1'b0;
        b_local_fail_event    = 1'b0;
        error_count           = 0;
        test_index            = 0;

        // ---------------------------------------------------------------------
        // 1. 연속 Fail만 세며, 중간 Good이 들어오면 Count를 초기화한다.
        // ---------------------------------------------------------------------
        apply_reset;

        send_matcher_result(PAIR, 1'b0);
        check_state(
            1'b0, 1'b0, 8'd1, 8'd1, 8'd0, 8'd0,
            1'b0, 1'b0, 1'b0, 1'b0
        );

        send_matcher_result(PAIR, 1'b0);
        check_state(
            1'b0, 1'b0, 8'd2, 8'd2, 8'd0, 8'd0,
            1'b0, 1'b0, 1'b0, 1'b0
        );

        send_matcher_result(PAIR, 1'b1);
        check_state(
            1'b0, 1'b0, 8'd0, 8'd0, 8'd0, 8'd0,
            1'b0, 1'b0, 1'b0, 1'b0
        );

        // ---------------------------------------------------------------------
        // 2. Pair 불일치가 연속 3회이면 A/B 모두 Fault
        // ---------------------------------------------------------------------
        for (test_index = 0; test_index < 3; test_index = test_index + 1)
            send_matcher_result(PAIR, 1'b0);

        check_state(
            1'b1, 1'b1, 8'd3, 8'd3, 8'd0, 8'd0,
            1'b1, 1'b1, 1'b0, 1'b0
        );

        // ---------------------------------------------------------------------
        // 3. Single 결과로는 복구되지 않으며 정상 Pair 5회가 필요하다.
        // ---------------------------------------------------------------------
        send_matcher_result(SINGLE_A, 1'b0);
        check_state(
            1'b1, 1'b1, 8'd3, 8'd3, 8'd0, 8'd0,
            1'b0, 1'b0, 1'b0, 1'b0
        );

        for (test_index = 0; test_index < 4; test_index = test_index + 1)
            send_matcher_result(PAIR, 1'b1);

        check_state(
            1'b1, 1'b1, 8'd3, 8'd3, 8'd4, 8'd4,
            1'b0, 1'b0, 1'b0, 1'b0
        );

        send_matcher_result(PAIR, 1'b1);
        check_state(
            1'b0, 1'b0, 8'd0, 8'd0, 8'd0, 8'd0,
            1'b0, 1'b0, 1'b1, 1'b1
        );

        // ---------------------------------------------------------------------
        // 4. Single A가 연속 3회이면 B 누락으로 B만 Fault
        // ---------------------------------------------------------------------
        apply_reset;

        for (test_index = 0; test_index < 3; test_index = test_index + 1)
            send_matcher_result(SINGLE_A, 1'b0);

        check_state(
            1'b0, 1'b1, 8'd0, 8'd3, 8'd0, 8'd0,
            1'b0, 1'b1, 1'b0, 1'b0
        );

        // ---------------------------------------------------------------------
        // 5. A Local Fail이 연속 3회이면 A만 Fault
        // ---------------------------------------------------------------------
        apply_reset;

        for (test_index = 0; test_index < 3; test_index = test_index + 1)
            send_local_fail(1'b1, 1'b0);

        check_state(
            1'b1, 1'b0, 8'd3, 8'd0, 8'd0, 8'd0,
            1'b1, 1'b0, 1'b0, 1'b0
        );

        if (error_count == 0)
            $display("[PASS] All channel_health_mgr core tests passed.");
        else
            $display("[FAIL] error_count=%0d", error_count);

        $finish;
    end

    // 무한 시뮬레이션 방지
    initial begin
        #3000;
        $display("[FAIL] Simulation timeout");
        $finish;
    end

endmodule