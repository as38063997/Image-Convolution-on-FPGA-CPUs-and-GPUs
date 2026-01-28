// This module implements 2D covolution between a 3x3 filter and a 512-pixel-wide image of any height.
// It is assumed that the input image is padded with zeros such that the input and output images have
// the same size. The filter coefficients are symmetric in the x-direction (i.e. f[0][0] = f[0][2], 
// f[1][0] = f[1][2], f[2][0] = f[2][2] for any filter f) and their values are limited to integers
// (but can still be positive of negative). The input image is grayscale with 8-bit pixel values ranging
// from 0 (black) to 255 (white).
module lab2 (
	input  clk,			// Operating clock
	input  reset,			// Active-high reset signal (reset when set to 1)
	input  [71:0] i_f,		// Nine 8-bit signed convolution filter coefficients in row-major format (i.e. i_f[7:0] is f[0][0], i_f[15:8] is f[0][1], etc.)
	input  i_valid,			// Set to 1 if input pixel is valid
	input  i_ready,			// Set to 1 if consumer block is ready to receive a new pixel
	input  [7:0] i_x,		// Input pixel value (8-bit unsigned value between 0 and 255)
	output o_valid,			// Set to 1 if output pixel is valid
	output o_ready,			// Set to 1 if this block is ready to receive a new pixel
	output [7:0] o_y		// Output pixel value (8-bit unsigned value between 0 and 255)
);

localparam FILTER_SIZE = 3;	// Convolution filter dimension (i.e. 3x3)
localparam PIXEL_DATAW = 8;	// Bit width of image pixels and filter coefficients (i.e. 8 bits)localparam int FILTER_SIZE = 3;

// The following code is intended to show you an example of how to use paramaters and
// for loops in SytemVerilog. It also arrages the input filter coefficients for you
// into a nicely-arranged and easy-to-use 2D array of registers. However, you can ignore
// this code and not use it if you wish to.

logic signed [PIXEL_DATAW-1:0] r_f [FILTER_SIZE-1:0][FILTER_SIZE-1:0]; // 2D array of registers for filter coefficients
integer col, row, buf_i, i; // variables to use in the for loop



/*always_ff @ (posedge clk) begin
	// If reset signal is high, set all the filter coefficient registers to zeros
	// We're using a synchronous reset, which is recommended style for recent FPGA architectures
	if(reset)begin
		for(row = 0; row < FILTER_SIZE; row = row + 1) begin
			for(col = 0; col < FILTER_SIZE; col = col + 1) begin
				r_f[row][col] <= 0;
			end
		end
	// Otherwise, register the input filter coefficients into the 2D array signal
	end else begin
		for(row = 0; row < FILTER_SIZE; row = row + 1) begin
			for(col = 0; col < FILTER_SIZE; col = col + 1) begin
				// Rearrange the 72-bit input into a 3x3 array of 8-bit filter coefficients.
				// signal[a +: b] is equivalent to signal[a+b-1 : a]. You can try to plug in
				// values for col and row from 0 to 2, to understand how it operates.
				// For example at row=0 and col=0: r_f[0][0] = i_f[0+:8] = i_f[7:0]
				//	       at row=0 and col=1: r_f[0][1] = i_f[8+:8] = i_f[15:8]
				r_f[row][col] <= i_f[(row * FILTER_SIZE * PIXEL_DATAW)+(col * PIXEL_DATAW) +: PIXEL_DATAW];
			end
		end
	end
end*/



// Start of your code

localparam IMG_SIZE = 512 + 2; // size of the image plus padding(512 + 2)
localparam BUFFER_SIZE = IMG_SIZE*2 + FILTER_SIZE;
logic signed [PIXEL_DATAW-1:0] i_buffer [BUFFER_SIZE];

logic[19:0] pixel_counter; // counter to record how many pixels have been added to the buffer
logic[9:0] row_counter; // row counter to deal with the offset of adding padding into pixel_counter

logic valid_stage [0:4];

// output woule be stored from multiplier and adder
logic signed [15:0] mult [0:8];
logic signed [18:0] add_1 [0:3];
logic signed [18:0] add_2 [0:1];
logic signed [18:0] add_3;

// The maxium bits from the last adder will be 20 bits
logic signed [19:0] add_final;

// capture output to 8 bits (0-255) grayscale
logic unsigned [7:0] cap_final;

// pipeline register to send and hold the value
logic signed [18:0] mult_reg [0:8];
logic signed [18:0] add_1_reg [0:3];
logic signed [18:0] add_2_reg [0:1];
logic signed [18:0] add_3_reg;
logic signed [18:0] add_wait [0:2]; // wait signal for add 1 to 3

always_ff @(posedge clk) begin
	// If reset signal is high, set all the filter coefficient registers to zeros
	// We're using a synchronous reset, which is recommended style for recent FPGA architectures
	if(reset)begin
	
		for(row = 0; row < FILTER_SIZE; row = row + 1) begin
			for(col = 0; col < FILTER_SIZE; col = col + 1) begin
				r_f[row][col] <= 0;
			end
		end
		
		for(buf_i = 0; buf_i < BUFFER_SIZE; buf_i = buf_i + 1)begin
			i_buffer[buf_i] <= '0;	
		end
		
		pixel_counter <= '0; // reset both counters
		row_counter <= '0; 
		valid_stage[0] <= '0; // reset valid signal
		
		
	// Otherwise, register the input filter coefficients into the 2D array signal
	end else begin
		for(row = 0; row < FILTER_SIZE; row = row + 1) begin
			for(col = 0; col < FILTER_SIZE; col = col + 1) begin
				// Rearrange the 72-bit input into a 3x3 array of 8-bit filter coefficients.
				// signal[a +: b] is equivalent to signal[a+b-1 : a]. You can try to plug in
				// values for col and row from 0 to 2, to understand how it operates.
				// For example at row=0 and col=0: r_f[0][0] = i_f[0+:8] = i_f[7:0]
				//	       at row=0 and col=1: r_f[0][1] = i_f[8+:8] = i_f[15:8]
				r_f[row][col] <= i_f[(row * FILTER_SIZE * PIXEL_DATAW)+(col * PIXEL_DATAW) +: PIXEL_DATAW];
			end
		end
		
		// prepare for input buffer
		// the newest input will be put input_buffer[0]
		// rest will be shifted by 1
		if(i_valid) begin
			i_buffer[0] <= i_x;
			pixel_counter <= pixel_counter +1;
			
			for(buf_i = 0; buf_i < BUFFER_SIZE - 1; buf_i = buf_i + 1) begin
				i_buffer[buf_i+1] <= i_buffer[buf_i]; // shift all pixels by 1 in the buffer	
			end
			
			row_counter <= row_counter + 1; // to know which row we are at
			
			// sends the output from  multipiler or adder to the pipeline register
			
			for (i = 0; i < 9; i++) begin // multipiler
				mult_reg[i] <= mult[i];
				
			end
			
			for (i = 0; i < 4; i++) begin // adder 1
				add_1_reg[i] <= add_1[i];
			end
			add_wait[0] <= mult_reg[0];
			ㄑㄛ
			for (i = 0; i < 2; i++) begin // adder 2
				add_2_reg[i] <= add_2[i];
			end	
			add_wait[1] <= add_wait[0];
			
			add_3_reg <= add_3; // adder 3
			add_wait[2] <= add_wait[1];
			
			
			// Capture the final output to 8 bits
			if(add_final > 20'sd255) begin
				cap_final <= 8'd255;
			end else if(add_final < 20'sd0)begin
				cap_final <= 8'd0;
			end else begin
				cap_final <= add_final[7:0];
			end
			
			// send the valid signal using pipline register
			valid_stage[1] <= valid_stage[0];
			valid_stage[2] <= valid_stage[1];
			valid_stage[3] <= valid_stage[2];
			valid_stage[4] <= valid_stage[3];
		end
		
		// buffer for convolution
		if(pixel_counter >= BUFFER_SIZE)begin
			// addition output caused by two padding when transfer
			// rows stall valid signal for two cycles
			if(row_counter == 'd1) begin
				valid_stage[0] = 1'b0;
			end else if(row_counter == 'd2)begin
				valid_stage[0] = 1'b0;
			end else begin
				valid_stage[0] <= 1'b1;
			end
		end
		
		if(row_counter == IMG_SIZE - 1)begin
			// Reset row counter for new rows
			row_counter <= 'd0;
		end
		
	end

end
 
 
mult8 mult_layer0_8 (.i_a(i_buffer[0]), .i_b(r_f[2][2]), .i_o(mult[8]));
mult8 mult_layer0_7 (.i_a(i_buffer[1]), .i_b(r_f[2][1]), .i_o(mult[7]));
mult8 mult_layer0_6 (.i_a(i_buffer[2]), .i_b(r_f[2][0]), .i_o(mult[6]));
mult8 mult_layer0_5 (.i_a(i_buffer[IMG_SIZE]), .i_b(r_f[1][2]), .i_o(mult[5]));
mult8 mult_layer0_4 (.i_a(i_buffer[IMG_SIZE + 1]), .i_b(r_f[1][1]), .i_o(mult[4]));
mult8 mult_layer0_3 (.i_a(i_buffer[IMG_SIZE + 2]), .i_b(r_f[1][0]), .i_o(mult[3]));
mult8 mult_layer0_2 (.i_a(i_buffer[IMG_SIZE*2]), .i_b(r_f[0][2]), .i_o(mult[2]));
mult8 mult_layer0_1 (.i_a(i_buffer[IMG_SIZE*2 + 1]), .i_b(r_f[0][1]), .i_o(mult[1]));
mult8 mult_layer0_0 (.i_a(i_buffer[IMG_SIZE*2 + 2]), .i_b(r_f[0][0]), .i_o(mult[0]));

add19 add_layer1_3 (.i_a(mult_reg[8]), .i_b(mult_reg[7]), .i_o(add_1[3]));
add19 add_layer1_2 (.i_a(mult_reg[6]), .i_b(mult_reg[5]), .i_o(add_1[2]));
add19 add_layer1_1 (.i_a(mult_reg[4]), .i_b(mult_reg[3]), .i_o(add_1[1]));
add19 add_layer1_0 (.i_a(mult_reg[2]), .i_b(mult_reg[1]), .i_o(add_1[0]));

add19 add_layer2_1 (.i_a(add_1_reg[3]), .i_b(add_1_reg[2]), .i_o(add_2[1]));
add19 add_layer2_0 (.i_a(add_1_reg[1]), .i_b(add_1_reg[0]), .i_o(add_2[0]));

add19 add_layer3_0 (.i_a(add_2_reg[1]), .i_b(add_2_reg[0]), .i_o(add_3));

add19 add_layer4_0 (.i_a(add_3_reg), .i_b(add_wait[2]), .i_o(add_final));

assign o_y = cap_final;
assign o_valid = valid_stage[4];
assign o_ready = i_ready;
// End of your code

endmodule

module mult8 (
	input unsigned [7:0] i_a,
	input signed [7:0] i_b,
	output signed[15:0] i_o
);
	assign i_o = $signed({1'b0, i_a}) * i_b;
endmodule

module add19(
	input  signed [18:0] i_a,
	input  signed [18:0] i_b,
	output signed [19:0] i_o
);
	assign i_o = i_a + i_b;
endmodule


