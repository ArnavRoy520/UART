`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12.09.2024 10:33:03
// Design Name: 
// Module Name: UART_Tx
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


module UART_Tx(
input  wire clk,                                            // Top level system clock input.
input  wire rst,                                         // Asynchronous active low reset.
output wire uart_txd,                                       // UART transmit pin.
output wire uart_tx_busy,                                   // Module busy sending previous item.
input  wire uart_tx_en,                                     // Send the data on uart_tx_data
input  wire [PAYLOAD_BITS-1:0] uart_tx_data                    // The data to be sent
);
 
////////////////////////////////////////////////////////////////parameters////////////////////////////////////////////////////////////////

parameter PAYLOAD_BITS    = 8;                                 // 8 bit data
parameter STOP_BITS    = 1;                                 // number of stop bits

parameter  BIT_RATE = 9600;                                 // baud rate in bits/sec
localparam BIT_P    = 1_000_000_000 * 1/BIT_RATE;           // one bit period in nanoseconds

parameter  CLK_HZ = 50_000_000;                             // 50MHz clock
localparam CLK_P  = 1_000_000_000 * 1/CLK_HZ;               // one clock period in nanoseconds

localparam CYCLES_PER_BIT     = BIT_P / CLK_P;              // number of clock cycles required to transmit one bit of data
localparam CYCLE_COUNTER_BITS = 1+$clog2(CYCLES_PER_BIT);   // length in bits of the cycle counter
localparam BIT_COUNTER_BITS   = 1+$clog2(PAYLOAD_BITS);     // length in bits of the bit counter

localparam IDLE  = 0;                                       // no data transferred
localparam START = 1;                                       // start bit detected
localparam SEND  = 2;                                       // data is being sent
localparam STOP  = 3;                                       // stop bits detecting

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
 
reg [CYCLE_COUNTER_BITS-1 : 0] cycle_counter;               // count the clock cycles in one bit transfer
reg [BIT_COUNTER_BITS-1 : 0]   bit_counter;                                  // count the number of bits transferred

reg [2:0]  state, next_state;                               // store the current and next state of the system

reg [PAYLOAD_BITS-1:0] data_to_send;                        // register to store the data to send
reg tx_reg;                                                 // register to store the data bit that has to be sent

wire next_bit  = cycle_counter == CYCLES_PER_BIT;           // indicator to transfer next bit
wire send_done = bit_counter == PAYLOAD_BITS;               // indicator that all data has been send 
wire stop_done = bit_counter == STOP_BITS && state == STOP; // indicator that stop bits have been completed

assign uart_txd = tx_reg;                                   // output the data in the output register onto the Tx pin
assign uart_tx_busy = state != IDLE;                        // give a bus ysignal if the line is being used
 

/////////////////////////deciding the state of the system/////////////////////////

//calculate next state of the system
always @(*) begin
    case(state)
        IDLE   : next_state = uart_tx_en ? START : IDLE;
        START  : next_state = next_bit   ? SEND  : START;
        SEND   : next_state = send_done  ? STOP  : SEND;
        STOP   : next_state = stop_done  ? IDLE  : STOP;
        default: next_state = IDLE;
    endcase
end

//assign next state to the system
always @(posedge clk) begin
    if (!rst) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end
//////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////bit counter///////////////////////////////////
always @(posedge clk) begin
    if (!rst) begin
        bit_counter <= 4'b0;
    end
    else if (state == SEND && next_bit) begin                            // send the next data bit 
        bit_counter <= bit_counter + 1'b1;
    end
    else if (state == STOP && next_bit) begin                            // send the next stop bit
        bit_counter <= bit_counter + 1'b1;
    end
    else if (state != SEND && state != STOP) begin                
        bit_counter <= {BIT_COUNTER_BITS{1'b0}};
    end
    else if(state == SEND && next_state == STOP) begin                   // start counting the number of stop bits
        bit_counter <= {BIT_COUNTER_BITS{1'b0}};
    end
end
/////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////cycle counter//////////////////////////////////
always @(posedge clk) begin
    if (!rst) begin
        cycle_counter <= {CYCLE_COUNTER_BITS{1'b0}};
    end
    else if (next_bit) begin                                             // reset counter to start sending the next bit
        cycle_counter <= {CYCLE_COUNTER_BITS{1'b0}};
    end
    else if (state == SEND || state == START || state == STOP) begin     
        cycle_counter <= cycle_counter + 1'b1;
    end
end
/////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////Data to send//////////////////////////////////
integer i=0;
always @(posedge clk) begin
    if (!rst) begin
         data_to_send <= {PAYLOAD_BITS{1'b0}};
    end
    else if (state == IDLE && uart_tx_en) begin
        data_to_send = uart_tx_data;            // data + parity bit
    end
    else if(state == SEND && next_bit) begin
        for (i = PAYLOAD_BITS-2; i >= 0; i = i - 1) begin        // right shift data in the output register
            data_to_send[i] <= data_to_send[i+1];
        end
    end
end

// give value to the output register
always @(posedge clk) begin
    if (!rst) begin
        tx_reg <= 1'b1;
    end else if(state == IDLE) begin
        tx_reg <= 1'b1;
    end else if(state == START) begin          // pull down to low for start bit
        tx_reg <= 1'b0;
    end else if(state == SEND) begin           // send data bit
        tx_reg <= data_to_send[0];
    end else if(state == STOP) begin           //release line to high for stop bit 
        tx_reg <= 1'b1;
    end   
end
////////////////////////////////////////////////////////////////////////////////

endmodule
