module i2c_fsm(

    input clk,
    input rst,
    input start,

    output reg busy,
    output reg done,

    output reg [2:0] state

);

//====================
// State Encoding
//====================

localparam IDLE      = 3'd0;
localparam START     = 3'd1;
localparam SEND_ADDR = 3'd2;
localparam ACK       = 3'd3;
localparam STOP      = 3'd4;

//====================
// Next State Register
//====================

reg [2:0] next_state;

//====================
// State Register
//====================

always @(posedge clk or posedge rst)
begin
    if(rst)
        state <= IDLE;
    else
        state <= next_state;
end

//====================
// Next State Logic
//====================

always @(*)
begin

    next_state = state;

    case(state)

        IDLE:
        begin
            if(start)
                next_state = START;
        end

        START:
        begin
            next_state = SEND_ADDR;
        end

        SEND_ADDR:
        begin
            next_state = ACK;
        end

        ACK:
        begin
            next_state = STOP;
        end

        STOP:
        begin
            next_state = IDLE;
        end

        default:
            next_state = IDLE;

    endcase

end

//====================
// Output Logic
//====================

always @(*)
begin

    busy = 1'b0;
    done = 1'b0;

    case(state)

        IDLE:
        begin
            busy = 1'b0;
            done = 1'b0;
        end

        START:
        begin
            busy = 1'b1;
        end

        SEND_ADDR:
        begin
            busy = 1'b1;
        end

        ACK:
        begin
            busy = 1'b1;
        end

        STOP:
        begin
            busy = 1'b0;
            done = 1'b1;
        end

    endcase

end

endmodule
