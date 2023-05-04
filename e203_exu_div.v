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
//  The ALU module to implement the compute function unit
//    and the AGU (address generate unit) for LSU is also handled by ALU
//    additionaly, the shared-impelmentation of MUL and DIV instruction 
//    is also shared by ALU in E200
//
// ====================================================================
`include "e203_defines.v"

module e203_exu_div(

  //////////////////////////////////////////////////////////////
  // The operands and decode info from dispatch
//Dispatch模块和DIV之间的接口采用valid-ready模式的握手信号
  input  disp_div_i_valid, 
  output disp_div_i_ready, 

  output i_longpipe, // Indicate this instruction is 
                     //   issued as a long pipe instruction
                    
  input  [`E203_ITAG_WIDTH-1:0] i_itag,         /// 
  input  [`E203_XLEN-1:0] i_rs1,
  input  [`E203_XLEN-1:0] i_rs2,
  input  [`E203_XLEN-1:0] i_imm,
  input  [`E203_DECINFO_WIDTH-1:0]  i_info,  
  // input  [`E203_PC_SIZE-1:0] i_pc,         //not for divider     ///
  // input  [`E203_INSTR_SIZE-1:0] i_instr,        ////
  // input  i_pc_vld,                         //related to cmt
  // input  [`E203_RFIDX_WIDTH-1:0] i_rdidx,
  input  i_rdwen,

  // input  flush_req,                   //only used in  lsuagu ?
  input  flush_pulse,


  //////////////////////////////////////////////////////////////
  // The div Write-Back Interface
  output wbck_o_valid, // Handshake valid
  input  wbck_o_ready, // Handshake ready
  output [`E203_XLEN-1:0] wbck_o_wdat,
  // output [`E203_RFIDX_WIDTH-1:0] wbck_o_rdidx,
  output [`E203_ITAG_WIDTH-1:0]  div_i_itag,
  output div_o_wbck_err,
  
  input  mdv_nob2b,


  input  clk,
  input  rst_n
  );


`ifdef E203_SUPPORT_MULDIV //{
  wire mdv_i_valid = disp_div_i_valid ;
`endif//E203_SUPPORT_MULDIV}

`ifdef E203_SUPPORT_MULDIV //{
  wire mdv_i_ready;
`endif//E203_SUPPORT_MULDIV}

//将div的ready信号作为反馈给上游派遣模块的ready握手信号
  assign disp_div_i_ready =   
                   `ifdef E203_SUPPORT_MULDIV //{
                     (mdv_i_ready)
                   `endif//E203_SUPPORT_SHARE_MULDIV}
                     ;

  assign i_longpipe =  1'b0;

`ifdef E203_SUPPORT_MULDIV //{
  //////////////////////////////////////////////////////
  // Instantiate the divider module
  wire [`E203_XLEN-1:0]           mdv_i_rs1  = i_rs1;
  wire [`E203_XLEN-1:0]           mdv_i_rs2  = i_rs2;
  wire [`E203_XLEN-1:0]           mdv_i_imm  = i_imm;
  wire [`E203_DECINFO_WIDTH-1:0]  mdv_i_info = i_info;  
  assign div_i_itag =  i_itag;  

  wire mdv_o_valid; 
  wire mdv_o_ready;
  wire [`E203_XLEN-1:0] mdv_o_wbck_wdat;
  // wire div_o_wbck_err;

  wire [`E203_MULDIV_ADDER_WIDTH-1:0] muldiv_req_alu_op1;    //[33-1 : 0]
  wire [`E203_MULDIV_ADDER_WIDTH-1:0] muldiv_req_alu_op2;
  wire                             muldiv_req_alu_add ;
  wire                             muldiv_req_alu_sub ;
  wire [`E203_MULDIV_ADDER_WIDTH-1:0] muldiv_req_alu_res;

  wire          muldiv_sbf_0_ena;
  wire [33-1:0] muldiv_sbf_0_nxt;
  wire [33-1:0] muldiv_sbf_0_r;

  wire          muldiv_sbf_1_ena;
  wire [33-1:0] muldiv_sbf_1_nxt;
  wire [33-1:0] muldiv_sbf_1_r;

  e203_exu_div_divider u_e203_exu_div_divider(
      .mdv_nob2b           (mdv_nob2b),

      .muldiv_i_valid      (mdv_i_valid    ),
      .muldiv_i_ready      (mdv_i_ready    ),
                           
      .muldiv_i_rs1        (mdv_i_rs1      ),
      .muldiv_i_rs2        (mdv_i_rs2      ),
      .muldiv_i_imm        (mdv_i_imm      ),
      .muldiv_i_info       (mdv_i_info[`E203_DECINFO_MULDIV_WIDTH-1:0]),
      .muldiv_i_longpipe   (mdv_i_longpipe ),                         

      .flush_pulse         (flush_pulse    ),

      .muldiv_o_valid      (mdv_o_valid    ),
      .muldiv_o_ready      (mdv_o_ready    ),
      .muldiv_o_wbck_wdat  (mdv_o_wbck_wdat),
      .muldiv_o_wbck_err   (div_o_wbck_err ),

      .muldiv_req_alu_op1  (muldiv_req_alu_op1),
      .muldiv_req_alu_op2  (muldiv_req_alu_op2),
      .muldiv_req_alu_add  (muldiv_req_alu_add),
      .muldiv_req_alu_sub  (muldiv_req_alu_sub),
      .muldiv_req_alu_res  (muldiv_req_alu_res),
      
      //connected to datapath
      .muldiv_sbf_0_ena    (muldiv_sbf_0_ena  ),
      .muldiv_sbf_0_nxt    (muldiv_sbf_0_nxt  ),
      .muldiv_sbf_0_r      (muldiv_sbf_0_r    ),
     
      .muldiv_sbf_1_ena    (muldiv_sbf_1_ena  ),
      .muldiv_sbf_1_nxt    (muldiv_sbf_1_nxt  ),
      .muldiv_sbf_1_r      (muldiv_sbf_1_r    ),

      .clk                 (clk               ),
      .rst_n               (rst_n             ) 
  );
`endif//E203_SUPPORT_MULDIV}


  //////////////////////////////////////////////////////////////
  // Instantiate the Datapath module
  //
 `ifdef E203_SUPPORT_MULDIV //{
  wire muldiv_req_alu = 1'b1;// Since MULDIV have no point to let rd=0, so always need ALU datapath
 `endif//E203_SUPPORT_MULDIV}

  e203_exu_div_dpath u_e203_exu_div_dpath(

`ifdef E203_SUPPORT_MULDIV //{
      .muldiv_req_alu      (muldiv_req_alu    ),

      .muldiv_req_alu_op1  (muldiv_req_alu_op1),
      .muldiv_req_alu_op2  (muldiv_req_alu_op2),
      .muldiv_req_alu_add  (muldiv_req_alu_add),
      .muldiv_req_alu_sub  (muldiv_req_alu_sub),
      .muldiv_req_alu_res  (muldiv_req_alu_res),
      
      .muldiv_sbf_0_ena    (muldiv_sbf_0_ena  ),
      .muldiv_sbf_0_nxt    (muldiv_sbf_0_nxt  ),
      .muldiv_sbf_0_r      (muldiv_sbf_0_r    ),
     
      .muldiv_sbf_1_ena    (muldiv_sbf_1_ena  ),
      .muldiv_sbf_1_nxt    (muldiv_sbf_1_nxt  ),
      .muldiv_sbf_1_r      (muldiv_sbf_1_r    ),
`endif//E203_SUPPORT_MULDIV}

      .clk                 (clk           ),
      .rst_n               (rst_n         ) 
    );


  //////////////////////////////////////////////////////////////
  // Aribtrate the Result and generate output interfaces
  // 
  wire o_valid;
  wire o_ready;

  assign o_valid =     
                      `ifdef E203_SUPPORT_MULDIV //{
                        mdv_o_valid  
                      `endif//E203_SUPPORT_MULDIV}
                     ;

`ifdef E203_SUPPORT_MULDIV //{
  assign mdv_o_ready      = o_ready;
`endif//E203_SUPPORT_MULDIV}

  assign wbck_o_wdat =  
                      `ifdef E203_SUPPORT_MULDIV //{
                       mdv_o_wbck_wdat
                      `endif//E203_SUPPORT_MULDIV}
                  ;

  // assign wbck_o_rdidx = i_rdidx; 

  wire wbck_o_rdwen = i_rdwen;
                  
  wire wbck_o_err = 
                      `ifdef E203_SUPPORT_MULDIV //{
                       div_o_wbck_err
                      `endif//E203_SUPPORT_MULDIV}
                  ;

  //  Each Instruction need to commit or write-back
  //   * The write-back only needed when the unit need to write-back
  //     the result (need to write RD), and it is not a long-pipe uop
  //     (need to be write back by its long-pipe write-back, not here)
  //   * Each instruction need to be commited 
  wire o_need_wbck = wbck_o_rdwen ;

  assign o_ready = 
           (o_need_wbck ? wbck_o_ready : 1'b1); 

  assign wbck_o_valid = o_need_wbck & o_valid ;
  // 

endmodule                                      
                                               
                                               
                                               
