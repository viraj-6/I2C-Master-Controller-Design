module i2c_top (
    input wire clk, rst, en, rw,
    input wire [6:0] dev_addr,
    input wire [7:0] reg_addr, // NEW
    input wire [7:0] data_in,
    output wire [7:0] data_out,
    output wire data_valid, busy,
    inout wire sda, scl
);

    i2c_controller u_controller (
        .clk(clk), .rst(rst), .en(en), .rw(rw),
        .dev_addr(dev_addr), .reg_addr(reg_addr), .data_in(data_in),
        .data_out(data_out), .data_valid(data_valid),
        .scl(scl), .sda(sda), .busy(busy)
    );

    i2c_slave u_slave (
        .clk(clk), .rst(rst), .scl(scl), .sda(sda)
    );
endmodule
