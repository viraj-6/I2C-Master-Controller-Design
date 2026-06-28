module i2c_controller (
    input wire clk, rst, en, rw,
    input wire [6:0] dev_addr,
    input wire [7:0] reg_addr, // NEW
    input wire [7:0] data_in,
    output wire [7:0] data_out,
    output wire data_valid, scl, busy,
    inout wire sda
);
    wire i2c_clk;
    i2c_clk_div u_clk_div (.clk(clk), .rst(rst), .i2c_clk(i2c_clk));

    i2c_master u_master (
        .i2c_clk(i2c_clk), .rst(rst), .en(en), .rw(rw),
        .dev_addr(dev_addr), .reg_addr(reg_addr), .data_in(data_in),
        .data_out(data_out), .data_valid(data_valid),
        .scl(scl), .sda(sda), .busy(busy)
    );
endmodule
