// -------------------------------------------------------------------------
// $Id: frame_assembler.v 2524 2013-08-19 13:24:03Z plana $
//  spiNNlink frame assembly module
//
// -------------------------------------------------------------------------
// AUTHOR
//  lap - luis.plana@manchester.ac.uk
//  Based on work by J Pepper (Date 08/08/2012)
//
// -------------------------------------------------------------------------
// DETAILS
//  Created on       : 28 Nov 2012
//  Version          : $Revision: 2524 $
//  Last modified on : $Date: 2013-08-19 14:24:03 +0100 (Mon, 19 Aug 2013) $
//  Last modified by : $Author: plana $
//  $HeadURL: https://solem.cs.man.ac.uk/svn/spiNNlink/testing/src/frame_assembler.v $
//
// -------------------------------------------------------------------------
// COPYRIGHT
//  Copyright (c) The University of Manchester, 2012. All rights reserved.
//  SpiNNaker Project
//  Advanced Processor Technologies Group
//  School of Computer Science
// -------------------------------------------------------------------------
// TODO
//  * add support for channel flow control (including packet storage)
// -------------------------------------------------------------------------


// ----------------------------------------------------------------
// include spiNNlink global constants and parameters
//
`include "spio_hss_multiplexer_common.h"
// ----------------------------------------------------------------

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//----------------------- internal modules ----------------------
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
`timescale 1ns / 1ps
module frm_issue
(
  input  wire 			 clk,
  input  wire 			 rst,

  // register interface
  output reg                     reg_sfrm,

  input  wire  [`CLR_BITS - 1:0] colour,
  input  wire  [`SEQ_BITS - 1:0] seq,

  // incoming packet interface
  input  wire  [`PKT_BITS - 1:0] ipkt_data0,
  input  wire  [`PKT_BITS - 1:0] ipkt_data1,
  input  wire  [`PKT_BITS - 1:0] ipkt_data2,
  input  wire  [`PKT_BITS - 1:0] ipkt_data3,
  input  wire  [`PKT_BITS - 1:0] ipkt_data4,
  input  wire  [`PKT_BITS - 1:0] ipkt_data5,
  input  wire  [`PKT_BITS - 1:0] ipkt_data6,
  input  wire  [`PKT_BITS - 1:0] ipkt_data7,
  input  wire [`NUM_CHANS - 1:0] ipkt_pres,
  input  wire                    ipkt_vld,
  output reg                     ipkt_rdy,

  // local channel flow control interface
  input  wire [`NUM_CHANS - 1:0] cfc_loc,
 
  // frame interface
  output reg   [`FRM_BITS - 1:0] frm_data,
  output reg   [`KCH_BITS - 1:0] frm_kchr,
  output reg 			 frm_last,
  output reg 			 frm_vld,
  input  wire 			 frm_rdy
);

  //---------------------------------------------------------------
  // constants
  //---------------------------------------------------------------
  localparam STATE_BITS = 5;
  localparam STRT_ST = 0;
  localparam HDR0_ST = STRT_ST + 1;
  localparam HDR1_ST = HDR0_ST + 1;
  localparam KEY0_ST = HDR1_ST + 1;
  localparam PLD0_ST = KEY0_ST + 1;
  localparam KEY1_ST = PLD0_ST + 1;
  localparam PLD1_ST = KEY1_ST + 1;
  localparam KEY2_ST = PLD1_ST + 1;
  localparam PLD2_ST = KEY2_ST + 1;
  localparam KEY3_ST = PLD2_ST + 1;
  localparam PLD3_ST = KEY3_ST + 1;
  localparam KEY4_ST = PLD3_ST + 1;
  localparam PLD4_ST = KEY4_ST + 1;
  localparam KEY5_ST = PLD4_ST + 1;
  localparam PLD5_ST = KEY5_ST + 1;
  localparam KEY6_ST = PLD5_ST + 1;
  localparam PLD6_ST = KEY6_ST + 1;
  localparam KEY7_ST = PLD6_ST + 1;
  localparam PLD7_ST = KEY7_ST + 1;
  localparam LAST_ST = PLD7_ST + 1;


  //---------------------------------------------------------------
  // internal signals
  //---------------------------------------------------------------
  reg  [STATE_BITS - 1:0] state;
  reg  [STATE_BITS - 1:0] nxp_state;
  reg  [`NUM_CHANS - 1:0] nxp_mask;
  reg  [`NUM_CHANS - 1:0] nxp_pres;


  //---------------------------------------------------------------
  // packet interface handshake (combinatorial)
  //---------------------------------------------------------------
  always @ (*)
    case (state)
      LAST_ST:   ipkt_rdy = 1'b1;

      default:   ipkt_rdy = 1'b0;
    endcase
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // register bank interface
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      reg_sfrm <= 1'b0;
    else
      reg_sfrm <= (state == STRT_ST) && ipkt_vld;

  //---------------------------------------------------------------
  // frame interface handshake
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      frm_vld  <= 1'b0;
    else
      case (state)
        STRT_ST: if (ipkt_vld)
                   frm_vld  <= 1'b1;
	         else
                   frm_vld  <= 1'b0;

        default:   frm_vld <= frm_vld;  // no change!
      endcase
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // frame data
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      frm_data <= `ZERO_FRM;    // not really necessary!
    else
      case (state)
        STRT_ST: if (ipkt_vld)
                   frm_data <= {`KCH_DATA,
                                 colour,
                                 seq,
                                 ipkt_data7[1],
                                 ipkt_data6[1],
                                 ipkt_data5[1],
                                 ipkt_data4[1],
                                 ipkt_data3[1],
                                 ipkt_data2[1],
                                 ipkt_data1[1],
                                 ipkt_data0[1],
                                 ipkt_pres
                               };

        HDR0_ST:   frm_data <= {ipkt_data3[`PKT_HDR_RNG],
                                 ipkt_data2[`PKT_HDR_RNG],
                                 ipkt_data1[`PKT_HDR_RNG],
                                 ipkt_data0[`PKT_HDR_RNG]
                               };

        HDR1_ST: if (frm_rdy)
                   frm_data <= {ipkt_data7[`PKT_HDR_RNG],
                                 ipkt_data6[`PKT_HDR_RNG],
                                 ipkt_data5[`PKT_HDR_RNG],
                                 ipkt_data4[`PKT_HDR_RNG]
                               };

        KEY0_ST: frm_data <= ipkt_data0[`PKT_KEY_RNG];

        PLD0_ST: frm_data <= ipkt_data0[`PKT_PLD_RNG];

        KEY1_ST: frm_data <= ipkt_data1[`PKT_KEY_RNG];

        PLD1_ST: frm_data <= ipkt_data1[`PKT_PLD_RNG];

        KEY2_ST: frm_data <= ipkt_data2[`PKT_KEY_RNG];

        PLD2_ST: frm_data <= ipkt_data2[`PKT_PLD_RNG];

        KEY3_ST: frm_data <= ipkt_data3[`PKT_KEY_RNG];

        PLD3_ST: frm_data <= ipkt_data3[`PKT_PLD_RNG];

        KEY4_ST: frm_data <= ipkt_data4[`PKT_KEY_RNG];

        PLD4_ST: frm_data <= ipkt_data4[`PKT_PLD_RNG];

        KEY5_ST: frm_data <= ipkt_data5[`PKT_KEY_RNG];

        PLD5_ST: frm_data <= ipkt_data5[`PKT_PLD_RNG];

        KEY6_ST: frm_data <= ipkt_data6[`PKT_KEY_RNG];

        PLD6_ST: frm_data <= ipkt_data6[`PKT_PLD_RNG];

        KEY7_ST: frm_data <= ipkt_data7[`PKT_KEY_RNG];

        PLD7_ST: frm_data <= ipkt_data7[`PKT_PLD_RNG];

        LAST_ST: frm_data <= {8'h00, cfc_loc, {(8 -`NUM_CHANS) {1'b0}},
                               `CRC_PAD
                             };

        default: frm_data <= frm_data;  // no change!
      endcase
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // frame k characters
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      frm_kchr <= `ZERO_KBITS;  // not really necessary!
    else
      case (state)
        STRT_ST: frm_kchr <= `DATA_KBITS;
        default: frm_kchr <= `ZERO_KBITS;
      endcase
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // frame last word
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      frm_last <= 1'b0;
    else
      case (state)
        LAST_ST: frm_last <= 1'b1;
        default: frm_last <= 1'b0;
      endcase
  //---------------------------------------------------------------


  //---------------------------------------------------------------
  // state machine
  //---------------------------------------------------------------
  //---------------------------------------------------------------
  // next-possible state (based on channel presence mask)
  // (combinatorial)
  //---------------------------------------------------------------
  always @ (*)
    casex (ipkt_pres & nxp_mask)
      8'bxxxxxxx1: nxp_state = KEY0_ST;
      8'bxxxxxx10: nxp_state = KEY1_ST;
      8'bxxxxx100: nxp_state = KEY2_ST;
      8'bxxxx1000: nxp_state = KEY3_ST;
      8'bxxx10000: nxp_state = KEY4_ST;
      8'bxx100000: nxp_state = KEY5_ST;
      8'bx1000000: nxp_state = KEY6_ST;
      8'b10000000: nxp_state = KEY7_ST;
      8'b00000000: nxp_state = LAST_ST;
    endcase
  //---------------------------------------------------------------
  
  //---------------------------------------------------------------
  // next-possible-state mask (based on current state)
  // (combinatorial)
  //---------------------------------------------------------------
  always @ (*)
    casex (state)
      STRT_ST: nxp_mask = 8'b11111111;
      HDR0_ST: nxp_mask = 8'b11111111;
      HDR1_ST: nxp_mask = 8'b11111111;
      KEY0_ST: nxp_mask = 8'b11111110;
      PLD0_ST: nxp_mask = 8'b11111110;
      KEY1_ST: nxp_mask = 8'b11111100;
      PLD1_ST: nxp_mask = 8'b11111100;
      KEY2_ST: nxp_mask = 8'b11111000;
      PLD2_ST: nxp_mask = 8'b11111000;
      KEY3_ST: nxp_mask = 8'b11110000;
      PLD3_ST: nxp_mask = 8'b11110000;
      KEY4_ST: nxp_mask = 8'b11100000;
      PLD4_ST: nxp_mask = 8'b11100000;
      KEY5_ST: nxp_mask = 8'b11000000;
      PLD5_ST: nxp_mask = 8'b11000000;
      KEY6_ST: nxp_mask = 8'b10000000;
      PLD6_ST: nxp_mask = 8'b10000000;
      KEY7_ST: nxp_mask = 8'b11111111;
      PLD7_ST: nxp_mask = 8'b11111111;
      LAST_ST: nxp_mask = 8'b11111111;
      default: nxp_mask = 8'bxxxxxxxx;
    endcase
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // next state
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      state <= STRT_ST;
    else
      case (state)
        STRT_ST: if (ipkt_vld)
                   state <= HDR0_ST;
                 else
		   state <= STRT_ST;  // no change!

        HDR0_ST:   state <= HDR1_ST;

        HDR1_ST: if (frm_rdy)
                   state <= nxp_state;
                 else
		   state <= HDR1_ST;  // no change!

        KEY0_ST: if (ipkt_data0[1])
                   state <= PLD0_ST;
                 else
                   state <= nxp_state;

        PLD0_ST:   state <= nxp_state;

        KEY1_ST: if (ipkt_data1[1])
                   state <= PLD1_ST;
                 else
		   state <= nxp_state;

        PLD1_ST:   state <= nxp_state;

        KEY2_ST: if (ipkt_data2[1])
                   state <= PLD2_ST;
                 else
		   state <= nxp_state;

        PLD2_ST:   state <= nxp_state;

        KEY3_ST: if (ipkt_data3[1])
                   state <= PLD3_ST;
                 else
		   state <= nxp_state;

        PLD3_ST:   state <= nxp_state;

        KEY4_ST: if (ipkt_data4[1])
                   state <= PLD4_ST;
                 else
		   state <= nxp_state;

        PLD4_ST:   state <= nxp_state;

        KEY5_ST: if (ipkt_data5[1])
                   state <= PLD5_ST;
                 else
		   state <= nxp_state;

        PLD5_ST:   state <= nxp_state;

        KEY6_ST: if (ipkt_data6[1])
                   state <= PLD6_ST;
                 else
		   state <= nxp_state;

        PLD6_ST:   state <= nxp_state;

        KEY7_ST: if (ipkt_data7[1])
                   state <= PLD7_ST;
                 else
		   state <= LAST_ST;

        PLD7_ST:   state <= LAST_ST;

        LAST_ST:   state <= STRT_ST;

        default:   state <= state;    // no change!
      endcase
  //---------------------------------------------------------------
endmodule
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//------------------- end of internal modules -------------------
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//----------------------- top-level module ----------------------
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
`timescale 1ns / 1ps
module spio_hss_multiplexer_frame_assembler
(
  input  wire 			 clk,
  input  wire 			 rst,

  // register interface (to register bank)
  output wire                    reg_sfrm,
  output reg                     reg_rnak,
  output reg                     reg_rack,
  output reg                     reg_looc,
  output reg  [`CRDT_BITS - 1:0] reg_crdt,
  output wire [`NUM_CHANS - 1:0] reg_empt,
  output wire [`NUM_CHANS - 1:0] reg_full,

  // packet interface
  input  wire  [`PKT_BITS - 1:0] pkt_data0,
  input  wire 			 pkt_vld0,
  output wire 			 pkt_rdy0,

  input  wire  [`PKT_BITS - 1:0] pkt_data1,
  input  wire 			 pkt_vld1,
  output wire 			 pkt_rdy1,

  input  wire  [`PKT_BITS - 1:0] pkt_data2,
  input  wire 			 pkt_vld2,
  output wire 			 pkt_rdy2,

  input  wire  [`PKT_BITS - 1:0] pkt_data3,
  input  wire 			 pkt_vld3,
  output wire 			 pkt_rdy3,

  input  wire  [`PKT_BITS - 1:0] pkt_data4,
  input  wire 			 pkt_vld4,
  output wire 			 pkt_rdy4,

  input  wire  [`PKT_BITS - 1:0] pkt_data5,
  input  wire 			 pkt_vld5,
  output wire 			 pkt_rdy5,

  input  wire  [`PKT_BITS - 1:0] pkt_data6,
  input  wire 			 pkt_vld6,
  output wire 			 pkt_rdy6,

  input  wire  [`PKT_BITS - 1:0] pkt_data7,
  input  wire 			 pkt_vld7,
  output wire 			 pkt_rdy7,

  // ack/nack interface (from frame disassembler)
  // regain tx credit and frame resend control
  input  wire                    ack_type,
  input  wire  [`CLR_BITS - 1:0] ack_colour,
  input  wire  [`SEQ_BITS - 1:0] ack_seq,
  input  wire 			 ack_vld,

  // channel flow control interface (from packet dispatcher)
  // use remote cfc to mask local channels, send local cfc to remote side
  input  wire [`NUM_CHANS - 1:0] cfc_rem,
  input  wire [`NUM_CHANS - 1:0] cfc_loc,
 
  // channel flow control interface (to frame transmitter)
  // report channel flow state to remote side
  output reg 			 cfc_vld,
 
  // frame interface (to frame transmitter)
  // assembled data frame
  output wire  [`FRM_BITS - 1:0] frm_data,
  output wire  [`KCH_BITS - 1:0] frm_kchr,
  output wire			 frm_last,
  output wire			 frm_vld,
  input  wire 			 frm_rdy,
 
  // out-of-credit interface (to frame transmitter)
  // out-of-credit report
  output reg   [`CLR_BITS - 1:0] ooc_colour,
  output reg 			 ooc_vld
);

  //---------------------------------------------------------------
  // constants
  //---------------------------------------------------------------
  localparam STATE_BITS = 1;
  localparam IDLE_ST = 0;
  localparam BUSY_ST = IDLE_ST + 1;


  //---------------------------------------------------------------
  // internal signals
  //---------------------------------------------------------------
  reg  [STATE_BITS - 1:0] state;

  reg                     bpkt_req;
  wire [`NUM_CHANS - 1:0] bpkt_vld;

  wire  [`PKT_BITS - 1:0] ipkt_data [0 : `NUM_CHANS - 1];
  wire [`NUM_CHANS - 1:0] ipkt_pres;
  reg                     ipkt_vld;
  wire                    ipkt_rdy;

  reg   [`CLR_BITS - 1:0] colour; 
  reg   [`SEQ_BITS - 1:0] seq; 

  reg                     vld_ack;
  reg                     vld_nak;
  reg   [`SEQ_BITS - 1:0] pre_ack;
//#  reg   [`SEQ_BITS - 1:0] pre_nak;

  reg  [`CRDT_BITS - 1:0] credit;
  reg                     crdt_out;

  reg  [`O_CNT_BITS -1:0] ooc_snd_ctr;
  reg  [`C_CNT_BITS -1:0] cfc_snd_ctr;
   

  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //--------------------------- structure -------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // frame sender module
  //---------------------------------------------------------------
  frm_issue fi
  (
    .clk           (clk),
    .rst           (rst),

    .reg_sfrm      (reg_sfrm),

    .colour        (colour),
    .seq           (seq),

    .ipkt_data0    (ipkt_data[0]),
    .ipkt_data1    (ipkt_data[1]),
    .ipkt_data2    (ipkt_data[2]),
    .ipkt_data3    (ipkt_data[3]),
    .ipkt_data4    (ipkt_data[4]),
    .ipkt_data5    (ipkt_data[5]),
    .ipkt_data6    (ipkt_data[6]),
    .ipkt_data7    (ipkt_data[7]),
    .ipkt_pres     (ipkt_pres),
    .ipkt_vld      (ipkt_vld),
    .ipkt_rdy      (ipkt_rdy),

    .cfc_loc       (cfc_loc),
 
    .frm_data      (frm_data),
    .frm_kchr      (frm_kchr),
    .frm_last      (frm_last),
    .frm_vld       (frm_vld),
    .frm_rdy       (frm_rdy)
  );
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // packet store modules
  //---------------------------------------------------------------
  spio_hss_multiplexer_pkt_store ps0
  (
    .clk       (clk),
    .rst       (rst),

    .empty     (reg_empt[0]),
    .full      (reg_full[0]),

    .cfc_rem   (cfc_rem[0]),

    .pkt_data  (pkt_data0),
    .pkt_vld   (pkt_vld0),
    .pkt_rdy   (pkt_rdy0),

    .vld_ack   (vld_ack),
    .vld_nak   (vld_nak),
    .ack_seq   (ack_seq),
    .rep_seq   (ack_seq == pre_ack),

    .bpkt_seq  (seq),
    .bpkt_data (ipkt_data[0]),
    .bpkt_pres (ipkt_pres[0]),
    .bpkt_vld  (bpkt_vld[0]),
    .bpkt_req  (bpkt_req)
  );

  spio_hss_multiplexer_pkt_store ps1
  (
    .clk       (clk),
    .rst       (rst),

    .empty     (reg_empt[1]),
    .full      (reg_full[1]),

    .cfc_rem   (cfc_rem[1]),

    .pkt_data  (pkt_data1),
    .pkt_vld   (pkt_vld1),
    .pkt_rdy   (pkt_rdy1),

    .vld_ack   (vld_ack),
    .vld_nak   (vld_nak),
    .ack_seq   (ack_seq),
    .rep_seq   (ack_seq == pre_ack),

    .bpkt_seq  (seq),
    .bpkt_data (ipkt_data[1]),
    .bpkt_pres (ipkt_pres[1]),
    .bpkt_vld  (bpkt_vld[1]),
    .bpkt_req  (bpkt_req)
  );

  spio_hss_multiplexer_pkt_store ps2
  (
    .clk       (clk),
    .rst       (rst),

    .empty     (reg_empt[2]),
    .full      (reg_full[2]),

    .cfc_rem   (cfc_rem[2]),

    .pkt_data  (pkt_data2),
    .pkt_vld   (pkt_vld2),
    .pkt_rdy   (pkt_rdy2),

    .vld_ack   (vld_ack),
    .vld_nak   (vld_nak),
    .ack_seq   (ack_seq),
    .rep_seq   (ack_seq == pre_ack),

    .bpkt_seq  (seq),
    .bpkt_data (ipkt_data[2]),
    .bpkt_pres (ipkt_pres[2]),
    .bpkt_vld  (bpkt_vld[2]),
    .bpkt_req  (bpkt_req)
  );

  spio_hss_multiplexer_pkt_store ps3
  (
    .clk       (clk),
    .rst       (rst),

    .empty     (reg_empt[3]),
    .full      (reg_full[3]),

    .cfc_rem   (cfc_rem[3]),

    .pkt_data  (pkt_data3),
    .pkt_vld   (pkt_vld3),
    .pkt_rdy   (pkt_rdy3),

    .vld_ack   (vld_ack),
    .vld_nak   (vld_nak),
    .ack_seq   (ack_seq),
    .rep_seq   (ack_seq == pre_ack),

    .bpkt_seq  (seq),
    .bpkt_data (ipkt_data[3]),
    .bpkt_pres (ipkt_pres[3]),
    .bpkt_vld  (bpkt_vld[3]),
    .bpkt_req  (bpkt_req)
  );

  spio_hss_multiplexer_pkt_store ps4
  (
    .clk       (clk),
    .rst       (rst),

    .empty     (reg_empt[4]),
    .full      (reg_full[4]),

    .cfc_rem   (cfc_rem[4]),

    .pkt_data  (pkt_data4),
    .pkt_vld   (pkt_vld4),
    .pkt_rdy   (pkt_rdy4),

    .vld_ack   (vld_ack),
    .vld_nak   (vld_nak),
    .ack_seq   (ack_seq),
    .rep_seq   (ack_seq == pre_ack),

    .bpkt_seq  (seq),
    .bpkt_data (ipkt_data[4]),
    .bpkt_pres (ipkt_pres[4]),
    .bpkt_vld  (bpkt_vld[4]),
    .bpkt_req  (bpkt_req)
  );

  spio_hss_multiplexer_pkt_store ps5
  (
    .clk       (clk),
    .rst       (rst),

    .empty     (reg_empt[5]),
    .full      (reg_full[5]),

    .cfc_rem   (cfc_rem[5]),

    .pkt_data  (pkt_data5),
    .pkt_vld   (pkt_vld5),
    .pkt_rdy   (pkt_rdy5),

    .vld_ack   (vld_ack),
    .vld_nak   (vld_nak),
    .ack_seq   (ack_seq),
    .rep_seq   (ack_seq == pre_ack),

    .bpkt_seq  (seq),
    .bpkt_data (ipkt_data[5]),
    .bpkt_pres (ipkt_pres[5]),
    .bpkt_vld  (bpkt_vld[5]),
    .bpkt_req  (bpkt_req)
  );

  spio_hss_multiplexer_pkt_store ps6
  (
    .clk       (clk),
    .rst       (rst),

    .empty     (reg_empt[6]),
    .full      (reg_full[6]),

    .cfc_rem   (cfc_rem[6]),

    .pkt_data  (pkt_data6),
    .pkt_vld   (pkt_vld6),
    .pkt_rdy   (pkt_rdy6),

    .vld_ack   (vld_ack),
    .vld_nak   (vld_nak),
    .ack_seq   (ack_seq),
    .rep_seq   (ack_seq == pre_ack),

    .bpkt_seq  (seq),
    .bpkt_data (ipkt_data[6]),
    .bpkt_pres (ipkt_pres[6]),
    .bpkt_vld  (bpkt_vld[6]),
    .bpkt_req  (bpkt_req)
  );

  spio_hss_multiplexer_pkt_store ps7
  (
    .clk       (clk),
    .rst       (rst),

    .empty     (reg_empt[7]),
    .full      (reg_full[7]),

    .cfc_rem   (cfc_rem[7]),

    .pkt_data  (pkt_data7),
    .pkt_vld   (pkt_vld7),
    .pkt_rdy   (pkt_rdy7),

    .vld_ack   (vld_ack),
    .vld_nak   (vld_nak),
    .ack_seq   (ack_seq),
    .rep_seq   (ack_seq == pre_ack),

    .bpkt_seq  (seq),
    .bpkt_data (ipkt_data[7]),
    .bpkt_pres (ipkt_pres[7]),
    .bpkt_vld  (bpkt_vld[7]),
    .bpkt_req  (bpkt_req)
  );
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //--------------------- frm_issue interface ---------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // frm_issue handshake (combinatorial)
  //---------------------------------------------------------------
  always @ (*)
    if ((state == IDLE_ST) && (bpkt_vld != 0))
      ipkt_vld = 1'b1;
    else
      ipkt_vld = 1'b0;

  always @ (*)
    if (!vld_nak && !crdt_out
         && (ipkt_rdy || ((state == IDLE_ST) && (bpkt_vld == 0)))
       )
      bpkt_req = 1'b1;
    else
      bpkt_req = 1'b0;
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // frame colour
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      colour <= 0;
    else
      if (vld_nak)
	colour <= ~colour;
      else
	colour <= colour;  // no change!
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // frame sequence number
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      seq <= `SEQ_BITS'd0;
    else
      casex ({vld_nak, ipkt_vld})
	2'b1x:   seq <= ack_seq;  // resend nack'd frame
	2'b01:   seq <= seq + 1;  // next in sequence!
	default: seq <= seq;      // no change!	
      endcase
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------- channel flow control interface ---------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // channel flow control handshake
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      cfc_vld <= 1'b0;
    else
//#      if ((cfc_snd_ctr == 0)                         // turn to send cfc
//#           && (state == IDLE_ST) && (bpkt_vld == 0)  // not sending a dfrm
//#           && (!crdt_out || (ooc_snd_ctr != 0))      // not sending ooc
//#         )
//#        cfc_vld <= 1'b1;
//#      else
        cfc_vld <= 1'b0;
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // cfc send counter
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      cfc_snd_ctr <= `CFC_CNT;
    else
      casex ({(state == IDLE_ST), (bpkt_vld == 0), (cfc_snd_ctr == 0),
               crdt_out, (ooc_snd_ctr == 0)
             }
            )
        5'b110xx: cfc_snd_ctr <= cfc_snd_ctr - 1;

        5'b11111: cfc_snd_ctr <= cfc_snd_ctr;  // wait for ooc!

        default:  cfc_snd_ctr <= `CFC_CNT;
      endcase
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //-------------------- out-of-credit interface ------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // out-of-credit handshake
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      ooc_vld <= 1'b0;
    else
      if ((state == IDLE_ST) && crdt_out && (ooc_snd_ctr == 0))
        ooc_vld <= 1'b1;
      else
	ooc_vld <= 1'b0;
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // out-of-credit colour
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      ooc_colour <= 1'b0;  // not really necessary!
    else
      if ((state == IDLE_ST) && crdt_out && (ooc_snd_ctr == 0))
        ooc_colour <= colour;
      else
        ooc_colour <= ooc_colour;  // no change!
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // credit counter
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      credit <= `CRDT_CNT;
    else
      casex ({vld_nak, vld_ack, ipkt_vld})
	3'b1xx:  credit <= `CRDT_CNT;
	3'bx10:  credit <= credit + ack_seq - pre_ack;
	3'bx11:  credit <= credit - 1 + ack_seq - pre_ack;
        3'b001:  credit <= credit - 1;
	default: credit <= credit;  // no change!
      endcase
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // out-of-credit flag (combinatorial)
  // valid acks and nacks increase credit
  //---------------------------------------------------------------
  always @ (*)
    crdt_out = ((credit == 0) && !vld_nak
                 && (!vld_ack || (ack_seq == pre_ack))
               );
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // ooc send counter
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      ooc_snd_ctr <= `OOC_CNT;
    else
      casex ({(state == IDLE_ST), crdt_out, (ooc_snd_ctr == 0)})
        3'b110:  ooc_snd_ctr <= ooc_snd_ctr - 1;

        default: ooc_snd_ctr <= `OOC_CNT;
      endcase
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------- register interface ---------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  always @ (posedge clk or posedge rst)
    if (rst)
      reg_rnak <= 1'b0;
    else
      reg_rnak <= vld_nak;

  always @ (posedge clk or posedge rst)
    if (rst)
      reg_rack <= 1'b0;
    else
      reg_rack <= vld_ack;

  always @ (posedge clk or posedge rst)
    if (rst)
      reg_looc <= 1'b0;
    else
      reg_looc <= ipkt_rdy && crdt_out;

  always @ (posedge clk or posedge rst)
    if (rst)
      reg_crdt <= 0;
    else
        reg_crdt <= credit;
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

	 
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //------------------------- ack interface -----------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // remember previous ack'd sequence number
  // nack's are also implicit acks!
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
//#      pre_ack <= {`SEQ_BITS {1'b1}};
      pre_ack <= {`SEQ_BITS {1'b0}};
    else
      casex ({vld_ack, vld_nak})
        2'b1x:   pre_ack <= ack_seq;
        2'bx1:   pre_ack <= ack_seq;
        default: pre_ack <= pre_ack;  // no change!
      endcase
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // valid ack logic (combinatorial)
  //---------------------------------------------------------------
  always @ (*)
    vld_ack = ack_vld && (ack_type == `ACK_T)
                && (ack_colour == colour);
//#    vld_ack = ack_vld && (ack_type == `ACK_T)
//#                && (ack_colour == colour) && (ack_seq != pre_ack);
  //---------------------------------------------------------------

  //---------------------------------------------------------------
  // valid nack logic (combinatorial)
  //---------------------------------------------------------------
  always @ (*)
    vld_nak = ack_vld && (ack_type == `NAK_T)
                && (ack_colour != colour);
//#    vld_nak = ack_vld && (ack_type == `NAK_T)
//#                && (ack_colour != colour) && (ack_seq != pre_nak);
  //---------------------------------------------------------------

  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //------------------------- state machine -----------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
  //---------------------------------------------------------------
  // next state
  //---------------------------------------------------------------
  always @ (posedge clk or posedge rst)
    if (rst)
      state <= IDLE_ST;
    else
      case (state)
        IDLE_ST: if (ipkt_vld)
                   state <= BUSY_ST;
                 else
                   state <= state;  // no change!

        BUSY_ST: if (ipkt_rdy)
                   state <= IDLE_ST;
                 else
	           state <= state;  // no change!

        default:   state <= state;  // no change!
      endcase
  //---------------------------------------------------------------
  //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

endmodule
