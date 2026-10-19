module fifo #(
    parameter ADDR_DEPTH = 16, DATA_WIDTH = 8
) (
    input  logic clk, rst_n, wr, rd,
    input  logic [DATA_WIDTH-1:0] w_data,
    output logic empty, full,
    output logic [DATA_WIDTH-1:0] r_data
); 

    logic [$clog2(ADDR_DEPTH)-1:0] w_addr, r_addr;
    logic wr_en, rd_en;

    assign wr_en = wr & ~full;
    assign rd_en = rd & ~empty;

    fifo_ctrl #(.ADDR_DEPTH(ADDR_DEPTH)) control_unit (.*);

    reg_file  #(.ADDR_DEPTH(ADDR_DEPTH), .DATA_WIDTH(DATA_WIDTH)) file_unit (.*);

endmodule