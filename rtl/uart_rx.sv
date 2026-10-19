module uart_rx #(
    parameter   DBIT = 8,
                SB_TICK = 16 
) (
    input  logic clk, rst_n, rx, s_tick,
    output logic rx_done_tick,
    output logic [DBIT-1:0] dout
);

    typedef enum {idle, start, data, stop} state_t;

    state_t       state_reg, state_next;
    logic   [3:0] s_reg, s_next;
    logic   [2:0] n_reg, n_next;
    logic   [DBIT-1:0] b_reg, b_next;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state_reg <= idle;
            s_reg <= '0;
            n_reg <= '0;
            b_reg <= '0;
        end else begin
            state_reg <= state_next;
            s_reg <= s_next;
            n_reg <= n_next;
            b_reg <= b_next;
        end
    end

    always_comb begin
        state_next   = state_reg;
        s_next       = s_reg;
        n_next       = n_reg;
        b_next       = b_reg;
        rx_done_tick = '0;

        case(state_reg)
            idle : 
                if(!rx) begin 
                    s_next = '0;
                    state_next = start;
                end
            start : begin
                if(s_tick) begin
                    if(s_reg==7) begin
                        s_next = '0;
                        n_next = '0;
                        state_next = data;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end
            data : begin
                if(s_tick) begin
                    if(s_reg==15) begin
                        s_next = '0;
                        b_next = {rx, b_reg[7:1]};
                        if(n_reg==DBIT-1) begin
                            state_next = stop;
                        end else begin
                            n_next = n_reg + 1;
                        end
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end
            stop : begin
                if(s_tick) begin
                    if(s_reg==SB_TICK-1) begin
                        rx_done_tick = '1;
                        state_next = idle;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end
            default : state_next = idle;
        endcase
    end

    assign dout = b_reg;

endmodule