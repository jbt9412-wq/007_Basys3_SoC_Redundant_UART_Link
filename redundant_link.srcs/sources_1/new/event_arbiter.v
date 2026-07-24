`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// event_arbiter
//
// 역할
//   여러 RTL 블록에서 같은 클럭에 발생한 Event를 소스별 Pending Slot에
//   보관하고, 한 번에 1개의 64-bit Event를 event_fifo로 전달한다.
//
// 입력 배치
//   source_valid[N]                  : Source N의 1클럭 Event Pulse
//   source_data[N*64 +: 64]          : Source N의 Event Record
//
// 출력 Handshake
//   event_valid && event_ready인 상승 에지에서 Event 1개가 전달된다.
//   event_ready=0이면 event_valid/event_data를 그대로 유지한다.
//
// 우선순위
//   번호가 작은 Source가 높은 우선순위를 가진다.
//   예: Source 0 > Source 1 > Source 2 ...
//
// Event 유실 조건
//   서로 다른 Source에서 동시에 발생한 Event는 각 Pending Slot에 저장된다.
//   단, 아직 처리되지 않은 Source에 같은 Source의 Event가 다시 들어오면
//   새 Event를 저장할 공간이 없으므로 새 Event를 버리고 event_lost_pulse를
//   발생시킨다. 기존 Pending Event는 보존한다.
//
// 중요
//   Source별 Event는 1클럭 Pulse여야 한다.
//   64-bit Event Record의 내부 필드 형식은 redundant_link_core에서 정한다.
//////////////////////////////////////////////////////////////////////////////////

module event_arbiter #(
    parameter integer SOURCE_COUNT = 8,
    parameter integer EVENT_WIDTH  = 64
)(
    input  wire                              clk,
    input  wire                              reset_p,

    // 여러 Event Source의 입력
    input  wire [SOURCE_COUNT-1:0]            source_valid,
    input  wire [(SOURCE_COUNT*EVENT_WIDTH)-1:0] source_data,

    // event_fifo와 연결되는 출력
    output wire                              event_valid,
    input  wire                              event_ready,
    output reg  [EVENT_WIDTH-1:0]             event_data,

    // 상태 및 진단
    output wire                              pending_any,
    output reg  [7:0]                        pending_count,
    output reg                               event_lost_pulse,
    output reg  [15:0]                       event_lost_count
);

    localparam integer INDEX_WIDTH =
        (SOURCE_COUNT <= 1) ? 1 : $clog2(SOURCE_COUNT);

    // Source마다 Event 1개를 보관한다.
    reg [SOURCE_COUNT-1:0] pending_valid;
    reg [EVENT_WIDTH-1:0]  pending_data [0:SOURCE_COUNT-1];

    reg                   selected_valid;
    reg [INDEX_WIDTH-1:0] selected_index;

    reg [15:0] lost_this_cycle;

    wire event_fire;

    integer select_index;
    integer count_index;
    integer lost_index;
    integer update_index;

    // -------------------------------------------------------------------------
    // 가장 높은 우선순위의 Pending Event 선택
    // -------------------------------------------------------------------------
    always @(*) begin
        selected_valid = 1'b0;
        selected_index = {INDEX_WIDTH{1'b0}};
        event_data     = {EVENT_WIDTH{1'b0}};

        for (select_index = 0;
             select_index < SOURCE_COUNT;
             select_index = select_index + 1) begin

            if (!selected_valid && pending_valid[select_index]) begin
                selected_valid = 1'b1;
                selected_index = select_index;
                event_data     = pending_data[select_index];
            end
        end
    end

    assign event_valid = selected_valid;
    assign event_fire  = selected_valid && event_ready;
    assign pending_any = |pending_valid;

    // -------------------------------------------------------------------------
    // 현재 Pending Event 수
    // -------------------------------------------------------------------------
    always @(*) begin
        pending_count = 8'd0;

        for (count_index = 0;
             count_index < SOURCE_COUNT;
             count_index = count_index + 1) begin

            if (pending_valid[count_index])
                pending_count = pending_count + 1'b1;
        end
    end

    // -------------------------------------------------------------------------
    // 이번 클럭에 저장하지 못하는 동일 Source Event 수
    //
    // 기존 Pending Event가 이번 클럭에 FIFO로 전달되면 같은 Source의
    // 새 Event가 즉시 그 Slot을 이어받을 수 있으므로 유실이 아니다.
    // -------------------------------------------------------------------------
    always @(*) begin
        lost_this_cycle = 16'd0;

        for (lost_index = 0;
             lost_index < SOURCE_COUNT;
             lost_index = lost_index + 1) begin

            if (source_valid[lost_index] &&
                pending_valid[lost_index] &&
                !(event_fire && (selected_index == lost_index))) begin

                lost_this_cycle = lost_this_cycle + 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Pending Slot 갱신
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            pending_valid   <= {SOURCE_COUNT{1'b0}};
            event_lost_pulse <= 1'b0;
            event_lost_count <= 16'd0;

            // pending_valid=0이므로 Pending Data 자체는 Reset하지 않는다.
        end
        else begin
            event_lost_pulse <= 1'b0;

            if (lost_this_cycle != 0) begin
                event_lost_pulse <= 1'b1;

                // 유실 횟수는 최대값에서 포화시킨다.
                if (event_lost_count >= (16'hFFFF - lost_this_cycle))
                    event_lost_count <= 16'hFFFF;
                else
                    event_lost_count <=
                        event_lost_count + lost_this_cycle;
            end

            for (update_index = 0;
                 update_index < SOURCE_COUNT;
                 update_index = update_index + 1) begin

                if (event_fire && (selected_index == update_index)) begin
                    if (source_valid[update_index]) begin
                        // 기존 Event를 전달한 클럭에 같은 Source의 새 Event가
                        // 들어오면 Slot을 비우지 않고 새 Event로 교체한다.
                        pending_valid[update_index] <= 1'b1;
                        pending_data[update_index]  <=
                            source_data[(update_index*EVENT_WIDTH)
                                        +: EVENT_WIDTH];
                    end
                    else begin
                        pending_valid[update_index] <= 1'b0;
                    end
                end
                else if (source_valid[update_index] &&
                         !pending_valid[update_index]) begin

                    pending_valid[update_index] <= 1'b1;
                    pending_data[update_index]  <=
                        source_data[(update_index*EVENT_WIDTH)
                                    +: EVENT_WIDTH];
                end
                // Pending Slot이 찬 상태에서 같은 Source Event가 재발생하면
                // 기존 Event를 보존하고 위의 lost 카운터만 증가시킨다.
            end
        end
    end

endmodule