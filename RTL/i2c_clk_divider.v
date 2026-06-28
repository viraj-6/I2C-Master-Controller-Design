module i2c_clk_div (
    input wire clk,       // System clock
    input wire rst,       // Active high reset
    output reg i2c_clk    // Slower I2C clock
);
    // Adjust this threshold based on your sys_clk to get 100kHz or 400kHz
    // Example: Divider for simulation purposes
    reg [7:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 8'd0;
            i2c_clk <= 1'b0;
        end else if (count == 8'd50) begin
            count <= 8'd0;
            i2c_clk <= ~i2c_clk;
        end else begin
            count <= count + 1'b1;
        end
    end
endmodule
