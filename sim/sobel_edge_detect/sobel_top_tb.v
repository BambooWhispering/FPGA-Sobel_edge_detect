/*
Sobel边缘检测顶层模块测试
*/
module sobel_top_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk					;	// 时钟（clock）
	reg							rst_n				;	// 复位（reset）
	
	// 输入信号（源视频信号）
	reg							sb_din_vsync		;	// 输入数据场有效信号
	reg							sb_din_hsync		;	// 输入数据行有效信号
	reg		[7:0]				sb_din				;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号（Sobel边缘检测后的信号）
	wire						sb_dout_vsync		;	// 输出数据场有效信号
	wire						sb_dout_hsync		;	// 输出数据行有效信号
	wire	[7:0]				sb_dout				; 	// 输出梯度数据（与 输出数据行有效信号 同步）
	wire	[19:0]				sb_dout_angle		;	// 输出梯度与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
	// ------
	
	
	// ---实例化测试模块---
	sobel_top #(
		// 视频数据流参数
		.DW					('d8			),	// 输入数据位宽（输出数据位宽为DW*2）
		.IW					('d5			),	// 输入图像宽（image width）
		.IH					('d3			),	// 输入图像高（image height）
		
		// 行参数
		.H_TOTAL			('d12			),	// 行总时间
		// 场参数（多少个时钟周期，注意这里不是多少行！！！）
		.V_FRONT_CLK		('d3			),	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
		
		// 单时钟FIFO（用于行缓存）参数
		.FIFO_DEPTH			('d1024			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
		.FIFO_DEPTH_DW		('d10			),	// SCFIFO 深度位宽
		.DEVICE_FAMILY		("Stratix III"	),	// SCFIFO 支持的设备系列
		
		// 参数选择
		.IS_BOUND_ADD		(1'b1			),	// 是否要进行边界补充（1——补充边界；0——忽略边界）
		
		// Cordic参数
		.T_IR_NUM			('d15			),	// 总迭代次数（total iteration number）（可选 15~18）
		.DW_DOT				('d4			),	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输入数据x、y坐标位宽=DW_x_y+DW_DOT 须<=32）
		
		// Sobel结果二值化阈值参数
		.BIANRY_THRESHOLD	('d128			)	// 二值化时的阈值（大于等于该阈值的输出全1，小于该阈值的输出0）（一般取输入值的一半）
		)
	sobel_top_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 输入信号（源视频信号）
		.sb_din_vsync		(sb_din_vsync	),	// 输入数据场有效信号
		.sb_din_hsync		(sb_din_hsync	),	// 输入数据行有效信号
		.sb_din				(sb_din			),	// 输入数据（与 输入数据行有效信号 同步）
		
		// 输出信号（Sobel边缘检测后的信号）
		.sb_dout_vsync		(sb_dout_vsync	),	// 输出数据场有效信号
		.sb_dout_hsync		(sb_dout_hsync	),	// 输出数据行有效信号
		.sb_dout			(sb_dout		), 	// 输出梯度数据（与 输出数据行有效信号 同步）
		.sb_dout_angle		(sb_dout_angle	),	// 输出梯度与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
		
		// Sobel选择参数
		.is_binary			(1'b0			)	// 是否要对边缘检测结果进行二值化（二值化 即 输出只能为0或全1）
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
		sb_din_vsync	= 1'b0;
		sb_din_hsync	= 1'b0;
		sb_din			= 1'b0;
	end
	endtask
	// ------
	
	
	// ---激励信号 产生---
	initial
	begin
		task_sysinit;
		task_reset;
		
		#(T_CLK*2);
		
		// ---行---
		sb_din_vsync	= 1'b1;
		#(T_CLK*9);
		
		sb_din_hsync	= 1'b1;
		sb_din			= 'd10;
		#T_CLK;
		
		sb_din			= 'd27;
		#T_CLK;
		
		sb_din			= 'd34;
		#T_CLK;
		
		sb_din			= 'd18;
		#T_CLK;
		
		sb_din			= 'd50;
		#T_CLK;
		
		sb_din_hsync	= 1'b0;
		sb_din			= 1'b0;
		#(T_CLK*4);
		// ------
		
		
		// ---行---
		sb_din_vsync	= 1'b1;
		#(T_CLK*3);
		
		sb_din_hsync	= 1'b1;
		sb_din			= 'd60;
		#T_CLK;
		
		sb_din			= 'd11;
		#T_CLK;
		
		sb_din			= 'd216;
		#T_CLK;
		
		sb_din			= 'd248;
		#T_CLK;
		
		sb_din			= 'd100;
		#T_CLK;
		
		sb_din_hsync	= 1'b0;
		sb_din			= 1'b0;
		#(T_CLK*4);
		// ------
		
		
		// ---行---
		sb_din_vsync	= 1'b1;
		#(T_CLK*3);
		
		sb_din_hsync	= 1'b1;
		sb_din			= 'd110;
		#T_CLK;
		
		sb_din			= 'd128;
		#T_CLK;
		
		sb_din			= 'd135;
		#T_CLK;
		
		sb_din			= 'd230;
		#T_CLK;
		
		sb_din			= 'd150;
		#T_CLK;
		
		sb_din_hsync	= 1'b0;
		sb_din			= 1'b0;
		#(T_CLK*3);
		// ------
		
		sb_din_vsync	= 1'b0;
		#(T_CLK*7);
		
		#(T_CLK*100) $stop;
	end
	// ------
	
	
endmodule
