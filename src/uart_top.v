`default_nettype none //

module uart_top #(
    parameter WIDTH = 8
)(
    input  wire clk,
    input  wire clk_sel,
    input  wire rstn,
    input  wire tr_en,
    input  wire mode_osl,
    input  wire [15:0] dlh_dll,
    input  wire [6:0] tr_fifo_data_w,
    input  wire rx_data_in,
    output wire tx_data_out,
    output wire [7:0] rx_data_read_out,
    input  wire rx_data_read_en,
    input  wire tx_data_w_en,
    output wire transmit_busy,
    output wire tx_i_interpt,
    output wire rx_i_interpt,
    output wire tx_o_interpt,
    output wire rx_o_interpt,
    input  wire tr_data_load
);

    // Internal signals
    reg [7:0] rx_data_reg;
    reg [7:0] tx_data_reg;
    reg [3:0] tx_bit_counter;
    reg [3:0] rx_bit_counter;
    reg [15:0] baud_counter;
    reg [15:0] baud_limit;
    reg tx_active;
    reg rx_active;
    reg tx_line_reg;
    reg rx_data_ready;
    reg tx_fifo_empty;
    reg rx_fifo_full;
    
    // State machine states
    localparam IDLE = 2'b00;
    localparam START = 2'b01;
    localparam DATA = 2'b10;
    localparam STOP = 2'b11;
    
    reg [1:0] tx_state;
    reg [1:0] rx_state;
    reg [1:0] rx_state_prev;

    // Baud rate generation
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            baud_counter <= 0;
            baud_limit <= dlh_dll;
        end else begin
            if (clk_sel) begin
                baud_limit <= 16'h0001; // Full clock rate
            end else begin
                baud_limit <= dlh_dll;  // Divided clock rate
            end
            
            if (baud_counter >= baud_limit) begin
                baud_counter <= 0;
            end else begin
                baud_counter <= baud_counter + 1;
            end
        end
    end

    wire baud_tick = (baud_counter == baud_limit);

    // TX State Machine
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            tx_state <= IDLE;
            tx_bit_counter <= 0;
            tx_line_reg <= 1'b1;
            tx_active <= 1'b0;
            tx_data_reg <= 8'h00;
        end else if (baud_tick) begin
            case (tx_state)
                IDLE: begin
                    tx_line_reg <= 1'b1;
                    tx_active <= 1'b0;
                    if (tr_en && tx_data_w_en && tr_data_load) begin
                        tx_data_reg <= {tr_fifo_data_w, 1'b0}; // Load 7 bits + padding
                        tx_state <= START;
                        tx_active <= 1'b1;
                        tx_bit_counter <= 0;
                    end
                end
                
                START: begin
                    tx_line_reg <= 1'b0; // Start bit
                    tx_state <= DATA;
                    tx_bit_counter <= 0;
                end
                
                DATA: begin
                    tx_line_reg <= tx_data_reg[tx_bit_counter];
                    if (tx_bit_counter == 7) begin
                        tx_state <= STOP;
                    end else begin
                        tx_bit_counter <= tx_bit_counter + 1;
                    end
                end
                
                STOP: begin
                    tx_line_reg <= 1'b1; // Stop bit
                    tx_state <= IDLE;
                    tx_active <= 1'b0;
                end
            endcase
        end
    end

    // RX State Machine
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rx_state <= IDLE;
            rx_state_prev <= IDLE;
            rx_bit_counter <= 0;
            rx_data_reg <= 8'h00;
            rx_active <= 1'b0;
            rx_data_ready <= 1'b0;
        end else begin
            rx_state_prev <= rx_state;
            
            if (baud_tick) begin
                case (rx_state)
                    IDLE: begin
                        rx_active <= 1'b0;
                        if (!rx_data_in) begin // Start bit detected
                            rx_state <= START;
                            rx_bit_counter <= 0;
                        end
                    end
                    
                    START: begin
                        if (!rx_data_in) begin // Confirm start bit
                            rx_state <= DATA;
                            rx_bit_counter <= 0;
                            rx_active <= 1'b1;
                        end else begin
                            rx_state <= IDLE; // False start
                        end
                    end
                    
                    DATA: begin
                        rx_data_reg[rx_bit_counter] <= rx_data_in;
                        if (rx_bit_counter == 7) begin
                            rx_state <= STOP;
                        end else begin
                            rx_bit_counter <= rx_bit_counter + 1;
                        end
                    end
                    
                    STOP: begin
                        if (rx_data_in) begin // Valid stop bit
                            rx_data_ready <= 1'b1;
                        end
                        rx_state <= IDLE;
                        rx_active <= 1'b0;
                    end
                endcase
            end
            
            // Clear data ready flag when read
            if (rx_data_read_en) begin
                rx_data_ready <= 1'b0;
            end
        end
    end

    // Output assignments
    assign tx_data_out = tx_line_reg;
    assign rx_data_read_out = rx_data_reg;
    assign transmit_busy = tx_active;
    
    // Interrupt generation (simplified)
    assign tx_i_interpt = !tx_active && tr_en; // TX ready
    assign rx_i_interpt = rx_data_ready;       // RX data available
    assign tx_o_interpt = tx_active;           // TX in progress
    assign rx_o_interpt = rx_active;           // RX in progress

endmodule
