`default_nettype none //

module tt_um_uart (
    input  wire [7:0] ui_in,     // control inputs
    output wire [7:0] uo_out,    // received data
    input  wire [7:0] uio_in,    // tx_data (bits 7:1), rx_data (bit 0)
    output wire [7:0] uio_out,   // tx line + interrupt flags
    output wire [7:0] uio_oe,    // output enable
    input  wire       ena,       // always 1
    input  wire       clk,       // main clock
    input  wire       rst_n      // active low reset
);

    // UART I/O wires
    wire tx_line;
    wire [7:0] rx_data;
    wire tx_i_int, rx_i_int, tx_o_int, rx_o_int, tr_busy;
    wire rx_we;

    // Output assignments
    assign uo_out       = rx_data;
    assign uio_out[0]   = tx_line;
    assign uio_out[1]   = tx_i_int;
    assign uio_out[2]   = rx_i_int;
    assign uio_out[3]   = tx_o_int;
    assign uio_out[4]   = rx_o_int;
    assign uio_out[5]   = tr_busy;
    assign uio_out[7:6] = 2'b00;

    assign uio_oe       = 8'b00111111; // uio_out[5:0] as outputs

    // Instantiate top UART module
    uart_top #(.WIDTH(8)) uart_inst (
        .clk(clk),
        .clk_sel(ui_in[2]),
        .rstn(rst_n),
        .tr_en(ui_in[0]),
        .mode_osl(ui_in[1]),
        .dlh_dll(16'h0020),               // fixed baud rate for Tiny Tapeout
        .tr_fifo_data_w(uio_in[7:1]),
        .rx_data_in(uio_in[0]),
        .tx_data_out(tx_line),
        .rx_data_read_out(rx_data),
        .rx_data_read_en(ui_in[5]),
        .tx_data_w_en(ui_in[3]),
        .transmit_busy(tr_busy),
        .tx_i_interpt(tx_i_int),
        .rx_i_interpt(rx_i_int),
        .tx_o_interpt(tx_o_int),
        .rx_o_interpt(rx_o_int),
        .tr_data_load(ui_in[4])
    );

endmodule
