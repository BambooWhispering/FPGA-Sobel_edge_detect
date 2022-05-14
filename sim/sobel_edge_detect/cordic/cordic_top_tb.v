/*
Cordic一次总旋转（非伪旋转） 顶层模块 模块测试
*/
module cordic_top_tb();
	
	
	// ---测试模块信号声明---
	// 系统信号
	reg								clk					;	// 时钟（clock）
	reg								rst_n				;	// 复位（reset）
	
	// 一次Cordic总旋转前的信号（源向量[0°,360°) ，故需要符号位）
	reg								din_vsync			;	// 输入数据场有效信号
	reg								din_hsync			;	// 输入数据行有效信号
	reg		signed	[15:0]			din_x				;	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	reg		signed	[15:0]			din_y				;	// 输入数据的y坐标（与 输入数据行有效信号 同步）
	
	// 一次Cordic总旋转后的信号（目的向量0°，故不需要符号位）
	wire							dout_vsync			;	// 输出数据场有效信号
	wire							dout_hsync			;	// 输出数据行有效信号
	wire			[15:0]			dout_radians		;	// 输出源向量的模长（与 输出数据行有效信号 同步）
	wire			[19:0]			dout_angle			;	// 输出源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
	// ------
	
	
	// ---实例化测试模块---
	cordic_top #(
		// 视频数据流参数
		.DW					('d16			),	// 输出数据x、y坐标位宽
		
		// Cordic参数
		.T_IR_NUM			('d15			),	// 总迭代次数（total iteration number）（可选 15~18）
		.DW_DOT				('d4			)	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输入数据x、y坐标位宽=DW+DW_DOT 须<=32）
		)
	cordic_top_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 一次Cordic总旋转前的信号（源向量[0°,360°) ，故需要符号位）
		.din_vsync			(din_vsync		),	// 输入数据场有效信号
		.din_hsync			(din_hsync		),	// 输入数据行有效信号
		.din_x				(din_x			),	// 输入数据的x坐标（与 输入数据行有效信号 同步）
		.din_y				(din_y			),	// 输入数据的y坐标（与 输入数据行有效信号 同步）
		
		// 一次Cordic总旋转后的信号（目的向量0°，故不需要符号位）
		.dout_vsync			(dout_vsync		),	// 输出数据场有效信号
		.dout_hsync			(dout_hsync		),	// 输出数据行有效信号
		.dout_radians		(dout_radians	),	// 输出源向量的模长（与 输出数据行有效信号 同步）
		.dout_angle			(dout_angle		)	// 输出源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
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
		
		#(T_CLK*30) $stop;
	end
	// ------
	
	
endmodule
