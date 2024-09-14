`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.09.2024 10:45:09
// Design Name: 
// Module Name: UART_Top
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


module UART_Top(
    input  Tx_clk, // Tx clock input.
    input  Rx_clk, //Rx clock input
    input rst, // synchronous Reset.
    output  wire [PAYLOAD_BITS-1:0] Rx_Data, //Received DATA
    input  wire [PAYLOAD_BITS-1:0] Tx_Data, //DATA to be Transmitted
    output wire Pin, //Bit by bit data flowing
    output wire Tx_Line_busy, //This shows that the transmitt line is busy
    input wire Enable_Tx, // This makes enables the transmitter to send data 
    input wire Enable_Rx, // This makes enables the Receiver to send data 
    output wire Break, // Shows whether there is some break in the line or not
    output wire Valid_Data // Shows if a valid signal is received or not
    );
    // Clock frequency in hertz.
    parameter CLK_HZ = 50000000;
    parameter BIT_RATE =   9600;
    parameter PAYLOAD_BITS = 8;
    

// UART Transmitter module.
//
    UART_Tx #(
                .BIT_RATE(BIT_RATE),
                .PAYLOAD_BITS(PAYLOAD_BITS),
                .CLK_HZ  (CLK_HZ  )) instantiate_UART_Tx(
                                                            .clk(Tx_clk),
                                                            .rst(rst),
                                                            .uart_txd(Pin),
                                                            .uart_tx_en(Enable_Tx),
                                                            .uart_tx_busy(Tx_Line_busy),
                                                            .uart_tx_data (Tx_Data) 
                                                            );
                                                            
//
// UART RX
        UART_Rx #(
                    .BIT_RATE(BIT_RATE),
                    .PAYLOAD_BITS(PAYLOAD_BITS),
                    .CLK_HZ  (CLK_HZ)) instantiate_UART_Rx(
                                                            .clk(Rx_clk), // Top level system clock input.
                                                            .rst(rst), // Asynchronous active low reset.
                                                            .uart_rx(Pin), // UART Recieve pin.
                                                            .uart_rx_en(Enable_Rx), // Recieve enable
                                                            .uart_rx_break(Break), // Did we get a BREAK message?
                                                            .uart_rx_valid(Valid_Data), // Valid data recieved and available.
                                                            .uart_rx_data (Rx_Data)  // The recieved data.
                                                            );

//

endmodule
