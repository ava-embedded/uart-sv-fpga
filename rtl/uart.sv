module uart #(
    parameter   SB_TICK = 16,
                DBIT = 8,
                FIFO_W = 4
) (
    input  logic clk, rst_n, rd_uart, wr_uart, rx,
    input  logic [DBIT-1:0] w_data,
    input  logic [10:0] dvsr,
    output logic [DBIT-1:0] r_data,
    output logic rx_empty, tx_full, tx
);

    logic tick, rx_done_tick, tx_done_tick;
    logic tx_empty, tx_fifo_no_empty;
    logic [DBIT-1:0] tx_fifo_out, rx_data_out; 

    baud_gen baud_generator_unit (.*);

    uart_rx #(.DBIT(DBIT), .SB_TICK(SB_TICK)) uart_rx_unit (.*, .s_tick(tick), .dout(rx_data_out));

    uart_tx #(.DBIT(DBIT), .SB_TICK(SB_TICK)) uart_tx_unit (.*, .tx_start(tx_fifo_no_empty), .s_tick(tick), .din(tx_fifo_out));

    fifo #(.DATA_WIDTH(DBIT), .ADDR_DEPTH(FIFO_W)) fifo_rx_unit (.*, .rd(rd_uart), .wr(rx_done_tick), .empty(rx_empty), .full(), .r_data(r_data), .w_data(rx_data_out));

    fifo #(.DATA_WIDTH(DBIT), .ADDR_DEPTH(FIFO_W)) fifo_tx_unit (.*, .rd(tx_done_tick), .wr(wr_uart), .empty(tx_empty), .full(tx_full), .r_data(tx_fifo_out), .w_data(w_data));

    assign tx_fifo_no_empty = ~tx_empty;

endmodule