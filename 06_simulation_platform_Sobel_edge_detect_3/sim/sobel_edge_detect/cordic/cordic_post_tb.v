/*
Cordic一次总旋转（伪旋转）的后处理 模块测试
*/
module cordic_post_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg								clk					;	// 时钟（clock）
	reg								rst_n				;	// 复位（reset）
	
	// 一次Cordic总旋转（伪旋转）后处理前的信号
	reg								din_vsync			;	// 输入数据场有效信号
	reg								din_hsync			;	// 输入数据行有效信号
	reg			[19:0]				din_x				;	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	reg			[19:0]				din_z				;	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	// 输入总旋转前的源向量信息（与 输出数据行有效信号 同步）：
	// 第2位表示源向量x坐标符号（0表示正数，1表示负数），
	// 第1位表示源向量y坐标符号（0表示正数，1表示负数），
	// 第0位表示映射到第一象限后的x、y坐标是否需要经过互换才能继续映射到1/4象限（0表示不需要互换，1表示需要互换）。
	reg			[ 2:0]				din_info			;	// 输入总旋转前的源向量信息（与 输出数据行有效信号 同步）
	
	// 一次Cordic总旋转（伪旋转）后处理后的信号
	wire							dout_vsync			;	// 输出数据场有效信号
	wire							dout_hsync			;	// 输出数据行有效信号
	wire		[15:0]				dout_x				;	// 输出数据的x坐标（与 输出数据行有效信号 同步）（源向量的模长）
	wire		[19:0]				dout_z				;	// 输出数据的z坐标（源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)）
	// ------
	
	
	// ---实例化测试模块---
	cordic_post #(
		// 视频数据流参数
		.DW					('d16			),	// 输出数据x、y坐标位宽
		
		// Cordic参数
		.T_IR_NUM			('d15			),	// 总迭代次数（total iteration number）（可选 15~18）
		.DW_DOT				('d4			)	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输入数据x、y坐标位宽=DW+DW_DOT 须<=32）
		)
	cordic_post_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 一次Cordic总旋转（伪旋转）后处理前的信号
		.din_vsync			(din_vsync		),	// 输入数据场有效信号
		.din_hsync			(din_hsync		),	// 输入数据行有效信号
		.din_x				(din_x			),	// 输入数据的x坐标（与 输入数据行有效信号 同步）
		.din_z				(din_z			),	// 输入数据的z坐标（与 输入数据行有效信号 同步）
		// 输入总旋转前的源向量信息（与 输出数据行有效信号 同步）：
		// 第2位表示源向量x坐标符号（0表示正数，1表示负数），
		// 第1位表示源向量y坐标符号（0表示正数，1表示负数），
		// 第0位表示映射到第一象限后的x、y坐标是否需要经过互换才能继续映射到1/4象限（0表示不需要互换，1表示需要互换）。
		.din_info			(din_info		),	// 输入总旋转前的源向量信息（与 输出数据行有效信号 同步）
		
		// 一次Cordic总旋转（伪旋转）后处理后的信号
		.dout_vsync			(dout_vsync		),	// 输出数据场有效信号
		.dout_hsync			(dout_hsync		),	// 输出数据行有效信号
		.dout_x				(dout_x			),	// 输出数据的x坐标（与 输出数据行有效信号 同步）（源向量的模长）
		.dout_z				(dout_z			)	// 输出数据的z坐标（源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)）
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
		din_z		= 1'b0;
		din_info	= 1'b0;
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
		din_x		= 'hBA9;
		din_z		= 'h5C49;
		din_info	= 3'b011;
		// 源向量为：(16, -112)
		// 输出应该为：dout_x ≈ 113.1371，dout_z*(2π)/(2^20) ≈ 4.8543 ≈ 278.13°
		// 实际输出为：dout_x = 112（可以接受），dout_z = 810057 -> dout_z*(2π)/(2^20) ≈ 4.8540 ≈ 278.11°（可以接受）
		
		#T_CLK;
		din_hsync	= 1'b0;
		din_x		= 1'b0;
		din_z		= 1'b0;
		
		#(T_CLK*4);
		din_vsync	= 1'b0;
		
		#(T_CLK*15) $stop;
	end
	// ------
	
	
endmodule
