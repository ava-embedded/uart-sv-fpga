module baud_gen (
    input  logic clk, rst_n,
    input  logic [10:0] dvsr,

    output logic tick
);

    logic [10:0] r_reg, r_next;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            r_reg <= '0;
        else
            r_reg <= r_next;
    end

    assign r_next = (r_reg==dvsr) ? 0 : r_reg + 1;

    assign tick = (r_reg==1);
endmodule