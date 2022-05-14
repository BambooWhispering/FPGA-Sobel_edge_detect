/*
上下左右边界补充：
通过复制边界的像素点，在图像的上下边界各添加 (正方形核边长-1)/2 行像素点，在图像的左右边界各添加 (正方形核边长-1)/2 个像素点
*/
module bound_add_top(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 输入信号
	din_vsync			,	// 输入数据场有效信号
	din_hsync			,	// 输入数据行有效信号
	din					,	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号
	dout_vsync			,	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	dout_hsync			,	// 输出数据行有效信号（左对齐，即在行有效期右边扩充列）
	dout				 	// 输出数据（与 输出数据行有效信号 同步）
	);
	
	
	// *******************************************参数声明***************************************
	// 核参数
	parameter	KSZ				=	'd3					;	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
	
	// 视频数据流参数
	parameter	DW				=	'd8					;	// 输入数据位宽
	parameter	IW				=	'd640				;	// 输入图像宽（image width）
	parameter	IH				=	'd480				;	// 输入图像高（image height）
	
	// 行参数（多少个时钟周期）
	parameter	H_TOTAL			=	'd1440				;	// 行总时间
	// 场参数（多少个时钟周期，注意这里不是多少行！！！）
	parameter	V_FRONT_CLK		=	'd28800				;	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
	
	// 单时钟FIFO（用于行缓存）参数
	parameter	FIFO_DEPTH		=	'd1024				;	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
	parameter	FIFO_DEPTH_DW	=	'd10				;	// SCFIFO 深度位宽
	parameter	DEVICE_FAMILY	=	"Stratix III"		;	// SCFIFO 支持的设备系列
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input						clk						;	// 时钟（clock）
	input						rst_n					;	// 复位（reset）
	
	// 输入信号
	input						din_vsync				;	// 输入数据场有效信号
	input						din_hsync				;	// 输入数据行有效信号
	input		[DW-1:0]		din						;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号
	output						dout_vsync				;	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	output						dout_hsync				;	// 输出数据行有效信号（左对齐，即在行有效期右边扩充列）
	output		[DW-1:0]		dout					; 	// 输出数据（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// 上下边界补充模块 输出信号
	wire						ud_dout_vsync			;	// 上下边界补充后的 输出数据场有效信号（比输入场有效信号多了 KSZ-1 行（左对齐））
	wire						ud_dout_hsync			;	// 上下边界补充后的 输出数据行有效信号（比输入行有效信号多了 KSZ-1 行）
	wire		[ 7:0]			ud_dout					; 	// 上下边界补充后的 输出数据（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// 实例化 上下边界补充模块
	// 通过复制边界的像素点，在图像的上下边界各添加 (正方形核边长-1)/2 行像素点
	bound_up_down_add #(
		// 核参数
		.KSZ				(KSZ					),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
		
		// 视频数据流参数
		.DW					(DW						),	// 输入数据位宽
		.IW					(IW						),	// 输入图像宽（image width）
		.IH					(IH						),	// 输入图像高（image height）
		
		// 行参数（多少个时钟周期）
		.H_TOTAL			(H_TOTAL				),	// 行总时间
		// 场参数（多少个时钟周期，注意这里不是多少行！！！）
		.V_FRONT_CLK		(V_FRONT_CLK			),	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
		
		// 单时钟FIFO（用于行缓存）参数
		.FIFO_DEPTH			(FIFO_DEPTH				),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
		.FIFO_DEPTH_DW		(FIFO_DEPTH_DW			),	// SCFIFO 深度位宽
		.DEVICE_FAMILY		(DEVICE_FAMILY			)	// SCFIFO 支持的设备系列
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
		.dout_vsync			(ud_dout_vsync			),	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
		.dout_hsync			(ud_dout_hsync			),	// 输出数据行有效信号
		.dout				(ud_dout				) 	// 输出数据（与 输出数据行有效信号 同步）
		);
	
	
	// 实例化 左右边界补充模块
	// 通过复制边界的像素点，在图像的左右边界各添加 (正方形核边长-1)/2 个像素点
	bound_left_right_add #(
		// 核参数
		.KSZ				(KSZ			),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
		
		// 视频数据流参数
		.DW					(DW				),	// 输入数据位宽
		.IW					(IW				)	// 输入图像宽（image width）
		)
	bound_left_right_add_u0(
		// 系统信号
		.clk				(clk			),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 输入信号
		.din_vsync			(ud_dout_vsync	),	// 输入数据场有效信号
		.din_hsync			(ud_dout_hsync	),	// 输入数据行有效信号
		.din				(ud_dout		),	// 输入数据（与 输入数据行有效信号 同步）
		
		// 输出信号
		.dout_vsync			(dout_vsync		),	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
		.dout_hsync			(dout_hsync		),	// 输出数据行有效信号（左对齐，即在行有效期右边扩充列）
		.dout				(dout			) 	// 输出数据（与 输出数据行有效信号 同步）
		);
	
	
endmodule
