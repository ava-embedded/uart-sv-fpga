module fifo_ctrl #(
    parameter ADDR_DEPTH = 4
) (
    input  logic clk, rst_n, rd, wr,
    output logic empty, full,
    output logic [$clog2(ADDR_DEPTH)-1:0] w_addr, r_addr
);

    logic [$clog2(ADDR_DEPTH)-1:0] w_ptr_logic, w_ptr_next, w_ptr_succ;
    logic [$clog2(ADDR_DEPTH)-1:0] r_ptr_logic, r_ptr_next, r_ptr_succ;
    logic full_logic, full_next, empty_logic, empty_next;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            w_ptr_logic <= '0;
            r_ptr_logic <= '0;
            full_logic  <= '0;
            empty_logic <= '1;
        end else begin
            w_ptr_logic <= w_ptr_next;
            r_ptr_logic <= r_ptr_next;
            full_logic  <= full_next;
            empty_logic <= empty_next;
        end
    end

    always_comb begin
        w_ptr_succ = w_ptr_logic + 1;
        r_ptr_succ = r_ptr_logic + 1;
        w_ptr_next = w_ptr_logic;
        r_ptr_next = r_ptr_logic;
        full_next  = full_logic;
        empty_next = empty_logic;

        unique case({wr, rd})
            2'b01 : 
                if(!empty_logic)
                    begin
                        r_ptr_next = r_ptr_succ;
                        full_next = 1'b0;
                        if(r_ptr_succ==w_ptr_logic) empty_next = 1'b1;
                    end
            2'b10 :
                if(!full_logic)
                begin
                    w_ptr_next = w_ptr_succ;
                    empty_next = 1'b0;
                    if(w_ptr_succ==r_ptr_logic) full_next = 1'b1;
                end
            2'b11 : 
                if(empty_logic)
                    begin
                        w_ptr_next = w_ptr_succ;
                        empty_next = 1'b0;
                    end
                else if(full_logic)
                    begin
                        r_ptr_next = r_ptr_succ;
                        full_next = 1'b0;
                    end
                else
                    begin
                        w_ptr_next = w_ptr_succ;
                        r_ptr_next = r_ptr_succ;
                    end
            default : ;
        endcase
    end

    assign w_addr = w_ptr_logic;
    assign r_addr = r_ptr_logic;
    assign empty  = empty_logic;
    assign full   = full_logic;

endmodule