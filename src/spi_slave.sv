/*
 * SPDX-FileCopyrightText: 2014-2015 Santhosh G (santhg@opencores.org)
 * SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
 * SPDX-FileComment: Original source: https://opencores.org/projects/spi_verilog_master_slave
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */
`default_nettype none
////////////////////////////////////////////////////////////////////////////////
////                                                                        ////
//// Copyright (C) 2014, 2015 Authors                                       ////
////                                                                        ////
//// This source file may be used and distributed without                   ////
//// restriction provided that this copyright statement is not              ////
//// removed from the file and that any derivative work contains            ////
//// the original copyright notice and the associated disclaimer.           ////
////                                                                        ////
//// This source file is free software; you can redistribute it             ////
//// and/or modify it under the terms of the GNU Lesser General             ////
//// Public License as published by the Free Software Foundation;           ////
//// either version 2.1 of the License, or (at your option) any             ////
//// later version.                                                         ////
////                                                                        ////
//// This source is distributed in the hope that it will be                 ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied             ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR                ////
//// PURPOSE.  See the GNU Lesser General Public License for more           ////
//// details.                                                               ////
////                                                                        ////
//// You should have received a copy of the GNU Lesser General              ////
//// Public License along with this source; if not, download it             ////
//// from http://www.opencores.org/lgpl.shtml                               ////
////                                                                        ////
////////////////////////////////////////////////////////////////////////////////
/* SPI MODE 3
        CHANGE DATA (sdout) @ NEGEDGE SCK
        read data (sdin) @posedge SCK
*/
// verilator lint_off BLKSEQ
module spi_slave #(
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
  input rstb,             // Active-low asynchronous reset. Resets internal registers like rreg, treg, nb, etc.
  input ss,               // Slave Select (Active Low). When low, this slave is active and communicates with the master.
  input sck,              // SPI Clock (from master). Rising edge captures incoming bit; falling edge shifts out data.
  input sdin,             // Slave Data In. SPI MISO line — data coming from the master to this slave.
  input ten,              // Transmit Enable. When high, this slave is allowed to drive sdout; otherwise, it's tri-stated (1'bz).
  input mlb,              // MSB/LSB first selection: if 1 → MSB-first; if 0 → LSB-first. Affects both shifting directions.
  input [7:0] tdata,      // Transmit Data. This is the byte that the slave will shift out to the master on sdout.
  output sdout,           // Slave Data Out (to master). The outgoing bit from this slave (MISO). Tri-stated if ss is high or ten is low.
  output reg done,        // Receive Done Flag. Pulses high when a full 8 bits have been received on sdin.
  output reg [7:0] rdata  // Received Data Byte. This is the assembled byte from the incoming sdin bits. Updated when done == 1.
);

  reg [7:0] treg;
  reg [7:0] rreg;
  reg [3:0] nb;
  wire sout;

  assign sout = mlb ? treg[7] : treg[0];
  assign sdout = ( (!ss) && ten ) ? sout : 1'bz; //if 1=> send data  else TRI-STATE sdout

    //read from  sdout
    always @(posedge sck or negedge rstb) begin
        if (rstb == 0) begin
            rreg = 8'h00;
            rdata = 8'h00;
            done = 0;
            nb = 0;
        end   //
        else if (!ss) begin
            if (mlb == 0) begin //LSB first, in@msb -> right shift
                rreg = {sdin, rreg[7:1]};
            end
            else begin //MSB first, in@lsb -> left shift
                rreg = {rreg[6:0], sdin};
            end
            //increment bit count
            nb = nb + 1;
            if (nb != 8) done = 0;
            else begin
                rdata = rreg;
                done = 1;
                nb = 0;
            end
        end //if(!ss)_END  if(nb==8)
    end

    //send to  sdout
    always @(negedge sck or negedge rstb) begin
        if (rstb == 0) begin
            treg = 8'hFF;
        end
        else begin
            if (!ss) begin
                if (nb == 0) treg = tdata;
                else begin
                    if(mlb == 0) begin //LSB first, out=lsb -> right shift
                        treg = {1'b1,treg[7:1]};
                    end
                    else begin //MSB first, out=msb -> left shift
                        treg = {treg[6:0],1'b1};
                    end
                end
            end //!ss
        end //rstb
    end //always

endmodule
// verilator lint_on BLKSEQ
/*
            if(mlb==0)  //LSB first, out=lsb -> right shift
                    begin treg = {treg[7],treg[7:1]}; end
            else     //MSB first, out=msb -> left shift
                    begin treg = {treg[6:0],treg[0]}; end
*/


/*
force -freeze sim:/SPI_slave/sck 0 0, 1 {25 ns} -r 50 -can 410
run 405ns
noforce sim:/SPI_slave/sck
force -freeze sim:/SPI_slave/sck 1 0
*/
