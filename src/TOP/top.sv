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

    // Explicit stage buffers for future pipelining work
    if_id_buf_t if_id_q;
    id_ex_buf_t id_ex_q;
    ex_mem_buf_t ex_mem_q;
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
            .i_mem_instr  		(mem_wb_q.instrWord),
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

    always_ff @(posedge clk) begin
        if (~reset_n) begin
            if_id_q <= '0;
            id_ex_q <= '0;
            ex_mem_q <= '0;
            mem_wb_q <= '0;
        end else begin
            if (en_IF) begin
                if_id_q.valid <= 1'b1;
                if_id_q.pc <= if_pc;
                if_id_q.instruction <= if_instruction;
                if_id_q.instrAddr <= if_instrAddr;
            end

            if (en_ID) begin
                id_ex_q.valid <= if_id_q.valid;
                id_ex_q.pc <= if_id_q.pc;
                id_ex_q.rdData1 <= id_rdData1;
                id_ex_q.rdData2 <= id_rdData2;
                id_ex_q.immediate <= id_immediate;
                id_ex_q.ex <= id_ctrlEX;
                id_ex_q.mem <= id_ctrlMEM;
                id_ex_q.wb <= id_ctrlWB;
            end else begin
                id_ex_q.valid <= 1'b0;
            end

            if (en_EX) begin
                ex_mem_q.valid <= id_ex_q.valid;
                ex_mem_q.branchTarget <= ex_branchTarget;
                ex_mem_q.aluResult <= ex_resultALU;
                ex_mem_q.storeData <= id_ex_q.rdData2;
                ex_mem_q.zero <= ex_zero;
                ex_mem_q.mem <= ex_ctrlMEM;
                ex_mem_q.vga <= ex_ctrlVGA;
                ex_mem_q.wb <= id_ex_q.wb;
            end else begin
                ex_mem_q.valid <= 1'b0;
            end

            if (en_MEM) begin
                mem_wb_q.valid <= ex_mem_q.valid;
                mem_wb_q.readData <= mem_readData;
                mem_wb_q.aluResult <= ex_mem_q.aluResult;
                mem_wb_q.pcSrc <= PCSrc;
                mem_wb_q.instrWord <= mem_if_instr;
                mem_wb_q.wb <= ex_mem_q.wb;
            end else begin
                mem_wb_q.valid <= 1'b0;
            end
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
