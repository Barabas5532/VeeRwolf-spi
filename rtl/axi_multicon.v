`default_nettype none
module axi_multicon
  #(parameter ID_WIDTH = 0)
   (input 		  clk,
    input 		  rst_n,
    output reg 		  o_gpio,
    output reg 		  o_timer_irq,
    input [ID_WIDTH-1:0]  i_awid,
    input [31:0] 	  i_awaddr,
    input [7:0] 	  i_awlen,
    input [2:0] 	  i_awsize,
    input [1:0] 	  i_awburst,
    input 		  i_awvalid,
    output 		  o_awready,

    input [ID_WIDTH-1:0]  i_arid,
    input [31:0] 	  i_araddr,
    input [7:0] 	  i_arlen,
    input [2:0] 	  i_arsize,
    input [1:0] 	  i_arburst,
    input 		  i_arvalid,
    output 		  o_arready,

    input [63:0] 	  i_wdata,
    input [7:0] 	  i_wstrb,
    input 		  i_wlast,
    input 		  i_wvalid,
    output 		  o_wready,

    output [ID_WIDTH-1:0] o_bid,
    output [1:0] 	  o_bresp,
    output 		  o_bvalid,
    input 		  i_bready,

    output [ID_WIDTH-1:0] o_rid,
    output [63:0] 	  o_rdata,
    output [1:0] 	  o_rresp,
    output 		  o_rlast,
    output 		  o_rvalid,
    input 		  i_rready);

   wire 	 reg_we;
   wire [31:0] 	 reg_addr;
   wire [7:0] 	 reg_be;
   wire [63:0] 	 reg_wdata;
   reg [63:0] 	 reg_rdata;

   AXI_BUS #(32, 64, ID_WIDTH, 1) slave();

   assign slave.aw_id    = i_awid   ;
   assign slave.aw_addr  = i_awaddr ;
   assign slave.aw_len   = i_awlen  ;
   assign slave.aw_size  = i_awsize ;
   assign slave.aw_burst = i_awburst;
   assign slave.aw_valid = i_awvalid;
   assign o_awready = slave.aw_ready;

   assign slave.ar_id    = i_arid   ;
   assign slave.ar_addr  = i_araddr ;
   assign slave.ar_len   = i_arlen  ;
   assign slave.ar_size  = i_arsize ;
   assign slave.ar_burst = i_arburst;
   assign slave.ar_valid = i_arvalid;
   assign o_arready = slave.ar_ready;

   assign slave.w_data  = i_wdata ;
   assign slave.w_strb  = i_wstrb ;
   assign slave.w_last  = i_wlast ;
   assign slave.w_valid = i_wvalid;
   assign o_wready = slave.w_ready;

   assign o_bid    = slave.b_id   ;
   assign o_bresp  = slave.b_resp ;
   assign o_bvalid = slave.b_valid;
   assign slave.b_ready = i_bready;

   assign o_rid    = slave.r_id   ;
   assign o_rdata  = slave.r_data ;
   assign o_rresp  = slave.r_resp ;
   assign o_rlast  = slave.r_last ;
   assign o_rvalid = slave.r_valid;
   assign slave.r_ready = i_rready;

   axi2mem
     #(.AXI_ID_WIDTH   (ID_WIDTH),
       .AXI_ADDR_WIDTH (32),
       .AXI_DATA_WIDTH (64),
       .AXI_USER_WIDTH (0))
   ram_axi2mem
     (.clk_i  (clk),
      .rst_ni (rst_n),
      .slave  (slave),
      .req_o  (),
      .we_o   (reg_we),
      .addr_o (reg_addr),
      .be_o   (reg_be),
      .data_o (reg_wdata),
      .data_i (reg_rdata));

   reg [31:0] 	 mtime;
   reg [31:0] 	 mtimecmp;
`ifdef SIMPRINT
   reg [1023:0]  signature_file;
   integer 	f = 0;
   initial begin
      if ($value$plusargs("signature=%s", signature_file)) begin
	 $display("Writing signature to %0s", signature_file);
	 f = $fopen(signature_file, "w");
      end
   end
`endif

`ifndef SWERVOLF_FPGA_VERSION_DIRTY
 `define SWERVOLF_FPGA_VERSION_DIRTY 1
`endif
`ifndef SWERVOLF_FPGA_VERSION_MAJOR
 `define SWERVOLF_FPGA_VERSION_MAJOR 255
`endif
`ifndef SWERVOLF_FPGA_VERSION_MINOR
 `define SWERVOLF_FPGA_VERSION_MINOR 255
`endif
`ifndef SWERVOLF_FPGA_VERSION_REV
 `define SWERVOLF_FPGA_VERSION_REV 255
`endif
`ifndef SWERVOLF_SHA
 `define SWERVOLF_SHA 32'hdeadbeef
`endif

   wire [31:0] version;

   assign version[31]    = `SWERVOLF_FPGA_VERSION_DIRTY;
   assign version[30:24] = 7'd0;
   assign version[23:16] = `SWERVOLF_FPGA_VERSION_MAJOR;
   assign version[15: 8] = `SWERVOLF_FPGA_VERSION_MINOR;
   assign version[ 7: 0] = `SWERVOLF_FPGA_VERSION_REV;

   localparam [2:0]
     REG_VERSION  = 3'd0,
     REG_SHA      = 3'd1,
     REG_SIMPRINT = 3'd4,
     REG_SIMEXIT  = 3'd5;
//0 = ver
   //4 = sha
   //8 = simprint
   //9 = simexit
   //10 = gpio
   //18 = timer/timecmp
   always @(posedge clk) begin
      if (reg_we)
	case (reg_addr[4:3])
`ifdef SIMPRINT
	  1: begin
	     if (reg_be[0]) begin
		$fwrite(f, "%c", reg_wdata[7:0]);
		$write("%c", reg_wdata[7:0]);
	     end
	     if (reg_be[1]) begin
		$display("Finito");
		$finish;
	     end
	  end
`endif
	  2 : o_gpio <= reg_wdata[0];
	  3 : mtimecmp <= reg_wdata[31:0];
	endcase

      case (reg_addr[4:3])
	0 : reg_rdata <= {`SWERVOLF_SHA, version};
	3 : reg_rdata <= mtime;
      endcase

      mtime <= mtime + 32'd1;
      o_timer_irq <= (mtime >= mtimecmp);
   end
endmodule
