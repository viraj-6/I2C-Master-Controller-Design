module i2c_slave (
    input wire clk,   
    input wire rst,   
    input wire scl,
    inout wire sda
);
    localparam SLAVE_ADDR = 7'h5A;

    // 256 Bytes of Internal Memory
    reg [7:0] memory [0:255];
    reg [7:0] active_reg_addr;

    // Initialize memory for simulation
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1) memory[i] = 8'h00;
        memory[8'h10] = 8'h42; // Pre-load for testing
    end

    // Oversampling logic
    reg [2:0] scl_sync; reg [2:0] sda_sync;
    always @(posedge clk or posedge rst) begin
        if (rst) begin scl_sync <= 3'b111; sda_sync <= 3'b111; end 
        else begin scl_sync <= {scl_sync[1:0], scl}; sda_sync <= {sda_sync[1:0], sda}; end
    end

    wire scl_high = scl_sync[1];
    wire scl_rise = (scl_sync[2:1] == 2'b01);
    wire scl_fall = (scl_sync[2:1] == 2'b10);
    wire sda_rise = (sda_sync[2:1] == 2'b01);
    wire sda_fall = (sda_sync[2:1] == 2'b10);
    wire start_cond = sda_fall && scl_high; 
    wire stop_cond  = sda_rise && scl_high; 

    // Slave State Machine
    localparam S_IDLE       = 4'd0, S_DEV_ADDR   = 4'd1, S_ACK1       = 4'd2;
    localparam S_REG_ADDR   = 4'd3, S_ACK2       = 4'd4, S_WRITE_DATA = 4'd5;
    localparam S_ACK3       = 4'd6, S_READ_DATA  = 4'd7, S_WAIT_NACK  = 4'd8;

    reg [3:0] state;
    reg [7:0] shift_rx;
    reg [3:0] bit_cnt; // CHANGED: Now a 4-bit counter that counts UP
    reg sda_out, sda_dir, rw_bit; 

    assign sda = (sda_dir && sda_out == 1'b0) ? 1'b0 : 1'bz;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE; shift_rx <= 8'd0; bit_cnt <= 4'd0;
            sda_out <= 1'b1; sda_dir <= 1'b0; rw_bit <= 1'b0;
            active_reg_addr <= 8'd0;
        end else begin
            
            // Asynchronous Start/Stop Handlers
            if (start_cond) begin
                state <= S_DEV_ADDR; bit_cnt <= 4'd0; sda_dir <= 1'b0; 
            end
            else if (stop_cond) begin
                state <= S_IDLE; sda_dir <= 1'b0; 
            end
            
            else begin
                // =====================================
                // PHASE 1: SAMPLE on Rising Edge
                // =====================================
                if (scl_rise) begin
                    if (state == S_DEV_ADDR || state == S_REG_ADDR || state == S_WRITE_DATA) begin
                        if (bit_cnt < 8) shift_rx[7 - bit_cnt] <= sda_sync[1]; 
                    end
                    bit_cnt <= bit_cnt + 1'b1; // Increment counter!
                end
                
                // =====================================
                // PHASE 2: DRIVE on Falling Edge
                // =====================================
                else if (scl_fall) begin
                    case (state)
                        S_DEV_ADDR: begin
                            if (bit_cnt == 8) begin // All 8 bits received
                                if (shift_rx[7:1] == SLAVE_ADDR) begin
                                    state <= S_ACK1; rw_bit <= shift_rx[0];
                                    sda_dir <= 1'b1; sda_out <= 1'b0; // Send ACK
                                end else state <= S_IDLE;
                            end
                        end
                        
                        S_ACK1: begin
                            if (bit_cnt == 9) begin
                                bit_cnt <= 4'd0; // Reset for next byte
                                if (rw_bit == 1'b0) begin
                                    state <= S_REG_ADDR;
                                    sda_dir <= 1'b0; // Release bus
                                end else begin
                                    state <= S_READ_DATA;
                                    sda_dir <= 1'b1; 
                                    sda_out <= memory[active_reg_addr][7]; // Drive first bit immediately!
                                end
                            end
                        end
                        
                        S_REG_ADDR: begin
                            if (bit_cnt == 8) begin
                                active_reg_addr <= shift_rx;
                                state <= S_ACK2; sda_dir <= 1'b1; sda_out <= 1'b0; // Send ACK
                            end
                        end

                        S_ACK2: begin
                            if (bit_cnt == 9) begin
                                sda_dir <= 1'b0; bit_cnt <= 4'd0;
                                state <= S_WRITE_DATA; 
                            end
                        end

                        S_WRITE_DATA: begin
                            if (bit_cnt == 8) begin
                                memory[active_reg_addr] <= shift_rx; // Save to Memory
                                state <= S_ACK3; sda_dir <= 1'b1; sda_out <= 1'b0; // Send ACK
                            end
                        end

                        S_ACK3: begin
                            if (bit_cnt == 9) begin
                                sda_dir <= 1'b0; state <= S_IDLE; 
                            end
                        end

                        S_READ_DATA: begin
                            if (bit_cnt < 8) begin
                                sda_dir <= 1'b1;
                                sda_out <= memory[active_reg_addr][7 - bit_cnt]; // Drive bit
                            end else if (bit_cnt == 8) begin
                                sda_dir <= 1'b0; // Release bus for Master NACK
                                state <= S_WAIT_NACK;
                            end
                        end

                        S_WAIT_NACK: begin
                            if (bit_cnt == 9) begin
                                state <= S_IDLE;
                            end
                        end
                    endcase
                end
            end
        end
    end
endmodule
