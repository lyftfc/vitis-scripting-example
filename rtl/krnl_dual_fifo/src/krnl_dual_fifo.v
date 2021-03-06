`default_nettype none
`timescale 1 ns / 1 ps

module krnl_cached_cuckoo #(
  parameter integer C_S_AXI_CONTROL_ADDR_WIDTH = 12,
  parameter integer C_S_AXI_CONTROL_DATA_WIDTH = 32,
  parameter DWIDTH_A = 16,
  parameter DEPTH_A = 8,
  parameter DWIDTH_B = 16,
  parameter DEPTH_B = 8
) (
  // System Signals
  input  wire                       ap_clk         ,
  input  wire                       ap_rst_n       ,
  // AXI4-Stream (slave) interface s_dina
  input  wire                       s_dina_tvalid  ,
  output wire                       s_dina_tready  ,
  input  wire [DWIDTH_A-1:0]        s_dina_tdata   ,
  input  wire [DWIDTH_A/8-1:0]      s_dina_tkeep   ,
  input  wire                       s_dina_tlast   ,
  // AXI4-Stream (slave) interface s_dinb
  input  wire                       s_dinb_tvalid  ,
  output wire                       s_dinb_tready  ,
  input  wire [DWIDTH_B-1:0]        s_dinb_tdata   ,
  input  wire [DWIDTH_B/8-1:0]      s_dinb_tkeep   ,
  input  wire                       s_dinb_tlast   ,
  // AXI4-Stream (master) interface m_douta
  output wire                       m_douta_tvalid ,
  input  wire                       m_douta_tready ,
  output wire [DWIDTH_A-1:0]        m_douta_tdata  ,
  output wire [DWIDTH_A/8-1:0]      m_douta_tkeep  ,
  output wire                       m_douta_tlast  ,
  // AXI4-Stream (master) interface m_doutb
  output wire                       m_doutb_tvalid ,
  input  wire                       m_doutb_tready ,
  output wire [DWIDTH_B-1:0]        m_doutb_tdata  ,
  output wire [DWIDTH_B/8-1:0]      m_doutb_tkeep  ,
  output wire                       m_doutb_tlast  ,
  // AXI4-Lite slave interface
  input  wire                                    s_axi_control_awvalid,
  output wire                                    s_axi_control_awready,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   s_axi_control_awaddr ,
  input  wire                                    s_axi_control_wvalid ,
  output wire                                    s_axi_control_wready ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   s_axi_control_wdata  ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] s_axi_control_wstrb  ,
  input  wire                                    s_axi_control_arvalid,
  output wire                                    s_axi_control_arready,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   s_axi_control_araddr ,
  output wire                                    s_axi_control_rvalid ,
  input  wire                                    s_axi_control_rready ,
  output wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   s_axi_control_rdata  ,
  output wire [2-1:0]                            s_axi_control_rresp  ,
  output wire                                    s_axi_control_bvalid ,
  input  wire                                    s_axi_control_bready ,
  output wire [2-1:0]                            s_axi_control_bresp  
);

(* DONT_TOUCH = "yes" *)
reg                                 areset                         = 1'b0;

// Register and invert reset signal.
always @(posedge ap_clk) begin
  areset <= ~ap_rst_n;
end

// AXI4-Lite slave interface
s_axi_ctrl_none #(
  .C_S_AXI_ADDR_WIDTH ( C_S_AXI_CONTROL_ADDR_WIDTH ),
  .C_S_AXI_DATA_WIDTH ( C_S_AXI_CONTROL_DATA_WIDTH )
)
inst_control_s_axi (
  .ACLK    ( ap_clk                ),
  .ARESET  ( areset                ),
  .ACLK_EN ( 1'b1                  ),
  .AWVALID ( s_axi_control_awvalid ),
  .AWREADY ( s_axi_control_awready ),
  .AWADDR  ( s_axi_control_awaddr  ),
  .WVALID  ( s_axi_control_wvalid  ),
  .WREADY  ( s_axi_control_wready  ),
  .WDATA   ( s_axi_control_wdata   ),
  .WSTRB   ( s_axi_control_wstrb   ),
  .ARVALID ( s_axi_control_arvalid ),
  .ARREADY ( s_axi_control_arready ),
  .ARADDR  ( s_axi_control_araddr  ),
  .RVALID  ( s_axi_control_rvalid  ),
  .RREADY  ( s_axi_control_rready  ),
  .RDATA   ( s_axi_control_rdata   ),
  .RRESP   ( s_axi_control_rresp   ),
  .BVALID  ( s_axi_control_bvalid  ),
  .BREADY  ( s_axi_control_bready  ),
  .BRESP   ( s_axi_control_bresp   )
);

///////////////////////////////////////////////////////////////////////////////
// Add kernel logic here.  Modify/remove example code as necessary.
///////////////////////////////////////////////////////////////////////////////

axis_queue_bram #(
    .DWIDTH  (DWIDTH_A),
    .QDEPTH  (DEPTH_A)
) fifo_a (
  .clk           ( ap_clk          ),
  .rst           ( areset          ),
  .s_din_tvalid  ( s_dina_tvalid   ),
  .s_din_tready  ( s_dina_tready   ),
  .s_din_tdata   ( s_dina_tdata    ),
  .m_dout_tvalid ( m_douta_tvalid  ),
  .m_dout_tready ( m_douta_tready  ),
  .m_dout_tdata  ( m_douta_tdata   )
);

axis_queue_bram #(
    .DWIDTH  (DWIDTH_B),
    .QDEPTH  (DEPTH_B)
) fifo_b (
  .clk           ( ap_clk          ),
  .rst           ( areset          ),
  .s_din_tvalid  ( s_dinb_tvalid   ),
  .s_din_tready  ( s_dinb_tready   ),
  .s_din_tdata   ( s_dinb_tdata    ),
  .m_dout_tvalid ( m_doutb_tvalid  ),
  .m_dout_tready ( m_doutb_tready  ),
  .m_dout_tdata  ( m_doutb_tdata   )
);

assign m_douta_tkeep = {(DWIDTH_A/8){1'b1}};
assign m_doutb_tkeep = {(DWIDTH_B/8){1'b1}};
assign m_douta_tlast = 1'b1;
assign m_doutb_tlast = 1'b1;

endmodule
`default_nettype wire
