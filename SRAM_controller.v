// clock frequency we are assuming is 200MHz - 5ns - 0.005us

module SRAM_Controller(
    input wire i_clk,
    input wire reset,
    input wire [20:0]i_address,
    input wire [15:0]i_data,
    input wire i_rd_strt,
    input wire i_wr_strt,
    
    output wire [15:0]o_data,
    output wire o_data_valid,
    output wire o_wr_done,
    output wire o_busy,

    //control Pins
    output wire[20:0] o_sram_address,
    output reg[15:0] io_sram_in_out,  //  register that interacts with the OUTIN port of the IC
    output wire o_CS,
    output wire o_OE,
    output wire o_WE,
    output wire o_UB,
    output wire o_LB
);

integer i;

reg r_data_valid;
reg r_wr_done;
reg r_CS;
reg r_OE;
reg r_WE;
reg r_UB;
reg r_LB;
reg r_busy;

reg[15:0] r_write_buffer; // buffer to store data before writing

reg[20:0] r_sram_address;
reg[15:0] r_sram_in;
reg[20:0] r_read_address; // a buffer for read address
reg[20:0] r_write_address; // a buffer for writing 

reg[15:0] r_powerup_counter; // the device requires greater than 150us to finish initialization after POWER-UP
reg[1:0]  r_read_cycle_time; // the device requires the address pins to be high min 10ns - 3clock cycles(15ns)
reg[2:0]  r_write_control_time; // the device requires the address pins to be high min 10ns - 3clock cycles(15ns)

assign  o_data_valid    = r_data_valid;
assign  o_wr_done       = r_wr_done;
assign  o_busy          = r_busy;

assign o_CS             = r_CS;     
assign o_OE             = r_OE;
assign o_WE             = r_WE;
assign o_UB             = r_UB;
assign o_LB             = r_LB;

assign o_sram_address   = r_sram_address;
assign o_data           = r_sram_in;


reg[3:0] SRAM_STATE;
localparam initial_state = 4'd0;
localparam read_write_state = 4'd1;
localparam read_state = 4'd2;
localparam write_state = 4'd3;
localparam read_cntrl = 4'd4;
localparam start_read = 4'd5;
localparam out_hold = 4'd6;
localparam write_address = 4'd7;
localparam write_cntrl_strt = 4'd8;
localparam write_cntrl_stop = 4'd9;
localparam write_start = 4'd10;
localparam write_stop = 4'd11;

always @(posedge i_clk or negedge reset) begin
    if (~reset) begin
        r_powerup_counter    <=0;
        r_read_cycle_time    <=0;
        r_write_control_time <=0;
        r_data_valid         <=0;
        r_busy               <=0;
        SRAM_STATE <= initial_state;
    end else begin
        r_data_valid <= 0;
        r_wr_done <= 0;
        case (SRAM_STATE)
        initial_state : begin
            if (r_powerup_counter <= 16'd40000) begin // waiting 200us - 200000ns - 40000clock cycles
                    SRAM_STATE <= initial_state;
                    r_powerup_counter <= r_powerup_counter + 1;
            end
            else begin
                r_powerup_counter    <=0;
                SRAM_STATE <= read_write_state;
            end
        end
        read_write_state : begin
            if (i_rd_strt) begin
                SRAM_STATE <= read_state;
            end
            else if(i_wr_strt)begin
                SRAM_STATE <= write_state;
            end
            else begin
                SRAM_STATE <= read_write_state;
            end
        end
        read_state : begin
            r_read_address <= i_address;
            r_CS    <= 0;   
            r_OE    <= 0; 
            r_UB    <= 0; 
            r_LB    <= 0; 

            r_WE    <= 1;  
            r_busy  <= 1; // read started can't allow other operations
            SRAM_STATE <= read_cntrl;
        end
        read_cntrl : begin
            if(r_read_cycle_time <= 2'd2) begin // holding 3 clock cycles
                r_sram_address <= r_read_address;
                SRAM_STATE <= read_cntrl;
                r_read_cycle_time <= r_read_cycle_time + 1;
            end
            else begin
                r_read_cycle_time    <=0;
                SRAM_STATE <= start_read; 
            end
        end
        start_read : begin
            r_sram_in <= io_sram_in_out; // reading from IC
            SRAM_STATE <= out_hold; // adopted next state bcz the output hold time should be min 2.5ns
        end
        out_hold : begin
            r_CS    <= 1;   
            r_OE    <= 1; 
            r_UB    <= 1; 
            r_LB    <= 1; 

            r_WE    <= 1; 
            r_busy  <= 0;
            r_data_valid <= 1;
            SRAM_STATE <= read_write_state;
        end
        write_state : begin
            r_OE    <= 1; // OE high
            r_busy  <= 1; // write started can't allow other operations
            r_write_address <= i_address; // buffered address
            r_write_buffer  <= i_data; // bufferd data
            SRAM_STATE    <= write_address;
        end
        write_address : begin
            r_sram_address <= r_write_address;
            SRAM_STATE <= write_cntrl_strt;
        end
        write_cntrl_strt : begin
            if(r_write_control_time <= 3'd2) begin // holding controls 3 clock cycles - 15ns
                r_CS    <= 0;    
                r_UB    <= 0; 
                r_LB    <= 0; 
                r_WE    <= 0; 
                SRAM_STATE <= write_cntrl_strt;
                r_write_control_time <= r_write_control_time + 1;
            end
            else begin
                r_write_control_time <=0;
                SRAM_STATE <= write_cntrl_stop;
            end
        end
        write_cntrl_stop : begin
            r_CS    <= 1;    
            r_UB    <= 1; 
            r_LB    <= 1; 
            r_WE    <= 1; 
            SRAM_STATE <= write_start;
        end
        write_start : begin
            io_sram_in_out <= r_write_buffer; // writing to memory
            r_wr_done <= 1;
            SRAM_STATE <= write_stop;
        end
        write_stop : begin
            r_sram_address <= 21'd0;
            r_busy  <= 0;
            SRAM_STATE <= read_write_state;
        end
        default: begin
            SRAM_STATE <= read_write_state;
        end
        endcase
    end
end
endmodule