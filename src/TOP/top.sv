//(* keep_hierarchy = "yes" *)
//(* max_fanout = 20 *)
module top (
    `ifdef SIMULATION
    input clk,      // System/CPU Clock
    input vga_clk,  // Clock for vga circuit
    `else
    input osc_clk,
    `endif
    input reset_n_out,  // Asynchronous reset active low
    output vga_out_t vgaData
);

    `ifndef SIMULATION
    // VIVADO CLOCKING
    logic clk, vga_clk;
    clk_wiz_0 WIZ (
        .clk_out1       (vga_clk),
        .clk_out2       (clk),
        .resetn         (reset_n_out),
        .clk_in1        (osc_clk)
        );
    `endif

    // Internal stage-control signals
    logic PCSrc;
    logic redirect_flush;
    logic [31:0] wrData;

    // Pipeline-visible stage wires
    logic [31:0] if_pc;
    logic [31:0] if_instruction;
    logic [31:0] if_instrAddr;

    logic [31:0] id_rdData1;
    logic [31:0] id_rdData2;
    logic [31:0] id_immediate;
    ex_ctrl_t id_ctrlEX;
    mem_ctrl_t id_ctrlMEM;
    wb_ctrl_t id_ctrlWB;

    logic [31:0] ex_branchTarget;
    logic ex_zero;
    logic [31:0] ex_resultALU;
    mem_ctrl_t ex_ctrlMEM;
    mem_ctrl_t ex_ctrlVGA;

    logic [31:0] mem_readData;
    logic [31:0] mem_if_instr;
    logic [31:0] fetch_instr_q;

    // Explicit stage buffers for future pipelining work
    if_id_buf_t if_id_d;
    if_id_buf_t if_id_q;
    id_ex_buf_t id_ex_d;
    id_ex_buf_t id_ex_q;
    ex_mem_buf_t ex_mem_d;
    ex_mem_buf_t ex_mem_q;
    mem_wb_buf_t mem_wb_d;
    mem_wb_buf_t mem_wb_q;

    // Clocking
    (* max_fanout = 20 *)
    logic en_IF, en_ID, en_EX, en_MEM, en_WB;
    logic stall_IF, stall_ID, stall_EX, stall_MEM, stall_WB;

    logic clk_if;
    logic clk_id;
    logic clk_mem;

    logic reset_n;
    always @(posedge clk) begin
        reset_n <= reset_n_out;
    end

    initial begin
        stall_IF = 0;
        stall_ID = 0;
        stall_EX = 0;
        stall_MEM = 0;
        stall_WB = 0;
    end


    top_en enable
        (
            .i_clk     	(clk),
            .i_reset_n	(reset_n),
            .stall_IF   (stall_IF),
            .stall_ID   (stall_ID),
            .stall_EX   (stall_EX),
            .stall_MEM   (stall_MEM),
            .stall_WB   (stall_WB),
            .o_en_IF  	(en_IF),
            .o_en_ID  	(en_ID),
            .o_en_EX  	(en_EX),
            .o_en_MEM  	(en_MEM),
            .o_en_WB  	(en_WB)
        );

    if_top IF
        (
            .i_clk        		(clk),
            .i_reset_n    		(reset_n),
            .i_PCSrc      		(PCSrc),
            .i_inAddr     		(ex_mem_q.branchTarget),
            .i_mem_instr  		(fetch_instr_q),
            .en_WB        		(en_WB),
            .o_outAddr    		(if_pc),
            .o_instruction		(if_instruction),
            .o_mem_instrAddr	(if_instrAddr)
        );

    id_top ID
        (
            .i_clk          (clk),
            .i_reset_n      (reset_n),
            .i_instr        (if_id_q.valid ? if_id_q.instruction : 32'b0),
            .i_wrSig        (mem_wb_q.valid ? mem_wb_q.wb.regWrite : 1'b0),
            .i_wrReg        (mem_wb_q.valid ? mem_wb_q.wb.writeReg : 5'b0),
            .i_wrData       (wrData),
            .en_ID 			(en_ID),
            .en_WB        	(en_WB),
            .o_rdData1      (id_rdData1),
            .o_rdData2      (id_rdData2),
            .o_immediate    (id_immediate),
            .o_ctrlEX       (id_ctrlEX),
            .o_ctrlMEM      (id_ctrlMEM),
            .o_ctrlWB       (id_ctrlWB)
        );

    ex_top EX
        (
        	.i_clk		   	(clk),
        	.i_reset_n		(reset_n),
            .i_inAddr      	(id_ex_q.pc),
            .i_regData1    	(id_ex_q.rdData1),
            .i_regData2    	(id_ex_q.rdData2),
            .i_immediate   	(id_ex_q.immediate),
            .i_ctrlEX      	(id_ex_q.valid ? id_ex_q.ex : '0),
            .i_ctrlMEM     	(id_ex_q.valid ? id_ex_q.mem : '0),
            .en_EX      	(en_EX),
            .o_outAddr     	(ex_branchTarget),
            .o_zero        	(ex_zero),
            .o_resultALU   	(ex_resultALU),
            .o_ctrlMEM      (ex_ctrlMEM),
            .o_ctrlVGA      (ex_ctrlVGA)
        );

    mem_top MEM
        (
            .i_clk          (clk),
            .i_reset_n      (reset_n),
            .i_memAddr      (ex_mem_q.aluResult),
            .i_if_instrAddr (if_id_q.instrAddr),
            .i_wrData       (ex_mem_q.storeData),
            .i_ctrlMEM      (ex_mem_q.valid ? ex_mem_q.mem : '0),
            .i_zero         (ex_mem_q.valid ? ex_mem_q.zero : 1'b0),
            .en_IF          (en_IF),
            .en_MEM         (en_MEM),
            .en_WB          (en_WB),
            .o_readData     (mem_readData),
            .o_if_instr     (mem_if_instr),
            .o_PCSrc        (PCSrc)
        );

    wb_top WB
        (
            .i_ctrlWB     (mem_wb_q.valid ? mem_wb_q.wb.memToReg : 1'b0),
            .i_readData   (mem_wb_q.readData),
            .i_resultALU  (mem_wb_q.aluResult),
            .o_wrData     (wrData)
        );

    always_comb begin
        redirect_flush = en_MEM && ex_mem_q.valid && PCSrc;

        if_id_d = if_id_q;
        if_id_d.valid = 1'b1;
        if_id_d.pc = if_pc;
        if_id_d.instruction = if_instruction;
        if_id_d.instrAddr = if_instrAddr;

        id_ex_d = id_ex_q;
        id_ex_d.valid = if_id_q.valid;
        id_ex_d.pc = if_id_q.pc;
        id_ex_d.rdData1 = id_rdData1;
        id_ex_d.rdData2 = id_rdData2;
        id_ex_d.immediate = id_immediate;
        id_ex_d.ex = id_ctrlEX;
        id_ex_d.mem = id_ctrlMEM;
        id_ex_d.wb = id_ctrlWB;

        ex_mem_d = ex_mem_q;
        ex_mem_d.valid = id_ex_q.valid;
        ex_mem_d.branchTarget = ex_branchTarget;
        ex_mem_d.aluResult = ex_resultALU;
        ex_mem_d.storeData = id_ex_q.rdData2;
        ex_mem_d.zero = ex_zero;
        ex_mem_d.mem = ex_ctrlMEM;
        ex_mem_d.vga = ex_ctrlVGA;
        ex_mem_d.wb = id_ex_q.wb;

        mem_wb_d = mem_wb_q;
        mem_wb_d.valid = ex_mem_q.valid;
        mem_wb_d.readData = mem_readData;
        mem_wb_d.aluResult = ex_mem_q.aluResult;
        mem_wb_d.pcSrc = PCSrc;
        mem_wb_d.instrWord = mem_if_instr;
        mem_wb_d.wb = ex_mem_q.wb;
    end

    pipeline_reg #(
        .T(if_id_buf_t),
        .RESET_VALUE('0)
    ) IF_ID_REG (
        .i_clk      (clk),
        .i_reset_n  (reset_n),
        .i_en       (en_IF),
        .i_flush    (redirect_flush),
        .i_d        (if_id_d),
        .o_q        (if_id_q)
    );

    pipeline_reg #(
        .T(id_ex_buf_t),
        .RESET_VALUE('0)
    ) ID_EX_REG (
        .i_clk      (clk),
        .i_reset_n  (reset_n),
        .i_en       (en_ID),
        .i_flush    (redirect_flush),
        .i_d        (id_ex_d),
        .o_q        (id_ex_q)
    );

    pipeline_reg #(
        .T(ex_mem_buf_t),
        .RESET_VALUE('0)
    ) EX_MEM_REG (
        .i_clk      (clk),
        .i_reset_n  (reset_n),
        .i_en       (en_EX),
        .i_flush    (redirect_flush),
        .i_d        (ex_mem_d),
        .o_q        (ex_mem_q)
    );

    pipeline_reg #(
        .T(mem_wb_buf_t),
        .RESET_VALUE('0)
    ) MEM_WB_REG (
        .i_clk      (clk),
        .i_reset_n  (reset_n),
        .i_en       (en_MEM),
        .i_flush    (1'b0),
        .i_d        (mem_wb_d),
        .o_q        (mem_wb_q)
    );

    always_ff @(posedge clk) begin
        if (~reset_n) begin
            fetch_instr_q <= '0;
        end else if (en_IF) begin
            fetch_instr_q <= mem_if_instr;
        end
    end


    // VGA output circuit
    vga_top VGA
        (
            .i_clk          (clk),
            .i_vga_clk      (vga_clk),
            .i_reset_n      (reset_n),
            .i_pxlAddr      (ex_mem_q.aluResult),
            .i_pxlData      (ex_mem_q.storeData),
            .i_ctrlVGA      (ex_mem_q.vga),
            .en_MEM   		(en_MEM),
            .o_vgaData      (vgaData)
        );

endmodule : top
