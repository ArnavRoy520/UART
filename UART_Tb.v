`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.09.2024 09:28:24
// Design Name: 
// Module Name: UART_Tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module UART_Tb;
reg  Tx_clk, Rx_clk;   //Tx and Rx clock input.
reg  rst     ; //reset
reg [PAYLOAD_BITS-1:0] Tx_Data; //8-bit Data to be transmitted
wire [PAYLOAD_BITS-1:0] Rx_Data  ;// 8-bit Received Data
wire Pin; // 1-Bit data on the line
reg Enable_Tx, Enable_Rx; //Enable status of the Tx and Rx lines
wire busy; // Tx Line Busy Status
wire Break, Valid_Data; // //Break and valid data received status Flags
//
// Bit rate of the UART line we are testing.
localparam BIT_RATE = 9600;
localparam BIT_P    = (1000000000/BIT_RATE);
localparam PAYLOAD_BITS = 8;
//
// Period and frequency of the system clock.
localparam CLK_HZ   = 50000000;
localparam CLK_P    = 1000000000/ CLK_HZ;

//
// Make the clock
always begin 
            #(CLK_P/2) assign Tx_clk = ~Tx_clk;
            #(CLK_P/2) assign Rx_clk = ~Rx_clk;
end



//
// Giving values to be transmitted
initial begin
    rst = 1'b0;
    Tx_clk = 1'b0;
    Rx_clk = 1'b0;
    Enable_Tx = 1'b0;
    Enable_Rx = 1'b0;
    #50 rst = 1'b1;
    #20           
    for(integer i = 0; i<50; i = i+1)begin
        Tx_Data <= $random;
        Enable_Tx = 1'b1;
        Enable_Rx = 1'b1;
        $display("Time = %d , RESET = %b, TRANSMITTED_Data = %8b, RECEIVED_Data = %8b, BIT_ Data = %b ", $time, rst,Tx_Data, Rx_Data, Pin);

        #1000;
        wait(!busy);
    end
end
//
// Instance the top level implementation module.
UART_Top instianciate_TOP (
.Tx_clk (Tx_clk),   // Tx clock input.
.Rx_clk(Rx_clk), //Rx clock input
.rst (rst),   // reset.
.Rx_Data(Rx_Data),   // Received Data
.Tx_Data(Tx_Data),    // Transmitted Data.
.Pin(Pin),
.Tx_Line_busy(busy),
.Enable_Tx(Enable_Tx),
.Enable_Rx(Enable_Rx),
.Break(Break),
.Valid_Data(Valid_Data)
);

//initial begin
//    $monitor("Time = %d , RESET = %b, TRANSMITTED_Data = %8b, RECEIVED_Data = %8b, BIT_ Data = %b ", $time, rst,Tx_Data, Rx_Data, Pin);
//end

initial begin
    $dumpfile("UART_Top.vcd");
    $dumpvars(0, UART_Tb);
end
endmodule
