/////////////////////
// Control Signals //
/////////////////////

typedef struct packed {
	logic [1:0] aluOp;
	logic [1:0] aluSrc;
	logic [2:0] func3;
	logic [6:0] func7;
} ex_ctrl_t;

typedef struct packed {
	logic [1:0] aluOp;
	logic [2:0] func3;
	logic [6:0] func7;
} alu_ctrl_t;

typedef struct packed {
	logic sign;			// Signed (0), Unsigned (1)
	logic [1:0] size;   // Byte (00), Half (01), Word (10)
	logic Jump;
	logic Branch;
	logic memRead;
	logic memWrite;
} mem_ctrl_t;

typedef struct packed {
	logic regWrite;
	logic memToReg;
	logic [4:0] writeReg;
} wb_ctrl_t;

////////////////////////////
// Pipeline Stage Buffers //
////////////////////////////

typedef struct packed {
	logic valid;
	logic [31:0] pc;
	logic [31:0] instruction;
	logic [31:0] instrAddr;
} if_id_buf_t;

typedef struct packed {
	logic valid;
	logic [31:0] pc;
	logic [31:0] rdData1;
	logic [31:0] rdData2;
	logic [31:0] immediate;
	ex_ctrl_t ex;
	mem_ctrl_t mem;
	wb_ctrl_t wb;
} id_ex_buf_t;

typedef struct packed {
	logic valid;
	logic [31:0] branchTarget;
	logic [31:0] aluResult;
	logic [31:0] storeData;
	logic zero;
	mem_ctrl_t mem;
	mem_ctrl_t vga;
	wb_ctrl_t wb;
} ex_mem_buf_t;

typedef struct packed {
	logic valid;
	logic [31:0] readData;
	logic [31:0] aluResult;
	logic pcSrc;
	logic [31:0] instrWord;
	wb_ctrl_t wb;
} mem_wb_buf_t;


// Control Signal Definitions
`define OPCODE  i_instr[6:0]
`define RD      i_instr[11:7]
`define RS1     i_instr[19:15]
`define RS2     i_instr[24:20]
`define FUNCT3  i_instr[14:12]
`define FUNCT7  i_instr[31:25]
`define IMM     i_instr[31:20]

/////////////////
// VGA Signals //
/////////////////

typedef struct packed {
	logic vSync;
	logic hSync;
	logic [3:0] red;
	logic [3:0] green;
	logic [3:0] blue;
} vga_out_t;

typedef struct packed {
	logic [3:0] red;
	logic [3:0] green;
	logic [3:0] blue;
} vga_color_t;

