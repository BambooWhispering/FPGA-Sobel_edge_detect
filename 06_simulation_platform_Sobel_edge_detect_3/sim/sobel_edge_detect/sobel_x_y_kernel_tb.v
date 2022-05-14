/*
Sobel 3*3的核求x、y方向的梯度 模块测试
*/
module sobel_x_y_kernel_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk					;	// 时钟（clock）
	reg							rst_n				;	// 复位（reset）
	
	// 输入信号（源视频信号）
	reg							din_vsync			;	// 输入数据场有效信号
	reg							din_hsync			;	// 输入数据行有效信号
	reg				[7:0]		din					;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号（Sobel核滤波后的信号）
	wire						dout_vsync			;	// 输出数据场有效信号
	wire						dout_hsync			;	// 输出数据行有效信号
	wire	signed	[15:0]		dout_grad_x			; 	// 输出x方向的梯度数据（与 输出数据行有效信号 同步）
	wire	signed	[15:0]		dout_grad_y			; 	// 输出y方向的梯度数据（与 输出数据行有效信号 同步）
	// ------
	
	
	// ---实例化测试模块---
	sobel_x_y_kernel #(
		// 视频数据流参数
		.DW					('d8			),	// 输入数据位宽（输出数据位宽为DW*2）
		.IW					('d4			),	// 输入图像宽（image width）
		
		// 行参数（多少个时钟周期）
		.H_TOTAL			('d8			),	// 行总时间
		
		// 单时钟FIFO（用于行缓存）参数
		.FIFO_DEPTH			('d1024			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
		.FIFO_DEPTH_DW		('d10			),	// SCFIFO 深度位宽
		.DEVICE_FAMILY		("Stratix III"	)	// SCFIFO 支持的设备系列
		)
	sobel_x_y_kernel_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 输入信号（源视频信号）
		.din_vsync			(din_vsync		),	// 输入数据场有效信号
		.din_hsync			(din_hsync		),	// 输入数据行有效信号
		.din				(din			),	// 输入数据（与 输入数据行有效信号 同步）
		
		// 输出信号（Sobel核滤波后的信号）
		.dout_vsync			(dout_vsync		),	// 输出数据场有效信号
		.dout_hsync			(dout_hsync		),	// 输出数据行有效信号
		.dout_grad_x		(dout_grad_x	), 	// 输出x方向的梯度数据（与 输出数据行有效信号 同步）
		.dout_grad_y		(dout_grad_y	) 	// 输出y方向的梯度数据（与 输出数据行有效信号 同步）
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
		
		#(T_CLK*2);
		
		din_vsync	= 1'b1;
		#(T_CLK*6);
		
		// ---行---
		din_hsync	= 1'b1;
		din			= 'd10;
		#T_CLK;
		din			= 'd8;
		#T_CLK;
		din			= 'd15;
		#T_CLK;
		din			= 'd39;
		#T_CLK;
		
		din_hsync	= 1'b0;
		din			= 1'b0;
		#(T_CLK*4);
		// ------
		
		
		// ---行---
		din_hsync	= 1'b1;
		din			= 'd43;
		#T_CLK;
		din			= 'd37;
		#T_CLK;
		din			= 'd7;
		#T_CLK;
		din			= 'd2;
		#T_CLK;
		
		din_hsync	= 1'b0;
		din			= 1'b0;
		#(T_CLK*4);
		// ------
		
		
		// ---行---
		din_hsync	= 1'b1;
		din			= 'd80;
		#T_CLK;
		din			= 'd62;
		#T_CLK;
		din			= 'd12;
		#T_CLK;
		din			= 'd26;
		#T_CLK;
		
		din_hsync	= 1'b0;
		din			= 1'b0;
		#(T_CLK*4);
		// ------
		
		din_vsync	= 1'b0;
		#(T_CLK*15);
		
		din_vsync	= 1'b1;
		#(T_CLK*6);
		
		// ---行---
		din_hsync	= 1'b1;
		din			= 'd10;
		#T_CLK;
		din			= 'd8;
		#T_CLK;
		din			= 'd15;
		#T_CLK;
		din			= 'd39;
		#T_CLK;
		
		din_hsync	= 1'b0;
		din			= 1'b0;
		#(T_CLK*4);
		// ------
		
		
		// ---行---
		din_hsync	= 1'b1;
		din			= 'd43;
		#T_CLK;
		din			= 'd37;
		#T_CLK;
		din			= 'd7;
		#T_CLK;
		din			= 'd2;
		#T_CLK;
		
		din_hsync	= 1'b0;
		din			= 1'b0;
		#(T_CLK*4);
		// ------
		
		
		// ---行---
		din_hsync	= 1'b1;
		din			= 'd80;
		#T_CLK;
		din			= 'd62;
		#T_CLK;
		din			= 'd12;
		#T_CLK;
		din			= 'd26;
		#T_CLK;
		
		din_hsync	= 1'b0;
		din			= 1'b0;
		#(T_CLK*4);
		// ------
		
		din_vsync	= 1'b0;
		
		#(T_CLK*30) $stop;
	end
	// ------
	
	
endmodule
