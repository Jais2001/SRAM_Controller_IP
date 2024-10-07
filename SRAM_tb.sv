`timescale 1ns/1ps
module SRAM_tb();

logic  i_clk = 0;
logic  reset = 0;   
logic  [20:0] in_address;  
logic  [15:0] in_data;
logic  in_rd_strt;
logic  in_wr_strt;

bit   [15:0]o_data;
bit   o_data_valid;
bit   o_wr_done;
bit   o_busy;
bit   [20:0] o_sram_address;
wire [15:0] io_sram_in_out; 
bit   o_CS;
bit   o_OE;
bit   o_WE;
bit   o_UB;
bit   o_LB;

SRAM_Controller DUT(
    .i_clk(i_clk),                  
    .reset(reset),
    .i_address(in_address),
    .i_data(in_data),
    .i_rd_strt(in_rd_strt),
    .i_wr_strt(in_wr_strt),
    .o_data(o_data),
    .o_data_valid(o_data_valid),
    .o_wr_done(o_wr_done),
    .o_busy(o_busy),
    .o_sram_address(o_sram_address),
    .io_sram_in_out(io_sram_in_out),
    .o_CS(o_CS),
    .o_OE(o_OE),
    .o_WE(o_WE),
    .o_UB(o_UB),
    .o_LB(o_LB)
);

initial begin
    $monitor("At time %t, r_powerup_counter = %d", $time, DUT.r_powerup_counter);
end

initial begin
    reset <= 0;
    #100;
    reset <= 1;
    #100;
    in_address <= 21'b110101101100101101001;
    in_data    <= 16'b1011011000110101;
    in_rd_strt <= 1;
    #300000;
    in_rd_strt <= 0;
    #300000;
    in_wr_strt <= 1;
    #300000;
    in_wr_strt <= 0;

end

always 
    #2.5 i_clk<=~i_clk;
endmodule