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
//  This module to implement the 17cycles MUL and 33 cycles DIV unit, which is mostly 
//  share the datapath with ALU_DPATH module to save gatecount to mininum
//

// ====================================================================
`include "e203_defines.v"
// `include "../multiplier/multiplier.v"

`ifdef E203_SUPPORT_MULDIV //{
module e203_exu_mul(
  //dispatch handshake signal the multiplier 1st handshake signal   
  input  i_valid, 
  output i_ready, 
  output i_longpipe, // long instruction 

  input  mdv_nob2b,
  
  // input signals 
  // input  [`E203_ITAG_WIDTH-1:0] i_itag,//unkown function of this signal 
  input  [`E203_XLEN-1:0] i_rs1,
  input  [`E203_XLEN-1:0] i_rs2,
  input  [`E203_XLEN-1:0] i_imm,//three input signals to operation
  input  [`E203_DECINFO_WIDTH-1:0]  i_info,

  
  input  i_ilegl,
  input  i_buserr,
  input  i_misalgn,

  input  i_rdwen,
  input  [`E203_RFIDX_WIDTH-1:0] i_rdidx,


  // input  [`E203_INSTR_SIZE-1:0] i_instr,
  input  i_pc_vld,
  input  flush_pulse,

  // write back handshake signal the multiplier 3rd handshake signals 
  output wbck_o_valid, // Handshake valid
  input  wbck_o_ready, // Handshake ready
  output [`E203_XLEN-1:0] wbck_o_wdat,
  output [`E203_RFIDX_WIDTH-1:0] wbck_o_rdidx,
  

  input  clk,
  input  rst_n
  );
  // the  whole transmission of handshake signal in exu_alu_mdv exu_alu 

  // i_valid & mdv_op -> mdv_i_valid & wbck_condi ->mdv_o_valid -> o_valid
  // o_ready &o_sel_mdv-> mdv_o_ready & wbck_condi -> mdv_i_ready ->i_rady
  
  //input of muldiv _i_valid of muldiv part 
  // wire muldiv_i_valid;//input signal from i_valid
  
  

  //output signal to form o_valid 
  // wire muldiv_o_valid; //output 
  // wire muldiv_o_ready; //input
  
  // wire o_valid;
  // wire o_ready;
  // two temporary signals in the multiplier 
  
  //begin of alu 
  wire ifu_excp_op = i_ilegl | i_buserr | i_misalgn; //发生取址异常的指令，单独列为一种类型，无需被执行
  wire mdv_op = (~ifu_excp_op) & (i_info[`E203_DECINFO_GRP] == `E203_DECINFO_GRP_MULDIV); //MUL unit operate
  // wire muldiv_i_valid = i_valid & mdv_op;
  wire ifu_excp_i_valid = i_valid & ifu_excp_op;
  // wire muldiv_i_ready;
  wire ifu_excp_i_ready;

  wire mdv_i_valid = i_valid & mdv_op;
  // wire ifu_excp_i_valid = 1;
  assign i_ready =   
                    (mdv_i_ready & mdv_op)
                  | (ifu_excp_i_ready & ifu_excp_op);
                  //  | (bjp_i_ready & bjp_op)
                  //  | (csr_i_ready & csr_op)
                  //  `ifdef E203_HAS_NICE//{
                  //  | (nice_i_ready & nice_op)
		  //  `endif//}
 
  // wire muldiv_i_ready;//wire of alu

  
// `ifdef E203_SUPPORT_SHARE_MULDIV //{
  // assign muldiv_o_ready      = o_sel_mdv & o_ready;
// `endif//E203_SUPPORT_SHARE_MULDIV}
  assign i_longpipe = 0; 
  
  wire mdv_o_valid;//output
  wire mdv_o_ready;//intput

  wire [`E203_XLEN-1:0]           muldiv_i_rs1  = {`E203_XLEN         {mdv_op}} & i_rs1;
  wire [`E203_XLEN-1:0]           muldiv_i_rs2  = {`E203_XLEN         {mdv_op}} & i_rs2;
  wire [`E203_XLEN-1:0]           muldiv_i_imm  = {`E203_XLEN         {mdv_op}} & i_imm;
  wire [`E203_DECINFO_WIDTH-1:0]  muldiv_i_info = {`E203_DECINFO_WIDTH{mdv_op}} & i_info; 
  // wire  [`E203_ITAG_WIDTH-1:0]    muldiv_i_itag = {`E203_ITAG_WIDTH   {mdv_op}} & i_itag; //useless signal 
  // wire mdv_i_valid;//input
 


  //rglr
  wire mdv_i_ready;//output
  assign mdv_o_valid = mdv_i_valid;
  assign mdv_i_ready = mdv_o_ready;
  wire [`E203_XLEN-1:0] muldiv_o_wbck_wdat;


  //begin of muldiv module 
  wire muldiv_i_hsked = mdv_i_valid & mdv_i_ready;
  wire muldiv_o_hsked = mdv_o_valid & mdv_o_ready;

  wire flushed_r;
  wire flushed_set = flush_pulse;
  wire flushed_clr = muldiv_o_hsked & (~flush_pulse);
  wire flushed_ena = flushed_set | flushed_clr;
  wire flushed_nxt = flushed_set | (~flushed_clr);
  sirv_gnrl_dfflr #(1) flushed_dfflr (flushed_ena, flushed_nxt, flushed_r, clk, rst_n);

  //flushed function for multiplier 

  //mul
  wire i_mul    = muldiv_i_info[`E203_DECINFO_MULDIV_MUL   ];// We treat this as signed X signed
  wire i_mulh   = muldiv_i_info[`E203_DECINFO_MULDIV_MULH  ];
  wire i_mulhsu = muldiv_i_info[`E203_DECINFO_MULDIV_MULHSU];
  wire i_mulhu  = muldiv_i_info[`E203_DECINFO_MULDIV_MULHU ];
      // If it is flushed then it is not back2back real case
  wire i_b2b    = muldiv_i_info[`E203_DECINFO_MULDIV_B2B   ] & (~flushed_r) & (~mdv_nob2b);

  wire back2back_seq = i_b2b;

  wire mul_rs1_sign = (i_mulhu)            ? 1'b0 : muldiv_i_rs1[`E203_XLEN-1];
  wire mul_rs2_sign = (i_mulhsu | i_mulhu) ? 1'b0 : muldiv_i_rs2[`E203_XLEN-1];//two operator sign num

  wire [32:0] mul_op1 = {mul_rs1_sign, muldiv_i_rs1};
  wire [32:0] mul_op2 = {mul_rs2_sign, muldiv_i_rs2};//two operators modified
  
  wire i_op_mul = i_mul | i_mulh | i_mulhsu | i_mulhu;//fecode mul
  // wire i_op_div = i_div | i_divu | i_rem    | i_remu;


  /////////////////////////////////////////////////////////////////////////////////
  // Implement the state machine for 
  //    (1) The MUL instructions

  // Multiplier Walace Tree Unit to realize multiply instruction
  wire [30:0] mul_op1_inverse = (~mul_op1[31:0]+1);
  wire [30:0] mul_op2_inverse = (~mul_op2[31:0]+1);

  wire [31:0] mul_exe_alu_op1 = mul_rs1_sign ? {(~mul_rs1_sign), mul_op1_inverse[30:0]} : mul_op1[31:0];
  wire [31:0] mul_exe_alu_op2 = mul_rs2_sign ? {(~mul_rs2_sign), mul_op2_inverse[30:0]} : mul_op2[31:0];
  //two signal from the original 
  // wire [31:0] mul_exe_alu_op1 = mul_op1[31:0];
  // wire [31:0] mul_exe_alu_op2 = mul_op2[31:0];
  
  // wire [63:0] local_mul_res;  //store the unsigned value 
  // wire [31:0] mul_exe_alu_op1 = mul_rs1_sign ? {(~mul_rs1_sign), mul_op1_inverse[30:0]} : mul_op1[31:0];
  // wire [31:0] mul_exe_alu_op2 = mul_rs2_sign ? {(~mul_rs2_sign), mul_op2_inverse[30:0]} : mul_op2[31:0];
  // multiplier multipler(
  //   .X(mul_exe_alu_op1),
  //   .Y(mul_exe_alu_op2),
  //   .result(local_mul_res)
  // );


  wire  [63:0] local_mul_res;
  assign local_mul_res = $signed(mul_op1) * $signed(mul_op2); 

  wire a1 = $signed(mul_op1);
  wire a2 = $signed(mul_op2);
  // assign lcoal_mul_res = mul_exe_alu_op1 * mul_exe_alu_op2;
  // wire [63:0] mul_res_present =  (mul_rs1_sign ^ mul_rs2_sign)? (~ local_mul_res + 1) : (local_mul_res);//store the signed value 
  wire [63:0] mul_res_present = local_mul_res;
  wire [63:0] mul_res_signed = (~local_mul_res+1);
  // assign mul_res_s = (~local_mul_res+1)
  //inverse and multiply and then inverse to get the true rsult if they are both 
  // assign mul_res_present =  (mul_op1[32]^mul_op2[32] )?(~local_mul_res+1) : (local_mul_res);
  //transmit the unsigned into signed 

  wire [31:0] res_mul    = mul_res_present[31:0];
  wire [31:0] res_mulh   = mul_res_present[63:32];  //this is the signed operator
  wire [31:0] res_mulhsu   = mul_res_present[63:32];  
  wire [31:0] res_mulhu   = mul_res_present[63:32];  
  // wire [31:0] res_mulhsu = (mul_rs1_sign ^ mul_rs2_sign)?(mul_res_signed[63:32]) : (local_mul_res[63:32]);
  // //judege whether the op1 is negative ot not                                      
  // wire [31:0] res_mulhu  = (mul_rs1_sign ^ mul_rs2_sign)?(mul_res_signed[63:32]) : (local_mul_res[63:32]);  //this is the unsigned operator

  wire[`E203_XLEN-1:0] mul_res = 
         i_mul    ? res_mul    :
         i_mulh   ? res_mulh   :
         i_mulhsu ? res_mulhsu :
         i_mulhu  ? res_mulhu  :
                  `E203_XLEN'b0;


///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
// Output generateion
  // assign special_cases = div_special_cases;// Only divider have special cases
  // wire[`E203_XLEN-1:0] special_res = div_special_res;// Only divider have special cases

  // To detect the sequence of MULH[[S]U] rdh, rs1, rs2;    MUL rdl, rs1, rs2
  // To detect the sequence of     DIV[U] rdq, rs1, rs2; REM[U] rdr, rs1, rs2  
  wire [`E203_XLEN-1:0] back2back_mul_res = {mul_rs1_sign,muldiv_i_rs1[31:0]};
  // wire [`E203_XLEN-1:0] back2back_mul_res = {part_prdt_lo_r[`E203_XLEN-2:0],part_prdt_sft1_r};// Only the MUL will be treated as back2back
  // wire [`E203_XLEN-1:0] back2back_mul_rem = part_remd_r[`E203_XLEN-1:0];
  // wire [`E203_XLEN-1:0] back2back_mul_div = part_quot_r[`E203_XLEN-1:0];
  wire [`E203_XLEN-1:0] back2back_res = (
             ({`E203_XLEN{i_mul         }} & back2back_mul_res)
          //  | ({`E203_XLEN{i_rem | i_remu}} & back2back_mul_rem)
          //  | ({`E203_XLEN{i_div | i_divu}} & back2back_mul_div)
     );

    // The output will be valid:
    //   * If it is back2back and sepcial cases, just directly pass out from input
    //   * If it is not back2back sequence when it is the last cycle of exec state 
    //     (not div need correction) or last correct state;
    // wire wbck_condi =()?1'b1:1'b0;///need to reconsider
  // wire wbck_condi = (mul_res)?1'b1:1'b0;
  // wire wbck_condi = (back2back_seq|special_cases ) ? 1'b1 : 1'b0;//not sure true or not 
                      //  (
                      //      (muldiv_sta_is_exec & exec_last_cycle & (~i_op_div))
                      //    | (muldiv_sta_is_remd_chck & (~div_need_corrct)) 
                      //    | muldiv_sta_is_remd_corr 
                      //  );
  // assign muldiv_o_valid = wbck_condi & muldiv_i_valid;
  // assign muldiv_i_ready = wbck_condi & muldiv_o_ready;

  // wire res_sel_spl = special_cases;
  wire res_sel_b2b  = back2back_seq;
  // wire res_sel_div  = (~back2back_seq) & (~special_cases) & i_op_div;
  wire res_sel_mul  = (~back2back_seq)  & i_op_mul;

  // wire [`E203_XLEN-1:0] muldiv_o_wbck_wdat ;
  assign muldiv_o_wbck_wdat = 
               ({`E203_XLEN{res_sel_b2b}} & back2back_res)
            //  | ({`E203_XLEN{res_sel_spl}} & special_res)
            //  | ({`E203_XLEN{res_sel_div}} & div_res)
              |({`E203_XLEN{res_sel_mul}} & mul_res);
  assign o_ready =  
           (o_need_wbck ? wbck_o_ready : 1'b1); 

  // wire muldiv_i_longpipe;
  // assign muldiv_i_longpipe = 1'b0;
  
  // end of the original muldiv
  
  wire ifu_excp_o_valid;
  wire ifu_excp_o_ready;
  wire [`E203_XLEN-1:0] ifu_excp_o_wbck_wdat;
  // wire ifu_excp_o_wbck_err; //multiplier has no error 

  assign ifu_excp_i_ready = ifu_excp_o_ready;
  assign ifu_excp_o_valid = ifu_excp_i_valid;
  assign ifu_excp_o_wbck_wdat = `E203_XLEN'b0;
  // assign ifu_excp_o_wbck_err  = 1'b1;// IFU illegal instruction always treat as error


  wire o_valid;
  wire o_ready;

  wire o_sel_ifu_excp = ifu_excp_op;
  wire o_sel_mdv = mdv_op;

  assign o_valid =     (o_sel_mdv      & mdv_o_valid     )
                     | (o_sel_ifu_excp & ifu_excp_o_valid)
                     ;

  assign ifu_excp_o_ready = o_sel_ifu_excp & o_ready;
  assign mdv_o_ready      = o_sel_mdv & o_ready;

  // wire o_valid;
  // wire o_ready;


  // assign o_valid =  (o_sel_mdv      & muldiv_o_valid )
  //                 | (o_sel_ifu_excp & ifu_excp_o_valid)
  //                 ;
  
  // writback part of multiplier 
  assign ifu_excp_o_ready = o_sel_ifu_excp & o_ready;
  // assign muldiv_o_ready      = o_sel_mdv & o_ready;
  assign wbck_o_wdat =
                       ({`E203_XLEN{o_sel_mdv}} & muldiv_o_wbck_wdat)
                     | ({`E203_XLEN{o_sel_ifu_excp}} & ifu_excp_o_wbck_wdat);
  
  assign wbck_o_rdidx = i_rdidx;

  wire wbck_o_rdwen = i_rdwen;
  
  wire wbck_o_err =1'b0;

  wire o_need_wbck = wbck_o_rdwen & (~i_longpipe) & (~wbck_o_err);
  // wire o_need_cmt  = 1'b1;


  assign wbck_o_valid = o_need_wbck & o_valid;


`ifndef FPGA_SOURCE//{
`ifndef DISABLE_SV_ASSERTION//{
//synopsys translate_off
///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////
// These below code are used for reference check with assertion
  wire [31:0] golden0_mul_op1 = mul_op1[32] ? (~mul_op1[31:0]+1) : mul_op1[31:0];
  wire [31:0] golden0_mul_op2 = mul_op2[32] ? (~mul_op2[31:0]+1) : mul_op2[31:0];
  wire [63:0] golden0_mul_res_pre = golden0_mul_op1 * golden0_mul_op2;
  wire [63:0] golden0_mul_res = (mul_op1[32]^mul_op2[32]) ? (~golden0_mul_res_pre + 1) : golden0_mul_res_pre;
  wire [63:0] golden1_mul_res = $signed(mul_op1) * $signed(mul_op2); 
  
  // To check the signed * operation is really get what we wanted
    CHECK_SIGNED_OP_CORRECT:
      assert property (@(posedge clk) disable iff ((~rst_n) | (~muldiv_o_valid))  ((golden0_mul_res == golden1_mul_res)))
      else $fatal ("\n Error: Oops, This should never happen. \n");

  wire [31:0] golden1_res_mul    = golden1_mul_res[31:0];
  wire [31:0] golden1_res_mulh   = golden1_mul_res[63:32];                       
  wire [31:0] golden1_res_mulhsu = golden1_mul_res[63:32];                                              
  wire [31:0] golden1_res_mulhu  = golden1_mul_res[63:32];                                                

  wire [63:0] golden2_res_mul_SxS = $signed(muldiv_i_rs1)   * $signed(muldiv_i_rs2);
  wire [63:0] golden2_res_mul_SxU = $signed(muldiv_i_rs1)   * $unsigned(muldiv_i_rs2);
  wire [63:0] golden2_res_mul_UxS = $unsigned(muldiv_i_rs1) * $signed(muldiv_i_rs2);
  wire [63:0] golden2_res_mul_UxU = $unsigned(muldiv_i_rs1) * $unsigned(muldiv_i_rs2);
  
  wire [31:0] golden2_res_mul    = golden2_res_mul_SxS[31:0];
  wire [31:0] golden2_res_mulh   = golden2_res_mul_SxS[63:32];                       
  wire [31:0] golden2_res_mulhsu = golden2_res_mul_SxU[63:32];                                              
  wire [31:0] golden2_res_mulhu  = golden2_res_mul_UxU[63:32];                                                

  // To check four different combination will all generate same lower 32bits result
//     CHECK_FOUR_COMB_SAME_RES:
//       assert property (@(posedge clk) disable iff ((~rst_n) | (~muldiv_o_valid))
//           (golden2_res_mul_SxS[31:0] == golden2_res_mul_SxU[31:0])
//         & (golden2_res_mul_UxS[31:0] == golden2_res_mul_UxU[31:0])
//         & (golden2_res_mul_SxU[31:0] == golden2_res_mul_UxS[31:0])
//        )
//       else $fatal ("\n Error: Oops, This should never happen. \n");

//       Seems the golden2 result is not correct in case of mulhsu, so have to comment it out
//  // To check golden1 and golden2 result are same
//    CHECK_GOLD1_AND_GOLD2_SAME:
//      assert property (@(posedge clk) disable iff ((~rst_n) | (~muldiv_o_valid))
//          (i_mul    ? (golden1_res_mul    == golden2_res_mul   ) : 1'b1)
//         &(i_mulh   ? (golden1_res_mulh   == golden2_res_mulh  ) : 1'b1)
//         &(i_mulhsu ? (golden1_res_mulhsu == golden2_res_mulhsu) : 1'b1)
//         &(i_mulhu  ? (golden1_res_mulhu  == golden2_res_mulhu ) : 1'b1)
//       )
//      else $fatal ("\n Error: Oops, This should never happen. \n");
      
  //    // The special case will need to be handled specially
  // wire [32:0] golden_res_div  = div_special_cases ? div_special_res : 
  //    (  $signed({div_rs1_sign,muldiv_i_rs1})   / ((div_by_0 | div_ovf) ? 1 :   $signed({div_rs2_sign,muldiv_i_rs2})));
  // wire [32:0] golden_res_divu  = div_special_cases ? div_special_res : 
  //    ($unsigned({div_rs1_sign,muldiv_i_rs1})   / ((div_by_0 | div_ovf) ? 1 : $unsigned({div_rs2_sign,muldiv_i_rs2})));
  // wire [32:0] golden_res_rem  = div_special_cases ? div_special_res : 
  //    (  $signed({div_rs1_sign,muldiv_i_rs1})   % ((div_by_0 | div_ovf) ? 1 :   $signed({div_rs2_sign,muldiv_i_rs2})));
  // wire [32:0] golden_res_remu  = div_special_cases ? div_special_res : 
  //    ($unsigned({div_rs1_sign,muldiv_i_rs1})   % ((div_by_0 | div_ovf) ? 1 : $unsigned({div_rs2_sign,muldiv_i_rs2})));
 
  // To check golden and actual result are same
  wire [`E203_XLEN-1:0] golden_res = 
         i_mul    ? golden1_res_mul    :
         i_mulh   ? golden1_res_mulh   :
         i_mulhsu ? golden1_res_mulhsu :
         i_mulhu  ? golden1_res_mulhu  :
        //  i_div    ? golden_res_div [31:0]    :
        //  i_divu   ? golden_res_divu[31:0]    :
        //  i_rem    ? golden_res_rem [31:0]    :
        //  i_remu   ? golden_res_remu[31:0]    :
                    `E203_XLEN'b0;

  CHECK_GOLD_AND_ACTUAL_SAME:
        // Since the printed value is not aligned with posedge clock, so change it to negetive
    assert property (@(negedge clk) disable iff ((~rst_n) | flush_pulse)
        (muldiv_o_valid ? (golden_res == muldiv_o_wbck_wdat   ) : 1'b1)
     )

    else begin
        $display("??????????????????????????????????????????");
        $display("??????????????????????????????????????????");
        $display("{i_mul,i_mulh,i_mulhsu,i_mulhu,i_div,i_divu,i_rem,i_remu}=%d%d%d%d%d%d%d%d",i_mul,i_mulh,i_mulhsu,i_mulhu,i_div,i_divu,i_rem,i_remu);
        $display("muldiv_i_rs1=%h\nmuldiv_i_rs2=%h\n",muldiv_i_rs1,muldiv_i_rs2);     
        $display("golden_res=%h\nmuldiv_o_wbck_wdat=%h",golden_res,muldiv_o_wbck_wdat);     
        $display("??????????????????????????????????????????");
        $fatal ("\n Error: Oops, This should never happen. \n");
      end

//synopsys translate_on
`endif//}
`endif//}


endmodule                                      
`endif//}
                                               
                                               
                                               