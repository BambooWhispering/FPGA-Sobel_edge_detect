/*
上下边界补充 测试模块
*/
module bound_up_down_add_tb();
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk						;	// 时钟（clock）
	reg							rst_n					;	// 复位（reset）
	
	// 输入信号
	reg							din_vsync				;	// 输入数据场有效信号
	reg							din_hsync				;	// 输入数据行有效信号
	reg			[ 7:0]			din						;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号
	wire						dout_vsync				;	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	wire						dout_hsync				;	// 输出数据行有效信号
	wire		[ 7:0]			dout					; 	// 输出数据（与 输出数据行有效信号 同步）
	// ------
	
	
	// ---实例化测试模块---
	bound_up_down_add #(
		// 核参数
		.KSZ				('d5					),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
		
		// 视频数据流参数
		.DW					('d8					),	// 输入数据位宽
		.IW					('d4					),	// 输入图像宽（image width）
		.IH					('d2					),	// 输入图像高（image height）
		
		// 行参数（多少个时钟周期）
		.H_TOTAL			('d6					),	// 行总时间
		// 场参数（多少个时钟周期，注意这里不是多少行！！！）
		.V_FRONT_CLK		('d3					),	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
		
		// 单时钟FIFO（用于行缓存）参数
		.FIFO_DEPTH			('d16					),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
		.FIFO_DEPTH_DW		('d4					),	// SCFIFO 深度位宽
		.DEVICE_FAMILY		("Stratix III"			)	// SCFIFO 支持的设备系列
		)
	bound_up_down_add_u0(
		// 系统信号
		.clk				(clk					),	// 时钟（clock）
		.rst_n				(rst_n					),	// 复位（reset）
		
		// 输入信号
		.din_vsync			(din_vsync				),	// 输入数据场有效信号
		.din_hsync			(din_hsync				),	// 输入数据行有效信号
		.din				(din					),	// 输入数据（与 输入数据行有效信号 同步）
		
		// 输出信号
		.dout_vsync			(dout_vsync				),	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
		.dout_hsync			(dout_hsync				),	// 输出数据行有效信号
		.dout				(dout					) 	// 输出数据（与 输出数据行有效信号 同步）
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
		din			= 1'b0;
	end
	endtask
	// ------
	
	
	// ---激励信号 产生---
	initial
	begin
		task_sysinit;
		task_reset;
		
		#(T_CLK*1);
		din_vsync	= 1'b1;
		
		#(T_CLK*5);
		din_hsync	= 1'b1;
		din			= 'd20;
		#T_CLK;
		din			= 'd18;
		#T_CLK;
		din			= 'd32;
		#T_CLK;
		din			= 'd11;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		
		#(T_CLK*2);
		din_hsync	= 1'b1;
		din			= 'd51;
		#T_CLK;
		din			= 'd33;
		#T_CLK;
		din			= 'd67;
		#T_CLK;
		din			= 'd2;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		
		#(T_CLK*3);
		din_vsync	= 1'b0;
		
		
		#(T_CLK*30);
		din_vsync	= 1'b1;
		
		#(T_CLK*5);
		din_hsync	= 1'b1;
		din			= 'd20;
		#T_CLK;
		din			= 'd18;
		#T_CLK;
		din			= 'd32;
		#T_CLK;
		din			= 'd11;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		#(T_CLK*2);
		din_hsync	= 1'b1;
		din			= 'd51;
		#T_CLK;
		din			= 'd33;
		#T_CLK;
		din			= 'd67;
		#T_CLK;
		din			= 'd2;
		
		#T_CLK;
		din_hsync	= 1'b0;
		din			= 1'b0;
		
		$stop;
	end
	// ------
	
	
	
endmodule
