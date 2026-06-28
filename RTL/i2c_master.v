module i2c_master (
    input wire i2c_clk,
    input wire rst,
    input wire en,
    input wire rw,             // 0 = Write, 1 = Read
    input wire [6:0] dev_addr, // 7-bit Device Address
    input wire [7:0] reg_addr, // 8-bit Internal Register Address
    input wire [7:0] data_in,  // Data to write
    
    output reg [7:0] data_out,
    output reg data_valid,
    output reg scl,  
    inout wire sda,
    output reg busy
);

    // Advanced State Machine
    localparam IDLE         = 4'd0;
    localparam START        = 4'd1;
    localparam DEV_ADDR_W   = 4'd2; // Device Addr + Write Bit(0)
    localparam ACK1         = 4'd3;
    localparam REG_ADDR     = 4'd4; // Register Address
    localparam ACK2         = 4'd5;
    localparam DATA_TX      = 4'd6; // Write Data
    localparam ACK3_W       = 4'd7;
    localparam REP_START_1  = 4'd8; // Repeated Start Setup
    localparam REP_START_2  = 4'd9; // Repeated Start Exec
    localparam DEV_ADDR_R   = 4'd10;// Device Addr + Read Bit(1)
    localparam ACK3_R       = 4'd11;
    localparam DATA_RX      = 4'd12;// Read Data
    localparam NACK_M       = 4'd13;// Master NACK
    localparam STOP         = 4'd14;

    reg [3:0] state;
    reg [2:0] bit_cnt;
    reg [7:0] shift_tx;
    reg rw_latch;
    reg phase; 
    reg sda_out, sda_dir;

    assign sda = (sda_dir && sda_out == 0) ? 1'b0 : 1'bz;

    always @(posedge i2c_clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            sda_out <= 1'b1; sda_dir <= 1'b1; scl <= 1'b1;
            busy <= 1'b0; bit_cnt <= 3'd7; phase <= 1'b0;
            data_out <= 8'd0; data_valid <= 1'b0; rw_latch <= 1'b0;
        end else begin
            data_valid <= 1'b0; 
            
            case (state)
                IDLE: begin
                    sda_out <= 1'b1; scl <= 1'b1; sda_dir <= 1'b1; phase <= 1'b0;
                    if (en) begin
                        state <= START;
                        busy <= 1'b1;
                        rw_latch <= rw;
                        shift_tx <= {dev_addr, 1'b0}; // ALWAYS start with Write to send Reg Addr
                    end else busy <= 1'b0;
                end

                START: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_out <= 1'b0; scl <= 1'b1; end 
                    else begin scl <= 1'b0; state <= DEV_ADDR_W; bit_cnt <= 3'd7; end
                end

                DEV_ADDR_W: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_out <= shift_tx[bit_cnt]; scl <= 1'b0; end 
                    else begin scl <= 1'b1; if (bit_cnt == 0) state <= ACK1; else bit_cnt <= bit_cnt - 1'b1; end
                end

                ACK1: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b0; scl <= 1'b0; end // Listen
                    else begin scl <= 1'b1; state <= REG_ADDR; bit_cnt <= 3'd7; shift_tx <= reg_addr; end
                end

                REG_ADDR: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b1; sda_out <= shift_tx[bit_cnt]; scl <= 1'b0; end 
                    else begin scl <= 1'b1; if (bit_cnt == 0) state <= ACK2; else bit_cnt <= bit_cnt - 1'b1; end
                end

                ACK2: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b0; scl <= 1'b0; end 
                    else begin 
                        scl <= 1'b1; 
                        if (rw_latch == 1'b0) begin state <= DATA_TX; shift_tx <= data_in; end // If Write
                        else state <= REP_START_1; // If Read
                        bit_cnt <= 3'd7; 
                    end
                end

                // --- WRITE BRANCH ---
                DATA_TX: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b1; sda_out <= shift_tx[bit_cnt]; scl <= 1'b0; end 
                    else begin scl <= 1'b1; if (bit_cnt == 0) state <= ACK3_W; else bit_cnt <= bit_cnt - 1'b1; end
                end
                ACK3_W: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b0; scl <= 1'b0; end 
                    else begin scl <= 1'b1; state <= STOP; end
                end

                // --- READ BRANCH ---
                REP_START_1: begin // Setup Sr: Release SDA High while SCL is Low, then SCL High
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b1; sda_out <= 1'b1; scl <= 1'b0; end 
                    else begin scl <= 1'b1; state <= REP_START_2; end
                end
                REP_START_2: begin // Exec Sr: Pull SDA Low while SCL is High, then SCL Low
                    phase <= ~phase;
                    if (phase == 0) begin sda_out <= 1'b0; scl <= 1'b1; end // START CONDITION!
                    else begin scl <= 1'b0; state <= DEV_ADDR_R; bit_cnt <= 3'd7; shift_tx <= {dev_addr, 1'b1}; end // Load Device Addr + Read Bit
                end
                DEV_ADDR_R: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_out <= shift_tx[bit_cnt]; scl <= 1'b0; end 
                    else begin scl <= 1'b1; if (bit_cnt == 0) state <= ACK3_R; else bit_cnt <= bit_cnt - 1'b1; end
                end
                ACK3_R: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b0; scl <= 1'b0; end 
                    else begin scl <= 1'b1; state <= DATA_RX; bit_cnt <= 3'd7; end
                end
                DATA_RX: begin
                    phase <= ~phase;
                    if (phase == 0) begin scl <= 1'b0; end // Slave drives data here
                    else begin 
                        scl <= 1'b1; data_out[bit_cnt] <= sda; // Master samples
                        if (bit_cnt == 0) state <= NACK_M; else bit_cnt <= bit_cnt - 1'b1;
                    end
                end
                NACK_M: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b1; sda_out <= 1'b1; scl <= 1'b0; end // Master drives HIGH (NACK)
                    else begin scl <= 1'b1; state <= STOP; data_valid <= 1'b1; end
                end

                // --- SHARED STOP ---
                STOP: begin
                    phase <= ~phase;
                    if (phase == 0) begin sda_dir <= 1'b1; sda_out <= 1'b0; scl <= 1'b0; end 
                    else begin scl <= 1'b1; state <= IDLE; end
                end
            endcase
        end
    end
endmodule
