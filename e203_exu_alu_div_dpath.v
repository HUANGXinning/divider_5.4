 /*                                                                      
 Copyright 2018-2020 Nuclei System Technology, Inc.                
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
  Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */                                                                      
                                                                         
                                                                         
                                                                         
//=====================================================================
//
// Designer   : Bob Hu
//
// Description:
//  This module to implement the datapath of ALU
//
// ====================================================================
`include "e203_defines.v"

module e203_exu_alu_div_dpath(
`ifdef E203_SUPPORT_MULDIV //{
  //////////////////////////////////////////////////////
  // MULDIV request the datapath
  input  muldiv_req_alu,

  input  [`E203_MULDIV_ADDER_WIDTH-1:0] muldiv_req_alu_op1,
  input  [`E203_MULDIV_ADDER_WIDTH-1:0] muldiv_req_alu_op2,
  input                              muldiv_req_alu_add,
  input                              muldiv_req_alu_sub,
  output [`E203_MULDIV_ADDER_WIDTH-1:0] muldiv_req_alu_res,

  input           muldiv_sbf_0_ena,
  input  [33-1:0] muldiv_sbf_0_nxt,
  output [33-1:0] muldiv_sbf_0_r,

  input           muldiv_sbf_1_ena,
  input  [33-1:0] muldiv_sbf_1_nxt,
  output [33-1:0] muldiv_sbf_1_r,
`endif//E203_SUPPORT_SHARE_MULDIV}

  input  clk,
  input  rst_n
  );

  `ifdef E203_XLEN_IS_32
      // This is the correct config since E200 is 32bits core
  `else
      !!! ERROR: There must be something wrong, our core must be 32bits wide !!!
  `endif


  wire sbf_0_ena;
  wire [33-1:0] sbf_0_nxt;
  wire [33-1:0] sbf_0_r;

  wire sbf_1_ena;
  wire [33-1:0] sbf_1_nxt;
  wire [33-1:0] sbf_1_r;



  wire [`E203_MULDIV_ADDER_WIDTH-1:0] adder_op1 = muldiv_req_alu_op1;
  wire [`E203_MULDIV_ADDER_WIDTH-1:0] adder_op2 = muldiv_req_alu_op2;

  wire adder_cin;
  wire [`E203_MULDIV_ADDER_WIDTH-1:0] adder_in1;
  wire [`E203_MULDIV_ADDER_WIDTH-1:0] adder_in2;
  wire [`E203_MULDIV_ADDER_WIDTH-1:0] adder_res;

  wire adder_add;
  wire adder_sub;

  assign adder_add = muldiv_req_alu_add ;
  assign adder_sub =  muldiv_req_alu_sub;

  wire adder_addsub = adder_add | adder_sub; 
  

     // Make sure to use logic-gating to gateoff the 
  assign adder_in1 = {`E203_MULDIV_ADDER_WIDTH{adder_addsub}} & (adder_op1);
  assign adder_in2 = {`E203_MULDIV_ADDER_WIDTH{adder_addsub}} & (adder_sub ? (~adder_op2) : adder_op2);
  assign adder_cin = adder_addsub & adder_sub;

  assign adder_res = adder_in1 + adder_in2 + adder_cin;




  //////////////////////////////////////////////////////////////
  // Implement the SBF: Shared Buffers
  sirv_gnrl_dffl #(33) sbf_0_dffl (sbf_0_ena, sbf_0_nxt, sbf_0_r, clk);
  sirv_gnrl_dffl #(33) sbf_1_dffl (sbf_1_ena, sbf_1_nxt, sbf_1_r, clk);

  /////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////
  /////////////////////////////////////////////////////////////////////
  //  The ALU-Datapath Mux for the requestors 

  localparam DPATH_MUX_WIDTH = ((`E203_XLEN*2)+21);

`ifdef E203_SUPPORT_MULDIV //{
  assign muldiv_req_alu_res  = adder_res;
`endif//E203_SUPPORT_SHARE_MULDIV}

  assign sbf_0_ena =  muldiv_sbf_0_ena ;
  assign sbf_1_ena =  muldiv_sbf_1_ena ;

  assign sbf_0_nxt = muldiv_sbf_0_nxt;
  assign sbf_1_nxt = muldiv_sbf_1_nxt;

`ifdef E203_SUPPORT_MULDIV //{
  assign muldiv_sbf_0_r = sbf_0_r;
  assign muldiv_sbf_1_r = sbf_1_r;
`endif//E203_SUPPORT_SHARE_MULDIV}

endmodule                                      
                                               
                                               
                                               
