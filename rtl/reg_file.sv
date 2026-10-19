module reg_file #(
    parameter ADDR_DEPTH = 4, DATA_WIDTH = 8
) (
    input  logic clk, wr_en, rd_en,
    input  logic [DATA_WIDTH-1:0] w_data,
    input  logic [$clog2(ADDR_DEPTH)-1:0] w_addr, r_addr,
    output logic [DATA_WIDTH-1:0] r_data
);

    logic [DATA_WIDTH-1:0] mem [0:ADDR_DEPTH-1];

    initial for (int i = 0; i < ADDR_DEPTH; i++) mem[i] = '0;
    
    always_ff @(posedge clk) begin
        if(wr_en) mem[w_addr] <= w_data;
    end

    assign r_data = mem[r_addr];

endmodule