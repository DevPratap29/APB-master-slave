module apb_slave (
    input  logic        pclk,       // APB clock: 1 bit
    input  logic        presetn,    // Active-low asynchronous reset: 1 bit
    input  logic [4:0]  i_paddr,    // APB address: 5 bits
    input  logic        i_pwrite,   // APB read/write control: 1 bit
    input  logic        i_psel,     // APB slave select: 1 bit
    input  logic        i_penable,  // APB access phase enable: 1 bit
    input  logic [31:0] i_pwdata,   // APB write data: 32 bits
    input  logic [3:0]  i_pstrb,    // APB byte write strobe: 4 bits, one per byte
    output logic [31:0] o_prdata,   // APB read data: 32 bits
    output logic        o_pslverr,  // APB slave error indication: 1 bit
    output logic        o_pready,   // APB slave ready indication: 1 bit
    output logic        o_hw_ctl,   // Hardware control output: 1 bit
    input  logic        i_hw_sts    // Hardware status input: 1 bit
);
typedef enum logic [1:0] {
    IDLE     = 2'b00,
    W_ACCESS = 2'b01,
    R_ACCESS = 2'b10,
    R_FINISH = 2'b11
} state_t;
state_t state_ff;                  // FSM state register: 2 bits
localparam ADDR_LSB = 2;            // Number of byte-offset bits for 32-bit data: 2 bits
localparam N_REG    = 8;            // Addressable 32-bit register locations: 2^(5-2) = 8
logic [31:0] apb_reg [0:4];        // Register bank: 5 registers, each 32 bits wide
logic wr_err, rd_err;              // Write-error and read-error flags: 1 bit each
logic req_rd, req_wr;               // Read-request and write-request flags: 1 bit each
assign req_rd = i_psel && ~i_pwrite;
assign req_wr = i_psel &&  i_pwrite;
always @(posedge pclk) begin
    if (!presetn) begin
        state_ff <= IDLE;
        apb_reg[0] <= '0;
        apb_reg[1] <= '0;
        apb_reg[2] <= '0;
        o_prdata <= '0;
        o_pready <= 1'b0;
    end
    else begin
        case (state_ff)
            IDLE: begin
                if (req_wr) begin
                    o_pready <= 1'b1;
                    state_ff <= W_ACCESS;
                end
                else if (req_rd) begin
                    o_pready <= 1'b0;
                    state_ff <= R_ACCESS;
                end
            end
            W_ACCESS: begin
                if (req_wr && i_penable) begin
                    case (i_paddr[4:2])
                        0: apb_reg[0] <= i_pwdata;
                        1: apb_reg[1] <= i_pwdata;
                        2: apb_reg[2] <= i_pwdata;
                        default: ;
                    endcase
                end
                o_pready <= 1'b0;
                state_ff <= IDLE;
            end
            R_ACCESS: begin
                if (req_rd && i_penable) begin
                    case (i_paddr[4:2])
                        0: o_prdata <= apb_reg[0];
                        2: o_prdata <= apb_reg[2];
                        3: o_prdata <= apb_reg[3];
                        4: o_prdata <= apb_reg[4];
                        default: o_prdata <= '0;
                    endcase
                end
                else begin
                    o_prdata <= '0;
                end
                o_pready <= 1'b1;
                state_ff <= R_FINISH;
            end
            R_FINISH: begin
                o_pready <= 1'b0;
                state_ff <= IDLE;
            end
            default: ;
        endcase
    end
end
assign apb_reg[3] = 32'hDEAD_BEEF;
assign apb_reg[4] = i_hw_sts;
assign o_hw_ctl = apb_reg[0];
assign wr_err = (state_ff == IDLE) &&
                req_wr &&
                (i_paddr[4:2] == 3 || i_paddr[4:2] == 4);
assign rd_err = (state_ff == R_ACCESS) &&
                req_rd &&
                (i_paddr[4:2] == 1);
always @(posedge pclk) begin
    if (!presetn) begin
        o_pslverr <= 1'b0;
    end
    else begin
        o_pslverr <= wr_err | rd_err;
    end
end
endmodule
