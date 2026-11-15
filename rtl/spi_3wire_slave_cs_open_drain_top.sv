module spi_3wire_slave_cs_open_drain_top
  ( input  logic reset, // reset button
    input  logic clk,   // board clock 100MHz
    input  logic sclk,  // SPI CLK
    inout  logic ss_n,  // SPI CS_N
    inout  logic sdata  // MOSI/MISO combined
    );

  parameter MAX_ADDRESS = 7'd1;

  logic        rst_n;
  logic        rst_n_sync;
  logic        rst_n_spi;
  logic  [4:0] bit_count;
  logic        rnw;
  logic        addr; // only 2 addresses
  logic        sdata_out;
  logic        sdata_oe;
  logic        ss_n_oe;
  logic  [7:0] write_data;
  logic  [7:0] hold_read_data;
  logic        write_pulse;
  logic        start_timer;
  logic        start_timer_sync;
  logic        hold_start_timer_sync;
  logic [31:0] timer;
  
  logic [7:0] registers; // 1 byte
  
  assign rst_n = !reset;

  synchronizer u_synchronizer_rst_n_sync
   ( .clk      (clk),
     .rst_n    (rst_n),
     .data_in  (1'b1),
     .data_out (rst_n_sync)
     );

//  assign rst_n_sync = rst_n; // don't synchronize for now

  bidir bidir_sdata
  (
   .pad    (sdata),     // inout
   .to_pad (sdata_out), // input
   .oe     (sdata_oe)   // input
   );

  assign rst_n_spi = rst_n_sync && !ss_n; // clear the SPI when the chip_select is inactive
   
  always_ff @(posedge sclk, negedge rst_n_spi)
    if (~rst_n_spi)                         bit_count <= 'd0;
    else if ((!rnw) && (bit_count == 'd15)) bit_count <= 'd8; // allow for address auto increment on write
    else if (  rnw  && (bit_count == 'd19)) bit_count <= 'd12; // allow for address auto increment on read
    else                                    bit_count <= bit_count + 1;
    
  always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)              rnw <= 1'd0;
     else if ((bit_count == 'd0)) rnw <= sdata;

   always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)             addr <= 0;
     else if (bit_count == 'd7)  addr <= sdata;
     else if (bit_count == 'd15) addr <= addr + 1'd1; // auto increment both read and write
   
   always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)                      write_data <= 8'd0;
     else if (!rnw && (bit_count >= 'd8)) write_data <= {write_data[6:0],sdata};
   
   assign write_pulse = (bit_count == 'd15) && (!rnw);

   always_ff @(posedge sclk, negedge rst_n_sync) // reset is synchronous to board clock
     if (~rst_n_sync)      registers <= 8'h00;
     else if (write_pulse) registers <= {write_data[6:0],sdata}; // last bit might be last SCLK posedge

   always_comb
     hold_read_data = registers;
   
   assign sdata_oe = (bit_count >= 'd9) && rnw;
   
   always_ff @(negedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)                sdata_out <= 1'd0;
     else if (rnw) case(bit_count)
                              'd12: sdata_out <= hold_read_data[7];
                              'd13: sdata_out <= hold_read_data[6];
                              'd14: sdata_out <= hold_read_data[5];
                              'd15: sdata_out <= hold_read_data[4];
                              'd16: sdata_out <= hold_read_data[3];
                              'd17: sdata_out <= hold_read_data[2];
                              'd18: sdata_out <= hold_read_data[1];
                              'd19: sdata_out <= hold_read_data[0];
                         endcase
     else                           sdata_out <= 1'b0;
   

   // address 1 is not read-able as it just serves as a trigger to start the timer
   always_ff @(posedge sclk, negedge rst_n_spi)
     if (~rst_n_spi)                          start_timer <= 1'b0;
     else if ((addr == 1) && (!rnw) && sdata) start_timer <= 1'b1;
     
   synchronizer u_synchronizer_start_timer
   ( .clk      (clk),
     .rst_n    (rst_n_sync),
     .data_in  (start_timer),
     .data_out (start_timer_sync)
     );

   always_ff @(posedge clk, negedge rst_n_sync)
     if (~rst_n_sync) hold_start_timer_sync <= 'd0;
     else             hold_start_timer_sync <= start_timer_sync;
     
   always_ff @(posedge clk, negedge rst_n_sync)
     if (~rst_n_sync)                                       timer <= 'd0;
     else if (start_timer_sync && (!hold_start_timer_sync)) timer <= registers << 22; // rising edge initialize, 255 << 22 * 10E-9s = 10.7s
     else if (timer > 0)                                    timer <= timer -'d1;      // decrement until zero
   
   always_ff @(posedge clk, negedge rst_n_sync)
     if (~rst_n_sync)                           ss_n_oe <= 1'b0;
     else if ((timer > 'd1) && (timer < 'd100)) ss_n_oe <= 1'b1; // 1us low
     else                                       ss_n_oe <= 1'b0;
     
   bidir bidir_ss_n
   (
    .pad    (ss_n),     // inout
    .to_pad (1'b0),     // input, open drain
    .oe     (ss_n_oe)   // input
    );
   
endmodule
