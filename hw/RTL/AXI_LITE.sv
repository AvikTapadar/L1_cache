module axi_controller(
    input logic clk,
    input logic rst,
    
    //CACHE INTERFACE (MASTER PROFILE)
    input logic cmd_valid,
    output logic cmd_ready,
    input logic [31:0] cmd_addr,
    input logic cmd_is_write,
    input logic [31:0] cmd_wdata,

    output logic refill_valid,
    output logic [31:0] refill_data,
    output logic axi_refill_done,

    //AXI INTERFACE
    //Channel 1: Write Address
    output logic axi_awvalid,
    output logic [31:0] axi_awaddr,
    input  logic axi_awready,

    //Channel 2: Write Data
    output logic axi_wvalid,
    output logic [31:0] axi_wdata,
    output logic [3:0] axi_wstrb,
    input  logic axi_wready,

    //Channel 3: Write Response
    input  logic axi_bvalid,
    output logic axi_bready,

    //Channel 4: Read Address
    output logic axi_arvalid,
    output logic [31:0] axi_araddr,
    input  logic axi_arready,

    //Channel 5: Read Data
    input  logic axi_rvalid,
    output logic axi_rready,
    input  logic [31:0] axi_rdata
);
    typedef enum {IDLE, WRITE_ADDR, WRITE_RESPONSE, READ_ADDR, READ_DATA} states_t;
    states_t p_state, n_state;

    logic [31:0] addr_reg;
    logic [1:0] word_count;

    always_ff @(posedge clk or posedge rst) begin //state transition logic
        if(rst) begin
            p_state <= IDLE;
        end else begin
            p_state <= n_state;
        end
    end

    always_ff @(posedge clk or posedge rst) begin //data path logic
        if(rst) begin
            addr_reg <= 32'b0;
            word_count <= 2'b00;
        end 
        else if(p_state == IDLE && cmd_valid) begin
            if(cmd_is_write == 0) begin
                addr_reg <= {cmd_addr[31:4], 4'b0000};
                word_count <= 2'b00;
            end 
            else begin
                addr_reg <= cmd_addr;
            end
        end 
        else if(p_state == READ_DATA && axi_rvalid && axi_rready) begin
            word_count <= word_count + 1;
            addr_reg <= addr_reg + 4;
        end
    end

    always_comb begin
        n_state = p_state;
        cmd_ready = 1'b0;
        refill_valid = 1'b0;
        refill_data = 32'b0;
        axi_refill_done = 1'b0;

        axi_awvalid = 1'b0;
        axi_wvalid = 1'b0;
        axi_bready = 1'b0;
        axi_rready = 1'b0;
        axi_awaddr = addr_reg;
        axi_wdata = cmd_wdata;
        axi_wstrb = 4'b1111;
        axi_araddr = addr_reg; 
        axi_rready = 1'b0;

        case(p_state)
            IDLE: begin
                cmd_ready = 1'b1;
                if(cmd_valid) begin
                    if(cmd_is_write) begin
                        n_state = WRITE_ADDR;
                    end else begin
                        n_state = READ_ADDR;
                    end
                end
            end
            WRITE_ADDR: begin
                axi_awvalid = 1'b1;
                axi_wvalid = 1'b1;
                if(axi_awready && axi_wready) begin
                    n_state = WRITE_RESPONSE;
                end
            end
            WRITE_RESPONSE: begin
                axi_bready = 1'b1;
                if(axi_bvalid) begin
                    axi_refill_done = 1'b1;
                    n_state = IDLE;
                end
            end
            READ_ADDR: begin
                axi_arvalid = 1'b1;
                if(axi_arready) begin
                    n_state = READ_DATA;
                end
            end
            READ_DATA: begin
                axi_rready = 1'b1;
                if(axi_rvalid) begin
                    refill_valid = 1'b1;
                    refill_data = axi_rdata;
                    if(word_count == 2'b11) begin //last word of the block has been read
                        axi_refill_done = 1'b1;
                        n_state = IDLE;
                    end else begin
                        n_state = READ_ADDR; 
                    end
                end
            end
        endcase
    end

endmodule