`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.09.2024 22:03:54
// Design Name: 
// Module Name: UART_Rx
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


module UART_Rx(
    input  wire clk , // Top level system clock input.
    input  wire rst       , // Asynchronous active low reset.
    input  wire uart_rx     , // UART Recieve pin.
    input  wire uart_rx_en   , // Recieve enable
    output wire uart_rx_break, // BREAK message?
    output wire uart_rx_valid, // Valid data recieved and available.
    output reg  [PAYLOAD_BITS-1:0] uart_rx_data   // The recieved data.
    );
    ///////////////////PARAMETERS DECLARATION///////////////////////////////
    parameter BIT_RATE = 9600; // bits / sec
    parameter BIT_P  = 1_000_000_000 * 1/BIT_RATE; // nanoseconds (Bit Period i.e. how much time one bit take to complete)

                ////RECEIVER CLOCK////
    parameter CLK_HZ = 50_000_000; ///(50 MHz)
    parameter CLK_P = 1_000_000_000 * 1/CLK_HZ; // nanoseconds (Clock Period)

////FRAME FORMAT OF the UART used |1-bit Start|8-bit DATA|1-bit Stop| ////
///So, the total frame size is 1+8+1 = 10 bits///

    parameter PAYLOAD_BITS = 8;    ////8-bit data + 1-bit parity
    parameter STOP_BITS = 1;
    
    
    //////////CALCULATION////////////
    // Number of clock cycles per uart bit. (i.e. one bit takes CYCLES_PER_BIT number of clk cycles to finish)
    parameter CYCLES_PER_BIT = BIT_P / CLK_P;
    // Size of the registers which store sample counts and bit durations. 
    //The clog2 function gives the minimum number of bits needed to count up to CYCLES_PER_BIT. The 1+ part ensures the register can count all the way from 0 to CYCLES_PER_BIT - 1.
    parameter COUNT_REG_LEN = 1+$clog2(CYCLES_PER_BIT);
    
    
    
    ///////////////////REGISTER AND STATE DECLARATION///////////////////////////////
    
    ///(1) These registers are used directly to take input from the uart_rx pin.
    ///We are using 2 registers to utilize them as two flop synchronizers.
    ///The data from uart_rx directly goes to rxd_reg_0 which in next clk cycle transfers the data to rxd_reg.
    reg rxd_reg;
    reg rxd_reg_0;
    
    ///(2)These are storage for the recieved serial data.
    ///They store the 8-bit sampled data
    reg [PAYLOAD_BITS-1:0] recieved_data;
    
    ///(3)These registers act as the counter for the number of cycles over a packet bit.
    ///Hence, they have the required amounnt of bits to maintain a count.
    reg [COUNT_REG_LEN-1:0] cycle_counter;

    ///(4) This register acts as the Counter for the number of recieved bits of the packet.
    ///As, we have got 11 bits of frame so we are using a 4 bit register (2^4 = 16)
    reg [3:0] bit_counter;
    
    ///(5)This is a pretty important reg as this stores the currently sampled bit in this.
    ///This bit will be fed to the MSB of the received_data and then shifted.
    ///The bit is sampled in the middle of the clock cycle of each bit.(Eg. if a bit takes 4 clk cycles to finish, then sampling will be done just after 2 clk cycles)
    ///This is done to prevent incorrect data capture and mismatch of time. 
    reg bit_sample;

    ///(6)Current and next states of the internal FSM.
    reg [2:0] fsm_state;
    reg [2:0] n_fsm_state;

    ///(7) STATES OF THE FSM
    parameter FSM_IDLE = 0;   ///THE IDLE STATE (LOGIC '1')
    parameter FSM_START= 1;   ///THE START STATE (WHEN it tansitions from HIGH 2 LOW after IDLE state)
    parameter FSM_RECV = 2;   ///THE RECEIVE STATE is one bit is sampled now we have to sample other
    parameter FSM_STOP = 3;   ///THE STOP STATE (when all the bits are captured)
    
    
    ///////////////////OUTPUT ASSIGNMENT///////////////////////////////// 

    ///(1) Assigning the BREAK FLAG
    ///A BREAK message (or BREAK condition) in UART communication refers to a special condition where the transmit line (TX) is held low (logical 0) for a duration longer than the time it would take to send a full frame
    ///The flag will be set '1' if all the DATA Bits are 0 and a vaild frame is received.
    assign uart_rx_break = uart_rx_valid && ~|recieved_data;
    
    ///(2) Assigning the VALID FLAG
    ///This signal is asserted (1) when the UART receiver has successfully received a valid data frame. It tells the rest of the system that valid data is available to be read.
    ///This is the case when now we are at the STOP STATE and our next  state is going to be IDLE
    assign uart_rx_valid = fsm_state == FSM_STOP && n_fsm_state == FSM_IDLE ;

    ///(3) Assigning the 8-bit DATA
    ///we have got a negative edge triggered syncronous reset D-FF
    always @(posedge clk) begin
        if(!rst) begin
            uart_rx_data  <= {PAYLOAD_BITS{1'b0}};
        end 
        else if (fsm_state == FSM_STOP) begin
            uart_rx_data  <= recieved_data;
        end
    end
    
    
    
    ///////////////////STATE SELECTION///////////////////////////////// 
    
    ///(1) First we will be updating the next_bit FLAG.
    ///This flag tells whether we have to sample the next bit or not.
    ///This is done because one bit takes more than one clk cycle to be transmitted or received.
    wire next_bit = cycle_counter == CYCLES_PER_BIT ||(fsm_state == FSM_STOP && cycle_counter == CYCLES_PER_BIT/2);
    
    ///(2) This flag is for the 8-bit DATA.
    ///This checks the condition, whether the preconfigured DATA length is equal to the received data length 
    wire payload_done = bit_counter   == PAYLOAD_BITS  ;

    ///(3) Next state being assigned.
    always @(*) begin
        case(fsm_state)
            FSM_IDLE : n_fsm_state = rxd_reg      ? FSM_IDLE : FSM_START;
            FSM_START: n_fsm_state = next_bit     ? FSM_RECV : FSM_START;
            FSM_RECV : n_fsm_state = payload_done ? FSM_STOP : FSM_RECV ;
            FSM_STOP : n_fsm_state = next_bit     ? FSM_IDLE : FSM_STOP ;
            default  : n_fsm_state = FSM_IDLE;
        endcase
    end
    
    
    ///////////////////UPDATE the recieved data register///////////////////////////////// 
    
    integer i = 0;
    always @(posedge clk) begin
        if(!rst) begin
            recieved_data <= {PAYLOAD_BITS{1'b0}};
        end 
        else if(fsm_state == FSM_IDLE) begin
            recieved_data <= {PAYLOAD_BITS{1'b0}}; 
        end 
        else if(fsm_state == FSM_RECV && next_bit ) begin
            recieved_data[PAYLOAD_BITS-1] <= bit_sample; /// The sampled bit is transfered to the MSB
            for ( i = PAYLOAD_BITS-2; i >= 0; i = i - 1) begin
                recieved_data[i] <= recieved_data[i+1];  ///Then the value of MSB is shifted
            end
        end
    end


    ///////////////////UPDATE the bit counter register///////////////////////////////// 

    always @(posedge clk) begin
        if(!rst) begin
            bit_counter <= 4'b0;
        end 
        else if(fsm_state != FSM_RECV) begin  
            bit_counter <= {COUNT_REG_LEN{1'b0}};  ///If the receiver is not receiving another bit, then reset the count
        end 
        else if(fsm_state == FSM_RECV && next_bit) begin
            bit_counter <= bit_counter + 1'b1;    ///Increments every time a new bit is received
        end
    end

    ///////////////////SAMPLE the recieved bit when in the middle of a bit frame///////////////////////////////// 

    always @(posedge clk) begin
        if(!rst) begin
            bit_sample <= 1'b0;
        end 
        else if (cycle_counter == CYCLES_PER_BIT/2) begin
            bit_sample <= rxd_reg;         ///Samples the bit after half no. of the required clk cycles
        end
    end

      ///////////////////INCREMENTS the cycle counter///////////////////////////////// 

    always @(posedge clk) begin
        if(!rst) begin
            cycle_counter <= {COUNT_REG_LEN{1'b0}};
        end 
        else if(next_bit) begin
            cycle_counter <= {COUNT_REG_LEN{1'b0}};  ///Once a bit  is received the counter is again reset for the upcoming bit
        end 
        else if(fsm_state == FSM_START || fsm_state == FSM_RECV || fsm_state == FSM_STOP) begin
            cycle_counter <= cycle_counter + 1'b1;   ///Meanwhile we keep increasing the counter until a sample has been collected 
        end
    end


    ///////////////////Progresses the next FSM state///////////////////////////////// 

    always @(posedge clk) begin : p_fsm_state
        if(!rst) begin
            fsm_state <= FSM_IDLE;
        end 
        else begin
            fsm_state <= n_fsm_state;
        end
    end


    ///////////////////UPDATING the internal value of the rxd_reg///////////////////////////////// 

    always @(posedge clk) begin : p_rxd_reg
        if(!rst) begin
            rxd_reg     <= 1'b1;   ////As the IDEL STATE is '1'
            rxd_reg_0   <= 1'b1;
        end 
        else if(uart_rx_en) begin   
            rxd_reg     <= rxd_reg_0;  ////This is the implementation of two stage flip flop for syncronization.
            rxd_reg_0   <= uart_rx;
        end
    end

endmodule
