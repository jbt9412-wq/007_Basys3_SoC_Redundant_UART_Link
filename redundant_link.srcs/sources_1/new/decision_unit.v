`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// decision_unit
//
// pair_matcher의 판정 결과를 최종 출력 프레임으로 변환한다.
//
// 정책
//   Pair + 내용 일치 : 채택
//   Pair + 내용 불일치: 폐기 (어느 채널이 맞는지 판단할 근거가 없음)
//   Single A/B       : 채택하되 degraded=1로 표시
//
// decision_valid는 입력 결과 하나당 1클럭 펄스이다.
// decision_accept=1인 경우에만 out_* 프레임이 유효하다.
//////////////////////////////////////////////////////////////////////////////////

module decision_unit (
    input  wire         clk,
    input  wire         reset_p,

    input  wire         result_valid,
    input  wire [1:0]   result_kind,
    input  wire         result_pair_equal,
    input  wire [3:0]   mismatch_flags,

    input  wire [7:0]   in_frame_length,
    input  wire [7:0]   in_device_id,
    input  wire [7:0]   in_command,
    input  wire [7:0]   in_sequence,
    input  wire [127:0] in_payload_data,
    input  wire [15:0]  in_received_crc,
    input  wire         in_seq_gap,

    output reg          decision_valid,
    output reg          decision_accept,
    output reg  [1:0]   decision_kind,
    output reg          decision_degraded,
    output reg  [3:0]   decision_mismatch_flags,

    output reg  [7:0]   out_frame_length,
    output reg  [7:0]   out_device_id,
    output reg  [7:0]   out_command,
    output reg  [7:0]   out_sequence,
    output reg  [127:0] out_payload_data,
    output reg  [15:0]  out_received_crc,
    output reg          out_seq_gap
);

    localparam [1:0] RESULT_NONE     = 2'b00;
    localparam [1:0] RESULT_PAIR     = 2'b01;
    localparam [1:0] RESULT_SINGLE_A = 2'b10;
    localparam [1:0] RESULT_SINGLE_B = 2'b11;

    wire accept_result;
    wire single_result;

    assign single_result =
        (result_kind == RESULT_SINGLE_A) ||
        (result_kind == RESULT_SINGLE_B);

    assign accept_result =
        ((result_kind == RESULT_PAIR) && result_pair_equal) ||
        single_result;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            decision_valid          <= 1'b0;
            decision_accept         <= 1'b0;
            decision_kind           <= RESULT_NONE;
            decision_degraded       <= 1'b0;
            decision_mismatch_flags <= 4'b0000;
            out_frame_length        <= 8'd0;
            out_device_id           <= 8'd0;
            out_command             <= 8'd0;
            out_sequence            <= 8'd0;
            out_payload_data        <= 128'd0;
            out_received_crc        <= 16'd0;
            out_seq_gap             <= 1'b0;
        end
        else begin
            // 기본값: 모든 판정 신호는 1클럭 펄스
            decision_valid          <= 1'b0;
            decision_accept         <= 1'b0;
            decision_kind           <= RESULT_NONE;
            decision_degraded       <= 1'b0;
            decision_mismatch_flags <= 4'b0000;

            if (result_valid) begin
                decision_valid          <= 1'b1;
                decision_accept         <= accept_result;
                decision_kind           <= result_kind;
                decision_degraded       <= single_result;
                decision_mismatch_flags <=
                    (result_kind == RESULT_PAIR) ? mismatch_flags : 4'b0000;

                if (accept_result) begin
                    out_frame_length <= in_frame_length;
                    out_device_id    <= in_device_id;
                    out_command      <= in_command;
                    out_sequence     <= in_sequence;
                    out_payload_data <= in_payload_data;
                    out_received_crc <= in_received_crc;
                    out_seq_gap      <= in_seq_gap;
                end
                else begin
                    out_frame_length <= 8'd0;
                    out_device_id    <= 8'd0;
                    out_command      <= 8'd0;
                    out_sequence     <= 8'd0;
                    out_payload_data <= 128'd0;
                    out_received_crc <= 16'd0;
                    out_seq_gap      <= 1'b0;
                end
            end
        end
    end

endmodule
