/*
Cordic一次总旋转（伪旋转，未进行模长补偿） 模块测试
*/
`timescale 1ns/1ns
module cordic_core_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk					;	// 时钟（clock）
	reg							rst_n				;	// 复位（reset）
	
	// 一次Cordic总旋转前的信号
	// （因为是从0°~45°位置开始旋转的，也就是第一象限的1/4象限，故开始旋转前，x、y均>=0，而z取方向为从0到目标角 即 z=0，故x、y、z均不需要有符号位）
	reg							din_vsync			;	// 输入数据场有效信号
	reg							din_hsync			;	// 输入数据行有效信号
	reg		[15:0]				din_x				;	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	reg		[15:0]				din_y				;	// 输入数据的y坐标（与 输入数据行有效信号 同步）
	reg		[19:0]				din_z				;	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	
	// 一次Cordic总旋转后的信号
	// （因为最终旋转到0°，故总旋转后，x>0，y坐标一定趋近于0 即 不需要输出y坐标，
	// 而起始总旋转位置为第一象限的1/4象限，故总旋转后，z趋近于起始旋转角度 即 z>=0，故x、z均不需要符号位）
	wire						dout_vsync			;	// 输出数据场有效信号
	wire						dout_hsync			;	// 输出数据行有效信号
	wire	[19:0]				dout_x				;	// 输出数据的x坐标（与 输出数据行有效信号 同步）（扩展了小数位）
	wire	[19:0]				dout_z				;	// 输出数据的z坐标（与 输出数据行有效信号 同步）
	// ------
	
	
	// ---实例化测试模块---
	cordic_core #(
		// 视频数据流参数
		// 设x、y绝对值最大值为max_x_y，则最终迭代结果最大值不超过2*max_x_y，故需要保留一位用于迭代过程。
		// 即 输入数据x、y坐标的 最高位为符号位，次高位保留为0，
		// 即 输入数据x、y坐标的绝对值 保存在 低DW-2位
		.DW					('d16			),	// 输入数据x、y坐标位宽
		
		// Cordic参数
		.T_IR_NUM			('d15			),	// 总迭代次数（total iteration number）（可选 15~18）
		.DW_DOT				('d4			)	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输出数据x、y坐标位宽=DW+DW_DOT 须<=32）
		)
	cordic_core_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 一次Cordic总旋转前的信号
		// （因为是从0°~45°位置开始旋转的，也就是第一象限的1/4象限，故开始旋转前，x、y均>=0，而z取方向为从0到目标角 即 z=0，故x、y、z均不需要有符号位）
		.din_vsync			(din_vsync		),	// 输入数据场有效信号
		.din_hsync			(din_hsync		),	// 输入数据行有效信号
		.din_x				(din_x			),	// 输入数据的x坐标（与 输入数据行有效信号 同步）
		.din_y				(din_y			),	// 输入数据的y坐标（与 输入数据行有效信号 同步）
		.din_z				(din_z			),	// 输入数据的z坐标（与 输入数据行有效信号 同步）
		
		// 一次Cordic总旋转后的信号
		// （因为最终旋转到0°，故总旋转后，x>0，y坐标一定趋近于0 即 不需要输出y坐标，
		// 而起始总旋转位置为第一象限的1/4象限，故总旋转后，z趋近于起始旋转角度 即 z>=0，故x、z均不需要符号位）
		.dout_vsync			(dout_vsync		),	// 输出数据场有效信号
		.dout_hsync			(dout_hsync		),	// 输出数据行有效信号
		.dout_x				(dout_x			),	// 输出数据的x坐标（与 输出数据行有效信号 同步）
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
		
		#(T_CLK*3);
		din_hsync	= 1'b1;
		din_x		= 'd112;
		din_y		= 'd16;
		din_z		= 'd0;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din_x		= 1'b0;
		din_y		= 1'b0;
		din_z		= 1'b0;
		
		#(T_CLK*4);
		din_vsync	= 1'b0;
		
		#(T_CLK*15) $stop;
	end
	// ------
	
	
endmodule
