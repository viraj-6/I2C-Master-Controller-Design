`timescale 1ns / 1ps

module tb_i2c;

    reg clk, rst, en, rw;
    reg [6:0] dev_addr;
    reg [7:0] reg_addr;
    reg [7:0] data_in;
    wire [7:0] data_out;
    wire data_valid, busy, sda, scl;

    pullup(sda);
    pullup(scl);

    i2c_top u_top (
        .clk(clk), .rst(rst), .en(en), .rw(rw),
        .dev_addr(dev_addr), .reg_addr(reg_addr), .data_in(data_in),
        .data_out(data_out), .data_valid(data_valid),
        .busy(busy), .sda(sda), .scl(scl)
    );

    always #10 clk = ~clk;

    initial begin
        clk = 0; rst = 1; en = 0; rw = 0;
        dev_addr = 7'h00; reg_addr = 8'h00; data_in = 8'h00;
        #100; rst = 0; #100;

        // ----------------------------------------
        // TEST 1: WRITE TO REGISTER 0x10
        // ----------------------------------------
        $display("Writing 0x42 to Register 0x10...");
        dev_addr = 7'h5A;  
        reg_addr = 8'h10;   // Target internal memory address
        rw       = 1'b0;    
        data_in  = 8'h42;   // Payload
        en       = 1;
        wait(busy); en = 0; 
        wait(!busy);        
        
        #2000; 

        // ----------------------------------------
        // TEST 2: READ FROM REGISTER 0x10
        // ----------------------------------------
        $display("Reading from Register 0x10...");
        dev_addr = 7'h5A;  
        reg_addr = 8'h10;   // Tell slave we want to read this address
        rw       = 1'b1;    // Execute Read
        en       = 1;
        wait(busy); en = 0; 
        wait(!busy);        
        
        if (data_valid && data_out == 8'h42) 
            $display("SUCCESS! Memory Read correctly returned: %h", data_out);
        else 
            $display("FAILED! Returned: %h", data_out);
        
        #1000;
        $finish;
    end
    
    initial begin
        $dumpfile("i2c_sim.vcd");
        $dumpvars(0, tb_i2c);
    end
endmodule
