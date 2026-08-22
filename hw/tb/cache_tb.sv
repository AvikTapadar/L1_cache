`timescale 1ns/1ps
module cache_tb;
    logic clk = 0, rst;

    //CPU interface (SLAVE PROFILE)
    logic req_valid_cpu;
    logic [31:0] req_addr_cpu;
    logic req_write_cpu;
    logic [31:0] req_wdata_cpu;
    logic resp_ready_cpu;

    logic req_ready_cpu;
    logic resp_valid_cpu;
    logic [31:0] resp_rdata_cpu;

    //AXI INTERFACE
    //Channel 1: Write Address
    logic axi_awvalid;
    logic [31:0] axi_awaddr;
    logic axi_awready;

    //Channel 2: Write Data
    logic axi_wvalid;
    logic [31:0] axi_wdata;
    logic [3:0] axi_wstrb;
    logic axi_wready;

    //Channel 3: Write Response
    logic axi_bvalid;
    logic axi_bready;

    //Channel 4: Read Address
    logic axi_arvalid;
    logic [31:0] axi_araddr;
    logic axi_arready; 

    //Channel 5: Read Data
    logic axi_rvalid;
    logic axi_rready;
    logic [31:0] axi_rdata;

    cache_direct_mapped cache_inst (
        .clk(clk),
        .rst(rst),

        //CPU interface (SLAVE PROFILE)
        .req_valid_cpu(req_valid_cpu),
        .req_addr_cpu(req_addr_cpu),
        .req_write_cpu(req_write_cpu),
        .req_wdata_cpu(req_wdata_cpu),
        .resp_ready_cpu(resp_ready_cpu),

        .req_ready_cpu(req_ready_cpu),
        .resp_valid_cpu(resp_valid_cpu),
        .resp_rdata_cpu(resp_rdata_cpu),

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

    logic [31:0] mem [0:1023]; // memory array 
    always #5 clk = ~clk; //10ns clock period

    initial begin
        for(int i=0; i<1024; i++) begin
            mem[i] = i;
        end
    end

    always_ff @(posedge clk) begin //AXI_WRITE_SLAVE 
        axi_wready <= 1'b1;
        axi_awready <= 1'b1;
        if(axi_awvalid && axi_wvalid) begin
            mem[axi_awaddr[31:2]] <= axi_wdata;
        end
    end

    always_ff @(posedge clk) begin //AXI_READ_SLAVE
        axi_arready <= 1'b1;
        if(axi_arvalid) begin
            axi_rdata <= mem[axi_araddr[31:2]];
            axi_rvalid <= 1'b1;
        end 
        if (axi_rready && axi_rvalid) begin
            axi_rvalid <= 1'b0;
        end
    end
