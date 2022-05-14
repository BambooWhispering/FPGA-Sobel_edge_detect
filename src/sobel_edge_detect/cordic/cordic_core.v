/*
Cordic一次总旋转（伪旋转，未进行模长补偿）：
将一次总旋转拆分为n次微伪旋转，一次总旋转 从[0°, 45°)开始旋转，最终旋转到0°。
则，一次总旋转后的 x坐标即为 未进行模长补偿的源向量的长度，y坐标即为 0，z坐标即为 源向量与0°轴的夹角的归一化值。
*/
module cordic_core(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 一次Cordic总旋转前的信号
	// （因为是从0°~45°位置开始旋转的，也就是第一象限的1/4象限，故开始旋转前，x、y均>=0，而z取方向为从0到目标角 即 z=0，故x、y、z均不需要有符号位）
	din_vsync			,	// 输入数据场有效信号
	din_hsync			,	// 输入数据行有效信号
	din_x				,	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	din_y				,	// 输入数据的y坐标（与 输入数据行有效信号 同步）
	din_z				,	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	
	// 一次Cordic总旋转后的信号
	// （因为最终旋转到0°，故总旋转后，x>0，y坐标一定趋近于0 即 不需要输出y坐标，
	// 而起始总旋转位置为第一象限的1/4象限，故总旋转后，z趋近于起始旋转角度 即 z>=0，故x、z均不需要符号位）
	dout_vsync			,	// 输出数据场有效信号
	dout_hsync			,	// 输出数据行有效信号
	dout_x				,	// 输出数据的x坐标（与 输出数据行有效信号 同步）
	dout_z					// 输出数据的z坐标（与 输出数据行有效信号 同步）
	);
	
	
	// *******************************************参数声明***************************************
	// 视频数据流参数
	// 设x、y绝对值最大值为max_x_y，则最终迭代结果最大值不超过2*max_x_y，故需要保留一位用于迭代过程。
	// 即 输入数据x、y坐标的 最高位为符号位，次高位保留为0，
	// 即 输入数据x、y坐标的绝对值 保存在 低DW-2位
	parameter	DW			=	'd16		;	// 输入数据x、y坐标位宽
	
	// Cordic参数
	parameter	T_IR_NUM	=	'd15		;	// 总迭代次数（total iteration number）（可选 15~18）
	parameter	DW_DOT		=	'd4			;	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输出数据x、y坐标位宽=DW+DW_DOT 须<=32）
	parameter	DW_NOR		=	'd20		;	// 输入数据z坐标归一化位宽（不要更改）
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input							clk					;	// 时钟（clock）
	input							rst_n				;	// 复位（reset）
	
	// 一次Cordic总旋转前的信号
	// （因为是从0°~45°位置开始旋转的，也就是第一象限的1/4象限，故开始旋转前，x、y均>=0，而z取方向为从0到目标角 即 z=0，故x、y、z均不需要有符号位）
	input							din_vsync			;	// 输入数据场有效信号
	input							din_hsync			;	// 输入数据行有效信号
	input		[DW-1:0]			din_x				;	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	input		[DW-1:0]			din_y				;	// 输入数据的y坐标（与 输入数据行有效信号 同步）
	input		[DW_NOR-1:0]		din_z				;	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	
	// 一次Cordic总旋转后的信号
	// （因为最终旋转到0°，故总旋转后，x>0，y坐标一定趋近于0 即 不需要输出y坐标，
	// 而起始总旋转位置为第一象限的1/4象限，故总旋转后，z趋近于起始旋转角度 即 z>=0，故x、z均不需要符号位）
	output							dout_vsync			;	// 输出数据场有效信号
	output							dout_hsync			;	// 输出数据行有效信号
	output		[DW+DW_DOT-1:0]		dout_x				;	// 输出数据的x坐标（与 输出数据行有效信号 同步）（扩展了小数位，相当于左移了DW_DOT位）
	output		[DW_NOR-1:0]		dout_z				;	// 输出数据的z坐标（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// T_IR_NUM+1次微伪旋转的输入数据
	wire	signed	[DW+DW_DOT-1:0]	din_x_dot[0:T_IR_NUM]	;	// 扩展出小数位的第i次微伪旋转的输入x坐标
	wire	signed	[DW+DW_DOT-1:0]	din_y_dot[0:T_IR_NUM]	;	// 扩展出小数位的第i次微伪旋转的输入y坐标
	wire	signed	[DW_NOR-1:0]	din_z_temp[0:T_IR_NUM]	;	// 第i次微伪旋转的输入z坐标
	wire			[T_IR_NUM:0]	din_vsync_temp			;	// 第i次微伪旋转的输入场同步信号
	wire			[T_IR_NUM:0]	din_hsync_temp			;	// 第i次微伪旋转的输入行同步信号
	// *******************************************************************************************
	
	
	// ---第0次微伪旋转的输入信号---
	assign	din_x_dot[0]		=	{din_x, {DW_DOT{1'b0}}}	;	// 扩展出小数位的第0次微伪旋转的输入x坐标
	assign	din_y_dot[0]		=	{din_y, {DW_DOT{1'b0}}}	;	// 扩展出小数位的第0次微伪旋转的输入y坐标
	
	assign	din_z_temp[0]		=	din_z					;	// 第0次微伪旋转的输入z坐标
	
	assign	din_vsync_temp[0]	=	din_vsync				;	// 第0次微伪旋转的输入场同步信号
	assign	din_hsync_temp[0]	=	din_hsync				;	// 第0次微伪旋转的输入行同步信号
	// ------
	
	
	// ---实例化 T_IR_NUM个Cordic单次迭代处理单元---
	// 采用菊花链结构，即把当前次迭代的输出作为下一次迭代的输入（故数组长度为 T_IR_NUM+1）
	generate
	begin: gen_iteration
		genvar	n;
		for(n=0; n<T_IR_NUM; n=n+1) // 完成第0~T_IR_NUM-1次Cordic迭代
		begin: gen_cordic_unit
			cordic_ir_uint #(
				// 视频数据流参数
				// 设x、y绝对值最大值为max_x_y，则迭代结果最大值不超过2*max_x_y，故需要保留一位用于迭代过程。
				// 即 输入数据x、y坐标的 最高位为符号位，次高位保留为0，
				// 即 输入数据x、y坐标的绝对值 保存在 低DW-2位
				.DW					(DW+DW_DOT			),	// 输入数据x、y坐标位宽
				
				// Cordic参数
				.P_IR_ID			(n					),	// 当前迭代次数编号（present iteration identity）
				.T_IR_NUM			(T_IR_NUM			)	// 总迭代次数（total iteration number）（可选 15~18）
				)
			cordic_ir_uint_u0(
				// 系统信号
				.clk				(clk				),	// 时钟（clock）
				.rst_n				(rst_n				),	// 复位（reset）
				
				// 单次Cordic迭代前的信号
				.din_vsync			(din_vsync_temp[n]	),	// 输入数据场有效信号
				.din_hsync			(din_hsync_temp[n]	),	// 输入数据行有效信号
				.din_x				(din_x_dot[n]		),	// 输入数据的x坐标（与 输入数据行有效信号 同步）
				.din_y				(din_y_dot[n]		),	// 输入数据的y坐标（与 输入数据行有效信号 同步）
				.din_z				(din_z_temp[n]		),	// 输入数据的z坐标（与 输入数据行有效信号 同步）
				
				// 单次Cordic迭代后的信号
				.dout_vsync			(din_vsync_temp[n+1]),	// 输出数据场有效信号
				.dout_hsync			(din_hsync_temp[n+1]),	// 输出数据行有效信号
				.dout_x				(din_x_dot[n+1]		),	// 输出数据的x坐标（与 输出数据行有效信号 同步）
				.dout_y				(din_y_dot[n+1]		),	// 输出数据的y坐标（与 输出数据行有效信号 同步）
				.dout_z				(din_z_temp[n+1]	)	// 输出数据的z坐标（与 输出数据行有效信号 同步）
				);
		end
	end
	endgenerate
	// ------
	
	
	// ---一次Cordic总旋转后的信号（即最后一次迭代的结果）---
	assign	dout_x	=	din_x_dot[T_IR_NUM];
	assign	dout_z	=	din_z_temp[T_IR_NUM];
	assign	dout_vsync	=	din_vsync_temp[T_IR_NUM];
	assign	dout_hsync	=	din_hsync_temp[T_IR_NUM];
	// ------
	
	
endmodule
