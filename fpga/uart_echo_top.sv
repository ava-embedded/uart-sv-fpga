// Top-level para FPGA: echo por UART a 9600 baudios (8N1).
// cada byte recibido por UART_RXD se reenvia por UART_TXD.
//
module uart_echo_top #(
    parameter int CLK_FREQ = 50_000_000,   // Hz: ajusta al reloj de tu placa
    parameter int BAUD     = 9600
) (
    input  logic CLOCK_50,    // reloj de la placa
    input  logic KEY0,        // reset, activo en bajo (boton presionado = 0)
    input  logic UART_RXD,    // viene del TX del adaptador USB-serial
    output logic UART_TXD     // va al RX del adaptador USB-serial
);

    localparam logic [10:0] DVSR = 11'(CLK_FREQ/(16*BAUD) - 1);  // 324 con 50 MHz

    // Sincronizador de 2 FF: rx llega de un dispositivo externo asincrono
    logic rx_meta, rx_sync;
    always_ff @(posedge CLOCK_50) begin
        rx_meta <= UART_RXD;
        rx_sync <= rx_meta;
    end

    logic [7:0] r_data;
    logic       rx_empty, tx_full;
    logic       wr_uart, rd_uart;

    // FIFO RX es FWFT, asi que r_data ya es el dato de la cabeza.
    // Se pasa a la FIFO TX y se saca de la FIFO RX en el mismo ciclo,
    // solo si hay dato y hay espacio en TX (para no perder bytes).
    assign wr_uart = ~rx_empty & ~tx_full;
    assign rd_uart = wr_uart;

    uart #(.FIFO_W(16)) uart_unit (
        .clk     (CLOCK_50),
        .rst_n   (KEY0),
        .rd_uart (rd_uart),
        .wr_uart (wr_uart),
        .rx      (rx_sync),
        .w_data  (r_data),
        .r_data  (r_data),
        .dvsr    (DVSR),
        .rx_empty(rx_empty),
        .tx_full (tx_full),
        .tx      (UART_TXD)
    );

endmodule