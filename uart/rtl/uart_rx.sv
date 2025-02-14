`default_nettype none

/*
 *  Parity Type:
 *  SPACE: 0
 *  MARK:  1
 *  EVEN:  2
 *  ODD:   3
 */

// `define PARITY_BIT 3
// `define TWO_STOP_BITS

module UART_RX #(
  parameter CLK_FREQ  = 25_000_000,
  parameter BAUD_RATE = 115_200,
  parameter DATA_BITS = 8
  ) (
  input  logic clk,
  input  logic rst_n,
  input  logic serial,
  output logic error,
  output logic data_valid,
  output logic [DATA_BITS-1:0] data
);

  localparam CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
  localparam CYCLE_CNT_SIZE = $clog2(CYCLES_PER_BIT);
  localparam DATA_IND_SIZE = $clog2(DATA_BITS);

  `ifdef PARITY_BIT
    localparam PARITY_TYPE = `PARITY_BIT;
    logic parity_ff;
    enum logic [2:0] {IDLE,
                      START,
                      DATA,
                      PARITY,
                      STOP} state;
  `else
    enum logic [1:0] {IDLE,
                      START,
                      DATA,
                      STOP} state;
  `endif

  `ifdef TWO_STOP_BITS
    logic stop_cnt;
  `endif

  logic [CYCLE_CNT_SIZE-1:0] cycle_cnt;
  logic [DATA_IND_SIZE-1:0] data_ind;

  logic sample;
  logic full_bit;
  logic data_done;

  assign sample = cycle_cnt == (CYCLES_PER_BIT / 2);
  assign full_bit = cycle_cnt == CYCLES_PER_BIT;
  assign data_done = data_ind == (DATA_BITS - 1);

  // ---------------------
  // --- parity logic ----
  // ---------------------
  `ifdef PARITY_BIT
    always_ff @(posedge clk) begin
      if ((PARITY_TYPE == 2) || (PARITY_TYPE == 3)) begin
        if (~rst_n)
          parity_ff <= '0;
        else if (state == IDLE)
          parity_ff <= '0;
        else if ((state == DATA) & sample)
          parity_ff <= parity_ff ^ serial;
        else if ((state == PARITY) & sample)
          parity_ff <= parity_ff ^ serial;
      end
    end
  `endif

  // --------------------
  // --- error logic ----
  // --------------------
  always_ff @(posedge clk) begin
    if (~rst_n)
      error <= '0;
    else if ((state == IDLE) & ~serial)
      error <= '0;
    else if ((state == START) & sample & serial)
      error <= 1'b1;
    `ifdef PARITY_BIT
      else if (state == PARITY)
        case (PARITY_TYPE)
          2'd0: begin
            if (sample & serial)
              error <= 1'b1;
          end
          2'd1: begin
            if (sample & ~serial)
              error <= 1'b1;
          end
          2'd2: begin
            if (full_bit & parity_ff)
              error <= 1'b1;
          end
          2'd3: begin
            if (full_bit & ~parity_ff)
              error <= 1'b1;
          end
        endcase
    `endif
    else if ((state == STOP) & sample & ~serial)
      error <= 1'b1;
  end

  // -----------------------
  // --- stop_cnt logic ----
  // -----------------------
  `ifdef TWO_STOP_BITS
    always_ff @(posedge clk) begin
      if (~rst_n)
        stop_cnt <= '0;
      else if (state == IDLE)
        stop_cnt <= '0;
      else if ((state == STOP) & full_bit)
        stop_cnt <= 1'b1;
    end
  `endif

  // -------------------------
  // --- data_valid logic ----
  // -------------------------
  always_ff @(posedge clk) begin
    if (~rst_n)
      data_valid <= '0;
    else if ((state == IDLE) & ~serial)
      data_valid <= '0;
    `ifdef TWO_STOP_BITS
      else if ((state == STOP) & stop_cnt & full_bit)
        data_valid <= 1'b1;
    `else
      else if ((state == STOP) & full_bit)
        data_valid <= 1'b1;
    `endif
  end

  // ------------------------
  // --- cycle_cnt logic ----
  // ------------------------
  always_ff @(posedge clk) begin
    if (~rst_n)
      cycle_cnt <= '0;
    else if ((state == IDLE) | full_bit)
      cycle_cnt <= '0;
    else
      cycle_cnt <= cycle_cnt + 1'b1;
  end

  // -----------------------
  // --- data_ind logic ----
  // -----------------------
  always_ff @(posedge clk) begin
    if (~rst_n)
      data_ind <= '0;
    else if (state == IDLE)
      data_ind <= '0;
    else if ((state == DATA) & full_bit)
      data_ind <= data_ind + 1'b1;
  end

  // -------------------
  // --- data logic ----
  // -------------------
  always_ff @(posedge clk) begin
    if (~rst_n)
      data <= '0;
    else if ((state == DATA) & sample)
      data[data_ind] <= serial;
  end

  // -------------------------
  // --- state logic ----
  // -------------------------
  always_ff @(posedge clk) begin
    if (~rst_n)
      state <= IDLE;

    case (state)
      IDLE: begin
        state <= (~serial) ? START : IDLE;
      end
      START: begin
        if (error)
          state <= IDLE;
        else if (full_bit)
          state <= DATA;
        else
          state <= START;
      end
      DATA: begin
        `ifdef PARITY_BIT
          state <= (data_done & full_bit) ? PARITY : DATA;
        `else
          state <= (data_done & full_bit) ? STOP : DATA;
        `endif
      end
      `ifdef PARITY_BIT
        PARITY: begin
          if (error)
            state <= IDLE;
          else if (full_bit)
            state <= STOP;
          else
            state <= PARITY;
        end
      `endif
      STOP: begin
        `ifdef TWO_STOP_BITS
          if (error)
            state <= IDLE;
          else if (stop_cnt & full_bit)
            state <= IDLE;
          else
            state <= STOP;
        `else
          if (error)
            state <= IDLE;
          else if (full_bit)
            state <= IDLE;
          else
            state <= STOP;
        `endif
      end
      default: begin
        state <= IDLE;
      end
    endcase
  end

endmodule : UART_RX
