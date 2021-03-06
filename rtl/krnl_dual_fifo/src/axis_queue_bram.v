`timescale 1ns / 1ps

module axis_queue_bram #(
    parameter DWIDTH = 32,
    parameter QDEPTH = 16
) (
    input  wire clk,
    input  wire rst,
    // Upstream
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_din TDATA" *)
    input  wire [DWIDTH-1:0] s_din_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_din TVALID" *)
    input  wire s_din_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 s_din TREADY" *)
    output wire s_din_tready,
    // Downstream
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_dout TDATA" *)
    output reg  [DWIDTH-1:0] m_dout_tdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_dout TVALID" *)
    output wire m_dout_tvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 m_dout TREADY" *)
    input  wire m_dout_tready
);

(* ram_style = "block" *)
reg [DWIDTH-1:0] mem [0:QDEPTH-1];

// Cyclic buffer pointers
reg [$clog2(QDEPTH)-1:0] front, back;
wire [$clog2(QDEPTH)-1:0] nextFront, nextBack;

wire mFull, mEmpty, mPop, mPush;

assign mEmpty = front == back;
assign mFull = nextBack == front;
assign mPush = s_din_tready && s_din_tvalid;
assign mPop = m_dout_tready && m_dout_tvalid;
assign nextFront = (front == QDEPTH - 1) ? 0 : front + 1;
assign nextBack = (back == QDEPTH - 1) ? 0 : back + 1;
assign s_din_tready = !rst && !mFull;
assign m_dout_tvalid = !rst && !mEmpty;

initial begin
    front = 0;
    back = 0;
end

always @ (posedge clk) begin
    if (rst) begin
        front <= 0;
        back <= 0;
    end else begin
        if (mPush) begin
            mem[back] <= s_din_tdata;
            back <= nextBack;
        end
        if (mPop)
            front <= nextFront;
        if (mEmpty) begin
            if (mPush)
                m_dout_tdata <= s_din_tdata;
        end else begin
            if (mPop)
                m_dout_tdata <= mem[nextFront];
            else
                m_dout_tdata <= mem[front];
        end
    end
end

endmodule
