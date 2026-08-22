 module cache_direct_mapped (
    input logic clk,
    input logic rst,

    //CPU interface (SLAVE PROFILE)
    input logic req_valid_cpu,
    input logic [31:0] req_addr_cpu,
    input logic req_write_cpu,
    input logic [31:0] req_wdata_cpu,
    input logic resp_ready_cpu,

    output logic req_ready_cpu,
    output logic resp_valid_cpu,
    output logic [31:0] resp_rdata_cpu,

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
    //PARAMETERS
    localparam int CACHE_LINE = 64;
    localparam int CACHE_BYTE_SIZE = 16;
    localparam int CACHE_LINE_WORD_SIZE = CACHE_BYTE_SIZE / 4;
    localparam int CACHE_LINE_BIT_WIDTH = CACHE_BYTE_SIZE * 8;

    localparam int OFFSET_BITS = 4;
    localparam int INDEX = 6;
    localparam int TAG = 32 - OFFSET_BITS - INDEX;

    //Internal ports (CACHE INTERFACE <-> AXI INTERFACE)
    logic cmd_valid, cmd_ready;
    logic [31:0] cmd_addr;
    logic cmd_is_write;
    logic [31:0] cmd_wdata;

    logic refill_valid;
    logic [31:0] refill_data;
    logic axi_refill_done;

    axi_controller axi_controller_inst ( //INSTANTIATION OF AXI CONTROLLER
        .clk(clk),
        .rst(rst),

        //CACHE INTERFACE (MASTER PROFILE)
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_addr(cmd_addr),
        .cmd_is_write(cmd_is_write),
        .cmd_wdata(cmd_wdata),

        .refill_valid(refill_valid),
        .refill_data(refill_data),
        .axi_refill_done(axi_refill_done),

        //AXI INTERFACE
        //Channel 1: Write Address
        .axi_awvalid(axi_awvalid),
        .axi_awaddr(axi_awaddr),
        .axi_awready(axi_awready),

        //Channel 2: Write Data
        .axi_wvalid(axi_wvalid),
        .axi_wdata(axi_wdata),
        .axi_wstrb(axi_wstrb),
        .axi_wready(axi_wready),

        //Channel 3: Write Response
        .axi_bvalid(axi_bvalid),
        .axi_bready(axi_bready),

        //Channel 4: Read Address
        .axi_arvalid(axi_arvalid),
        .axi_araddr(axi_araddr),
        .axi_arready(axi_arready),

        //Channel 5: Read Data
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready),
        .axi_rdata(axi_rdata)
    );

    logic [1:0] refill_word_count;
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            refill_word_count = 1'b0;
        end else begin
            if(refill_valid) refill_word_count <= refill_word_count + 1'b1;
        end
    end

    //CACHE LINE STRUCTURE
    logic [TAG-1:0] tag;
    logic [INDEX-1:0] index;
    logic [OFFSET_BITS-1:0] offset;

    assign tag = req_addr_cpu[31:32-TAG];
    assign index = req_addr_cpu[32-TAG-1:OFFSET_BITS];
    assign offset = req_addr_cpu[OFFSET_BITS-1:0];

    logic [CACHE_LINE_BIT_WIDTH-1:0] data_array [0:2**INDEX-1];
    logic [TAG-1:0] tag_array [0:2**INDEX-1];
    logic valid_array [0:2**INDEX-1];

    //HIT LOGIC
    logic hit;
    logic [31:0] hit_data;

    assign hit = valid_array[index] && (tag_array[index] == tag);
    always_comb begin
        case(offset[3:2])
            2'b00: hit_data = data_array[index][31:0];
            2'b01: hit_data = data_array[index][63:32];
            2'b10: hit_data = data_array[index][95:64];
            2'b11: hit_data = data_array[index][127:96];
            default: hit_data = 32'b0;
        endcase
    end

    //CACHE FSM
    typedef enum cache_states {IDLE, COMPARE, STORE, WRITE_THROUGH} cache_state_t;
    cache_state_t p_state, n_state;

    always_ff@(posedge clk or posedge rst) begin
        if(rst) begin
            p_state <= IDLE;
        end else begin
            p_state <= n_state;
        end
    end

    always_comb  begin
        n_state = p_state;
        req_ready_cpu = 1'b0;
        cmd_valid = 1'b0;
        cmd_is_write = 1'b0;
        cmd_addr = 32'b0;
        cmd_wdata = 32'b0;
        resp_valid_cpu = 1'b0;

        case(p_state)
            IDLE: begin
                req_ready_cpu = 1'b1;
                if(req_valid_cpu) begin
                    n_state = COMPARE;
                end else n_state = IDLE;
            end
            COMPARE: begin
                if(req_write_cpu) begin
                    n_state = WRITE_THROUGH;
                end 
                else if(hit)begin
                    resp_valid_cpu = 1'b1;
                    n_state = IDLE;
                end else n_state = STORE; //miss logic
            end
            STORE: begin
                cmd_valid = 1'b1;
                cmd_is_write = 1'b0;
                cmd_addr = req_addr_cpu;

                if(axi_refill_done) begin
                    n_state = COMPARE;
                end
            end
            WRITE_THROUGH: begin
                cmd_valid = 1'b1;
                cmd_is_write = 1'b1;
                cmd_addr = req_addr_cpu;
                cmd_wdata = req_wdata_cpu;
                if(axi_refill_done) begin
                    n_state = IDLE;
                end
            end 
        endcase
    end

    //WRITE LOGIC
    always_ff @(posedge clk) begin
        if(rst) begin
            for(int i = 0; i < 2**INDEX; i++) begin
                valid_array[i] <= 1'b0;
            end
        end
        else begin 
                if(p_state == COMPARE &&  req_write_cpu && hit) begin //CPU HIT
                case(offset[3:2])
                    2'b00: data_array[index][31:0] <= req_wdata_cpu;
                    2'b01: data_array[index][63:32] <= req_wdata_cpu;
                    2'b10: data_array[index][95:64] <= req_wdata_cpu;
                    2'b11: data_array[index][127:96] <= req_wdata_cpu;
                endcase
            end
            else if (p_state==STORE && refill_valid) begin //AXI REFILL
                case(refill_word_count)
                    2'b00: data_array[index][31:0] <= refill_data;
                    2'b01: data_array[index][63:32] <= refill_data;
                    2'b10: data_array[index][95:64] <= refill_data;
                    2'b11: data_array[index][127:96] <= refill_data;
                endcase
            end
            
            if(p_state == STORE && axi_refill_done) begin
                tag_array[index] <= tag;
                valid_array[index] <= 1'b1;
            end
        end
    end

endmodule