`default_nettype none

module ChipInterface (
  input  logic clk_25mhz,
  input  logic ftdi_txd,
  input  logic [6:0] btn,
  output logic [27:0] gp,
  output logic [27:0] gn,
  output logic ftdi_rxd,
  output logic [7:0] led
);

  logic rst_n;
  logic clk;
  logic data_valid;
  logic error;
  logic [7:0] data;

  assign rst_n = ~btn[5];
  assign clk = clk_25mhz;
  assign gp[27] = ftdi_txd;

  always_ff @(posedge clk) begin
    if (~rst_n)
      led <= '0;
    else if (data_valid)
      led <= data;
    else if (error)
      led <= 8'h55;
  end

  UART_RX #(
    .CLK_FREQ(25_000_000),
    .BAUD_RATE(115_200),
    .DATA_BITS(5)
  ) DUT (
    .clk,
    .rst_n,
    .serial(ftdi_txd),
    .error,
    .data_valid,
    .data
  );

endmodule : ChipInterface
