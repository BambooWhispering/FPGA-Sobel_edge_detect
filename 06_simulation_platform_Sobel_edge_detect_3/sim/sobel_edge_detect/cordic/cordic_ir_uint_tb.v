/*
Cordic单次迭代（微伪旋转）处理单元 模块测试
*/
`timescale 1ns/1ns
module cordic_ir_uint_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk					;	// 时钟（clock）
	reg							rst_n				;	// 复位（reset）
	
	// 单次Cordic迭代前的信号
	reg							din_vsync			;	// 输入数据场有效信号
	reg							din_hsync			;	// 输入数据行有效信号
	reg		signed	[15:0]		din_x				;	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	reg		signed	[15:0]		din_y				;	// 输入数据的y坐标（与 输入数据行有效信号 同步）
	reg		signed	[19:0]		din_z				;	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	
	// 单次Cordic迭代后的信号
	wire						dout_vsync			;	// 输出数据场有效信号
	wire						dout_hsync			;	// 输出数据行有效信号
	wire	signed	[15:0]		dout_x				;	// 输出数据的x坐标（与 输出数据行有效信号 同步）
	wire	signed	[15:0]		dout_y				;	// 输出数据的y坐标（与 输出数据行有效信号 同步）
	wire	signed	[19:0]		dout_z				;	// 输出数据的z坐标（与 输出数据行有效信号 同步）
	
	integer						i					;	// for循环计数
	// ------
	
	
	// ---实例化测试模块---
	cordic_ir_uint #(
		// 视频数据流参数
		// 设x、y绝对值最大值为max_x_y，则迭代结果最大值不超过2*max_x_y，故需要保留一位用于迭代过程。
		// 即 输入数据x、y坐标的 最高位为符号位，次高位保留为0，
		// 即 输入数据x、y坐标的绝对值 保存在 低DW-2位
		.DW					('d16			),	// 输入数据x、y坐标位宽
		
		// Cordic参数
		.P_IR_ID			('d2			),	// 当前迭代次数编号（present iteration identity）
		.T_IR_NUM			('d15			)	// 总迭代次数（total iteration number）（可选 15~18）
		)
	cordic_ir_uint_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 单次Cordic迭代前的信号
		.din_vsync			(din_vsync		),	// 输入数据场有效信号
		.din_hsync			(din_hsync		),	// 输入数据行有效信号
		.din_x				(din_x			),	// 输入数据的x坐标（与 输入数据行有效信号 同步）
		.din_y				(din_y			),	// 输入数据的y坐标（与 输入数据行有效信号 同步）
		.din_z				(din_z			),	// 输入数据的z坐标（与 输入数据行有效信号 同步）
		
		// 单次Cordic迭代后的信号
		.dout_vsync			(dout_vsync		),	// 输出数据场有效信号
		.dout_hsync			(dout_hsync		),	// 输出数据行有效信号
		.dout_x				(dout_x			),	// 输出数据的x坐标（与 输出数据行有效信号 同步）
		.dout_y				(dout_y			),	// 输出数据的y坐标（与 输出数据行有效信号 同步）
		.dout_z				(dout_z			)	// 输出数据的z坐标（与 输出数据行有效信号 同步）
		);
	// ------
	
	
	// ---系统时钟信号 产生---
	localparam T_CLK = 20; // 系统时钟（100MHz）周期：20ns
	initial
		clk = 1'b1;
	always #(T_CLK/2)
		clk = ~clk;
	// ------
	
	
	// ---复位任务---
	task task_reset;
	begin
		rst_n = 1'b0;
		repeat(10) @(negedge clk)
			rst_n = 1'b1;
	end
	endtask
	// ------
	
	
	// ---系统初始化 任务---
	task task_sysinit;
	begin
		din_vsync	= 1'b0;
		din_hsync	= 1'b0;
		din_x		= 1'b0;
		din_y		= 1'b0;
		din_z		= 1'b0;
	end
	endtask
	// ------
	
	
	// ---激励信号 产生---
	initial
	begin
		task_sysinit;
		task_reset;
		
		#(T_CLK*2);
		din_vsync	= 1'b1;
		
		#(T_CLK*2);
		din_hsync	= 1'b1;
		din_x		= $signed(176);
		din_y		= $signed(-32);
		din_z		= $signed('hD1C0);
		
		#T_CLK;
		din_hsync	= 1'b0;
		din_x		= $signed(0);
		din_y		= $signed(0);
		din_z		= $signed(0);
		
		#(T_CLK*2);
		din_vsync	= 1'b0;
		
		#(T_CLK*10) $stop;
	end
	// ------
	
	
endmodule
