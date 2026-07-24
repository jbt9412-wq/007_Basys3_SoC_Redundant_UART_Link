`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// pair_matcher
//
// 역할
//   1. A/B FIFO Head의 SEQ를 비교한다.
//   2. 같은 SEQ면 프레임 내용을 비교하고 양쪽을 Pop한다.
//   3. SEQ가 다르면 오래된 프레임만 Single 후보로 전달하고 Pop한다.
//   4. 앞선 SEQ 프레임은 FIFO에 그대로 보관한다.
//   5. 한쪽만 존재하면 PAIR_TIMEOUT_CYCLES 동안 기다린 뒤 Single로 전달한다.
//
// result_kind
//   2'b00 : 결과 없음
//   2'b01 : A/B Pair
//   2'b10 : Single A
//   2'b11 : Single B
//
// mismatch_flags
//   bit 0 : LEN 불일치
//   bit 1 : DEVICE_ID 불일치
//   bit 2 : CMD 불일치
//   bit 3 : 유효 Payload 불일치
//
// 주의
//   result_valid와 pop_a/pop_b는 같은 클럭에서 사용한다.
//   다음 모듈은 result_valid=1인 클럭에서 out_*을 저장해야 한다.
//////////////////////////////////////////////////////////////////////////////////

module pair_matcher #(
    // 100MHz 기준 1,000,000 Clock = 10ms
    parameter integer PAIR_TIMEOUT_CYCLES = 1_000_000,
    parameter integer TIMEOUT_COUNT_WIDTH = 20
)(
    input  wire         clk,
    input  wire         reset_p,

    // -------------------------------------------------------------------------
    // Channel A FIFO Head
    // -------------------------------------------------------------------------
    input  wire         a_empty,
    input  wire [7:0]   a_frame_length,
    input  wire [7:0]   a_device_id,
    input  wire [7:0]   a_command,
    input  wire [7:0]   a_sequence,
    input  wire [127:0] a_payload_data,
    input  wire [15:0]  a_received_crc,
    input  wire         a_seq_gap,

    // -------------------------------------------------------------------------
    // Channel B FIFO Head
    // -------------------------------------------------------------------------
    input  wire         b_empty,
    input  wire [7:0]   b_frame_length,
    input  wire [7:0]   b_device_id,
    input  wire [7:0]   b_command,
    input  wire [7:0]   b_sequence,
    input  wire [127:0] b_payload_data,
    input  wire [15:0]  b_received_crc,
    input  wire         b_seq_gap,

    // -------------------------------------------------------------------------
    // FIFO Pop
    // -------------------------------------------------------------------------
    output wire         pop_a,
    output wire         pop_b,

    // -------------------------------------------------------------------------
    // 비교 결과
    // -------------------------------------------------------------------------
    output wire         result_valid,
    output wire [1:0]   result_kind,
    output wire         result_pair_equal,
    output wire [3:0]   mismatch_flags,

    // Single 발생 원인
    output wire         result_timeout,
    output wire         result_seq_skew,
    output wire         result_seq_ambiguous,

    // decision_unit에 전달할 대표 프레임
    // Pair일 때는 Channel A 프레임을 대표값으로 사용한다.
    output wire [7:0]   out_frame_length,
    output wire [7:0]   out_device_id,
    output wire [7:0]   out_command,
    output wire [7:0]   out_sequence,
    output wire [127:0] out_payload_data,
    output wire [15:0]  out_received_crc,
    output wire         out_seq_gap
);

    localparam [1:0] RESULT_NONE     = 2'b00;
    localparam [1:0] RESULT_PAIR     = 2'b01;
    localparam [1:0] RESULT_SINGLE_A = 2'b10;
    localparam [1:0] RESULT_SINGLE_B = 2'b11;

    // -------------------------------------------------------------------------
    // FIFO 상태
    // -------------------------------------------------------------------------
    wire only_a;
    wire only_b;
    wire both_present;
    wire same_sequence;

    assign only_a        = !a_empty &&  b_empty;
    assign only_b        =  a_empty && !b_empty;
    assign both_present  = !a_empty && !b_empty;
    assign same_sequence = both_present &&
                           (a_sequence == b_sequence);

    // -------------------------------------------------------------------------
    // 한쪽 프레임만 존재할 때 사용하는 Pair Timeout
    // -------------------------------------------------------------------------
    reg [TIMEOUT_COUNT_WIDTH-1:0] timeout_count;

    wire timeout_reached;

    assign timeout_reached =
        (PAIR_TIMEOUT_CYCLES <= 1) ? 1'b1 :
        (timeout_count >= PAIR_TIMEOUT_CYCLES - 1);

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            timeout_count <= {TIMEOUT_COUNT_WIDTH{1'b0}};
        end
        else begin
            if (only_a || only_b) begin
                if (timeout_reached)
                    timeout_count <= {TIMEOUT_COUNT_WIDTH{1'b0}};
                else
                    timeout_count <= timeout_count + 1'b1;
            end
            else begin
                // 양쪽 모두 Empty, 양쪽 모두 존재 또는 SEQ 정렬 처리 시 초기화
                timeout_count <= {TIMEOUT_COUNT_WIDTH{1'b0}};
            end
        end
    end

    // -------------------------------------------------------------------------
    // Sequence 순서 비교
    //
    // b_sequence - a_sequence가:
    //   1~127   : B가 앞섬 → A가 오래됨
    //   129~255 : A가 앞섬 → B가 오래됨
    //   128     : 정확한 순서를 판단할 수 없는 반주기 차이
    //
    // 128 차이는 정상 운용에서 발생하지 않아야 한다.
    // 교착 방지를 위해 A를 오래된 쪽으로 처리하고 별도 표시한다.
    // -------------------------------------------------------------------------
    wire [7:0] sequence_distance;
    wire       a_is_older;
    wire       b_is_older;
    wire       sequence_ambiguous;

    assign sequence_distance  = b_sequence - a_sequence;

    assign sequence_ambiguous =
        both_present &&
        !same_sequence &&
        (sequence_distance == 8'h80);

    assign a_is_older =
        both_present &&
        !same_sequence &&
        (sequence_distance <= 8'h80);

    assign b_is_older =
        both_present &&
        !same_sequence &&
        (sequence_distance > 8'h80);

    // -------------------------------------------------------------------------
    // 유효 Payload Byte Mask
    //
    // LEN = DEVICE_ID + CMD + SEQ + PAYLOAD
    // Payload Byte 수 = LEN - 3
    // -------------------------------------------------------------------------
    reg [127:0] a_payload_mask;
    reg [127:0] b_payload_mask;

    integer byte_index;

    always @(*) begin
        a_payload_mask = 128'd0;
        b_payload_mask = 128'd0;

        for (byte_index = 0;
             byte_index < 16;
             byte_index = byte_index + 1) begin

            if ((a_frame_length > 8'd3) &&
                (byte_index < (a_frame_length - 8'd3)))
                a_payload_mask[byte_index*8 +: 8] = 8'hFF;

            if ((b_frame_length > 8'd3) &&
                (byte_index < (b_frame_length - 8'd3)))
                b_payload_mask[byte_index*8 +: 8] = 8'hFF;
        end
    end

    wire frame_length_equal;
    wire device_id_equal;
    wire command_equal;
    wire payload_equal;

    assign frame_length_equal =
        (a_frame_length == b_frame_length);

    assign device_id_equal =
        (a_device_id == b_device_id);

    assign command_equal =
        (a_command == b_command);

    // 각 채널의 유효 Payload 영역만 비교한다.
    assign payload_equal =
        ((a_payload_data & a_payload_mask) ==
         (b_payload_data & b_payload_mask));

    // -------------------------------------------------------------------------
    // 이번 클럭에 수행할 동작
    // -------------------------------------------------------------------------
    wire action_pair;

    wire action_single_a_timeout;
    wire action_single_b_timeout;

    wire action_single_a_skew;
    wire action_single_b_skew;

    wire action_single_a;
    wire action_single_b;

    assign action_pair = same_sequence;

    assign action_single_a_timeout =
        only_a && timeout_reached;

    assign action_single_b_timeout =
        only_b && timeout_reached;

    // 양쪽 Head가 있지만 SEQ가 다르면 오래된 쪽만 처리한다.
    assign action_single_a_skew = a_is_older;
    assign action_single_b_skew = b_is_older;

    assign action_single_a =
        action_single_a_timeout ||
        action_single_a_skew;

    assign action_single_b =
        action_single_b_timeout ||
        action_single_b_skew;

    // -------------------------------------------------------------------------
    // FIFO Pop
    //
    // Pair          : A/B 모두 Pop
    // Single A      : A만 Pop
    // Single B      : B만 Pop
    // -------------------------------------------------------------------------
    assign pop_a = action_pair || action_single_a;
    assign pop_b = action_pair || action_single_b;

    // -------------------------------------------------------------------------
    // 결과 종류
    // -------------------------------------------------------------------------
    assign result_valid =
        action_pair ||
        action_single_a ||
        action_single_b;

    assign result_kind =
        action_pair     ? RESULT_PAIR     :
        action_single_a ? RESULT_SINGLE_A :
        action_single_b ? RESULT_SINGLE_B :
                          RESULT_NONE;

    // -------------------------------------------------------------------------
    // Pair 비교 결과
    // -------------------------------------------------------------------------
    assign mismatch_flags[0] =
        action_pair && !frame_length_equal;

    assign mismatch_flags[1] =
        action_pair && !device_id_equal;

    assign mismatch_flags[2] =
        action_pair && !command_equal;

    assign mismatch_flags[3] =
        action_pair && !payload_equal;

    assign result_pair_equal =
        action_pair &&
        frame_length_equal &&
        device_id_equal &&
        command_equal &&
        payload_equal;

    // -------------------------------------------------------------------------
    // Single 발생 원인
    // -------------------------------------------------------------------------
    assign result_timeout =
        action_single_a_timeout ||
        action_single_b_timeout;

    assign result_seq_skew =
        action_single_a_skew ||
        action_single_b_skew;

    assign result_seq_ambiguous =
        sequence_ambiguous &&
        action_single_a_skew;

    // -------------------------------------------------------------------------
    // 대표 프레임 출력
    //
    // Pair 또는 Single A : A 프레임
    // Single B           : B 프레임
    // -------------------------------------------------------------------------
    assign out_frame_length =
        action_single_b ? b_frame_length :
        (result_valid ? a_frame_length : 8'd0);

    assign out_device_id =
        action_single_b ? b_device_id :
        (result_valid ? a_device_id : 8'd0);

    assign out_command =
        action_single_b ? b_command :
        (result_valid ? a_command : 8'd0);

    assign out_sequence =
        action_single_b ? b_sequence :
        (result_valid ? a_sequence : 8'd0);

    assign out_payload_data =
        action_single_b ? b_payload_data :
        (result_valid ? a_payload_data : 128'd0);

    assign out_received_crc =
        action_single_b ? b_received_crc :
        (result_valid ? a_received_crc : 16'd0);

    // Pair라면 두 채널 중 하나라도 Gap이 있었는지 전달한다.
    assign out_seq_gap =
        action_pair     ? (a_seq_gap || b_seq_gap) :
        action_single_a ? a_seq_gap :
        action_single_b ? b_seq_gap :
                          1'b0;

endmodule