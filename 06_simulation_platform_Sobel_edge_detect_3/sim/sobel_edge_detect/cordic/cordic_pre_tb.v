/*
Cordic一次总旋转的前处理（预处理） 模块测试
*/
module cordic_pre_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg							clk					;	// 时钟（clock）
	reg							rst_n				;	// 复位（reset）
	
	// 一次Cordic总旋转前处理前的信号（源向量[0°,360°) ，故需要符号位）
	reg							din_vsync			;	// 输入数据场有效信号
	reg							din_hsync			;	// 输入数据行有效信号
	reg		signed	[15:0]		din_x				;	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	reg		signed	[15:0]		din_y				;	// 输入数据的y坐标（与 输入数据行有效信号 同步）
	
	// 一次Cordic总旋转前处理后的信号（目的向量[0°, 45°)，故不需要符号位）
	wire						dout_vsync			;	// 输出数据场有效信号
	wire						dout_hsync			;	// 输出数据行有效信号
	wire			[15:0]		dout_x				;	// 输出数据的x坐标（与 输出数据行有效信号 同步）
	wire			[15:0]		dout_y				;	// 输出数据的y坐标（与 输出数据行有效信号 同步）
	// 输出源向量信息（与 输出数据行有效信号 同步）：
	// 第2位表示源向量x坐标符号（0表示正数，1表示负数），
	// 第1位表示源向量y坐标符号（0表示正数，1表示负数），
	// 第0位表示映射到第一象限后的x、y坐标是否需要经过互换才能继续映射到1/4象限（0表示不需要互换，1表示需要互换）。
	wire			[ 2:0]		dout_info			;	// 输出源向量信息（与 输出数据行有效信号 同步）
	// ------
	
	
	// ---实例化测试模块---
	cordic_pre #(
		// 视频数据流参数
		// 设x、y绝对值最大值为max_x_y，则最终迭代结果最大值不超过2*max_x_y，故需要保留一位用于迭代过程。
		// 即 输入数据x、y坐标的 最高位为符号位，次高位保留为0，
		// 即 输入数据x、y坐标的绝对值 保存在 低DW-2位
		.DW					('d16			)	// 输入数据x、y坐标位宽
		)
	cordic_pre_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 一次Cordic总旋转前处理前的信号（源向量[0°,360°) ，故需要符号位）
		.din_vsync			(din_vsync		),	// 输入数据场有效信号
		.din_hsync			(din_hsync		),	// 输入数据行有效信号
		.din_x				(din_x			),	// 输入数据的x坐标（与 输入数据行有效信号 同步）
		.din_y				(din_y			),	// 输入数据的y坐标（与 输入数据行有效信号 同步）
		
		// 一次Cordic总旋转前处理后的信号（目的向量[0°, 45°)，故不需要符号位）
		.dout_vsync			(dout_vsync		),	// 输出数据场有效信号
		.dout_hsync			(dout_hsync		),	// 输出数据行有效信号
		.dout_x				(dout_x			),	// 输出数据的x坐标（与 输出数据行有效信号 同步）
		.dout_y				(dout_y			),	// 输出数据的y坐标（与 输出数据行有效信号 同步）
		// 输出源向量信息（与 输出数据行有效信号 同步）：
		// 第2位表示源向量x坐标符号（0表示正数，1表示负数），
		// 第1位表示源向量y坐标符号（0表示正数，1表示负数），
		// 第0位表示映射到第一象限后的x、y坐标是否需要经过互换才能继续映射到1/4象限（0表示不需要互换，1表示需要互换），
		.dout_info			(dout_info		)	// 输出源向量信息（与 输出数据行有效信号 同步）
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
		din_x		= $signed(112);
		din_y		= $signed(16);
		
		#T_CLK;
		din_x		= $signed(16);
		din_y		= $signed(112);
		
		#T_CLK;
		din_x		= $signed(-16);
		din_y		= $signed(112);
		
		#T_CLK;
		din_x		= $signed(-112);
		din_y		= $signed(16);
		
		#T_CLK;
		din_x		= $signed(-112);
		din_y		= $signed(-16);
		
		#T_CLK;
		din_x		= $signed(-16);
		din_y		= $signed(-112);
		
		#T_CLK;
		din_x		= $signed(16);
		din_y		= $signed(-112);
		
		#T_CLK;
		din_x		= $signed(112);
		din_y		= $signed(-16);
		
		#T_CLK;
		din_hsync	= 1'b0;
		din_x		= $signed(0);
		din_y		= $signed(0);
		
		#(T_CLK*4);
		din_vsync	= 1'b0;
		
		#(T_CLK*15) $stop;
	end
	// ------
	
	
endmodule
