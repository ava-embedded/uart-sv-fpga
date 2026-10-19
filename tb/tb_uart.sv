`timescale 1ns/1ps

// Testbench sencillo de la UART en lazo cerrado (tx -> rx) a 9600 baudios.
module tb_uart;

    // ---------------- Parametros ----------------
    localparam int  CLK_FREQ   = 50_000_000;                 // Hz (ajusta a tu reloj)
    localparam int  BAUD       = 9600;
    localparam int  DVSR       = CLK_FREQ/(16*BAUD) - 1;     // 324 con 50 MHz
    localparam real CLK_PERIOD = 1.0e9/CLK_FREQ;             // ns

    localparam int  N_BYTES    = 4;

    // ---------------- Senales ----------------
    logic       clk = 0, rst_n = 0;
    logic       rd_uart = 0, wr_uart = 0;
    logic [7:0] w_data = 0, r_data = 0;
    logic       rx_empty, tx_full, tx;

    logic [7:0] sent [N_BYTES];
    logic [7:0] got  [N_BYTES];
    int         errors = 0;

    // ---------------- DUT (rx conectado a tx) ----------------
    uart #(.FIFO_W(16)) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .rd_uart (rd_uart),
        .wr_uart (wr_uart),
        .rx      (tx),          // lazo cerrado
        .w_data  (w_data),
        .r_data  (r_data),
        .dvsr    (11'(DVSR)),
        .rx_empty(rx_empty),
        .tx_full (tx_full),
        .tx      (tx)
    );

    // ---------------- Reloj ----------------
    always #(CLK_PERIOD/2) clk = ~clk;

    // ---------------- Tareas ----------------
    // Escribe un byte en la FIFO de TX
    task automatic send_byte(input logic [7:0] b);
        while (tx_full) @(negedge clk);
        @(negedge clk);
        w_data = b;  wr_uart = 1;
        @(negedge clk);
        wr_uart = 0;
    endtask

    // Lee un byte de la FIFO de RX (FWFT: el dato ya esta en r_data)
    task automatic recv_byte(output logic [7:0] b);
        while (rx_empty) @(negedge clk);
        b = r_data;
        rd_uart = 1;
        @(negedge clk);
        rd_uart = 0;
    endtask
    
    // ---------------- Monitor: mide el tiempo de bit en la linea tx ----------------
    // El primer byte es 0xA5 (LSB = 1), asi que el nivel bajo inicial dura
    // exactamente un bit (el bit de inicio).
    realtime t0, t1;
    initial begin
        @(posedge rst_n);
        repeat (5) @(posedge clk);
        @(negedge tx);  t0 = $realtime;
        @(posedge tx);  t1 = $realtime;
        $display("Bit de inicio: %0.2f us (esperado %0.2f us)",
                 (t1 - t0)/1000.0, 1.0e6/BAUD);
    end

    // ---------------- Secuencia principal ----------------
    initial begin
        sent[0] = 8'hA5;  sent[1] = 8'h3C;  sent[2] = 8'h7E;  sent[3] = 8'h81;

        repeat (5) @(negedge clk);
        rst_n = 1;
        repeat (5) @(negedge clk);

        for (int i = 0; i < N_BYTES; i++) send_byte(sent[i]);
        for (int i = 0; i < N_BYTES; i++) recv_byte(got[i]);

        for (int i = 0; i < N_BYTES; i++) begin
            if (got[i] === sent[i])
                $display("OK       enviado %h  recibido %h", sent[i], got[i]);
            else begin
                $display("MISMATCH enviado %h  recibido %h", sent[i], got[i]);
                errors++;
            end
        end

        if (errors == 0) $display("*** PASS: %0d bytes correctos ***", N_BYTES);
        else             $display("*** FAIL: %0d errores ***", errors);
        $finish;
    end

    // ---------------- Watchdog ----------------
    initial begin
        #50_000_000;   // 50 ms
        $display("*** TIMEOUT: la simulacion no termino ***");
        $finish;
    end

endmodule