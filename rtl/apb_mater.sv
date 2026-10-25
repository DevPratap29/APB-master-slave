module apb_master (
    input  logic        pclk,       // APB clock: 1 bit
    input  logic        presetn,    // Active-low asynchronous reset: 1 bit

    input  logic [44:0] i_cmd,      // Command bus: 45 bits = 1-bit write + 4-bit strobe + 32-bit data + 8-bit address
    input  logic        i_valid,    // Command valid signal: 1 bit
    output logic [32:0] o_resp,     // Response bus: 33 bits = 1-bit slave error + 32-bit read data
    output logic        o_ready,    // Command completion/ready signal: 1 bit

    output logic [7:0]  o_paddr,    // APB address: 8 bits
    output logic        o_pwrite,   // APB read/write control: 1 bit
    output logic        o_psel,     // APB slave select: 1 bit
    output logic        o_penable,  // APB access phase enable: 1 bit
    output logic [31:0] o_pwdata,   // APB write data: 32 bits
    output logic [3:0]  o_pstrb,    // APB byte write strobe: 4 bits, one per byte
    input  logic [31:0] i_prdata,   // APB read data from slave: 32 bits
    input  logic        i_pslverr,  // APB slave error indication: 1 bit
    input  logic        i_pready    // APB slave ready indication: 1 bit
);

typedef enum logic [1:0] {
    IDLE   = 2'b00,
    ACCESS = 2'b10
} state_t;

state_t state_ff, nxt_state;

always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        state_ff <= IDLE;
    end
    else begin
        state_ff <= nxt_state;
    end
end

always_comb begin
    case (state_ff)
        IDLE:    nxt_state = (i_valid) ? ACCESS : IDLE;
        ACCESS:  nxt_state = (!i_pready) ? ACCESS : IDLE;
        default: nxt_state = state_ff;
    endcase
end

assign o_paddr   = i_cmd[7:0];
assign o_pwrite  = i_cmd[44];
assign o_psel    = (state_ff == IDLE && i_valid);
assign o_penable = (state_ff == ACCESS);
assign o_pwdata  = i_cmd[39:8];
assign o_pstrb   = i_cmd[43:40];

assign o_resp  = {i_pslverr, i_prdata};
assign o_ready = o_penable & i_pready;

endmodule
```
