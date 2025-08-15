`default_nettype none
`timescale 1ns / 1ps

/*
 * This testbench instantiates the tt_um_uart module
 * and defines convenient signals for use in the cocotb Python test (test.py).
 */

module tb ();

  // Generate VCD dump for waveform viewing
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Clock and reset
  reg clk;
  reg rst_n;
  reg ena;

  // 8-bit I/O signals (as per Tiny Tapeout specification)
  reg  [7:0] ui_in;     // Control inputs (e.g., tr_en, clk_sel, etc.)
  reg  [7:0] uio_in;    // IO inputs (e.g., rx_data_in, tr_fifo_data_w)
  wire [7:0] uo_out;    // Received data output (rx_data_read_out)
  wire [7:0] uio_out;   // Output bus (tx_line, interrupts, busy)
  wire [7:0] uio_oe;    // Output enables

  // Instantiate your UART design (renamed to match Tiny Tapeout naming)
  tt_um_uart user_project (
      .ui_in   (ui_in),
      .uo_out  (uo_out),
      .uio_in  (uio_in),
      .uio_out (uio_out),
      .uio_oe  (uio_oe),
      .ena     (ena),
      .clk     (clk),
      .rst_n   (rst_n)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;  // 100 MHz clock (10ns period)

endmodule
