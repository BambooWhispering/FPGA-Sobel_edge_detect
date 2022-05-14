/*
Sobel边缘检测顶层模块
*/
module sobel_top(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 输入信号（源视频信号）
	sb_din_vsync		,	// 输入数据场有效信号
	sb_din_hsync		,	// 输入数据行有效信号
	sb_din				,	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号（Sobel边缘检测后的信号）
	sb_dout_vsync		,	// 输出数据场有效信号
	sb_dout_hsync		,	// 输出数据行有效信号
	sb_dout				, 	// 输出梯度数据（与 输出数据行有效信号 同步）
	sb_dout_angle		,	// 输出梯度与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
	
	// Sobel选择参数
	is_binary				// 是否要对边缘检测结果进行二值化（二值化 即 输出只能为0或全1）
	);
	
	
	// *******************************************参数声明***************************************
	// 核参数
	parameter	KSZ				=	'd3							;	// 核尺寸（正方形核的边长）（kernel size）（本例只实现了核尺寸为3的，所以不要更改）
	
	// 视频数据流参数
	parameter	DW				=	'd8							;	// 输入数据位宽
	parameter	IW				=	'd640						;	// 输入图像宽（image width）
	parameter	IH				=	'd480						;	// 输入图像高（image height）
	
	// 行参数
	parameter	H_TOTAL			=	'd1440						;	// 行总时间
	parameter	H_DISP			=	IW							;	// 行显示时间
	parameter	H_SYNC			=	H_TOTAL-H_DISP				;	// 行同步时间
	// 场参数（多少个时钟周期，注意这里不是多少行！！！）
	parameter	V_FRONT_CLK		=	'd28800						;	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
	
	// 单时钟FIFO（用于行缓存）参数
	parameter	FIFO_DEPTH		=	'd1024						;	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
	parameter	FIFO_DEPTH_DW	=	'd10						;	// SCFIFO 深度位宽
	parameter	DEVICE_FAMILY	=	"Stratix III"				;	// SCFIFO 支持的设备系列
	
	// 参数选择
	parameter	IS_BOUND_ADD	=	1'b1						;	// 是否要进行边界补充（1——补充边界；0——忽略边界）
	
	// Cordic视频数据流参数
	// 设x、y绝对值最大值为max_x_y，则最终迭代结果最大值不超过2*max_x_y，故需要保留一位用于迭代过程。
	// 即 输入数据x、y坐标的 最高位为符号位，次高位保留为0，
	// 即 输入数据x、y坐标的绝对值 保存在 低DW-2位
	parameter	DW_x_y		=	DW<<1		;	// 输入数据x、y坐标位宽
	
	// Cordic参数
	parameter	T_IR_NUM	=	'd15		;	// 总迭代次数（total iteration number）（可选 15~18）
	parameter	DW_DOT		=	'd4			;	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输入数据x、y坐标位宽=DW+DW_DOT 须<=32）
	parameter	DW_NOR		=	'd20		;	// 输入数据z坐标归一化位宽（不要更改）
	
	// Sobel结果二值化阈值参数
	parameter	BIANRY_THRESHOLD	=	'd128	;	// 二值化时的阈值（大于等于该阈值的输出全1，小于该阈值的输出0）（一般取输入值的一半）
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input							clk					;	// 时钟（clock）
	input							rst_n				;	// 复位（reset）
	
	// 输入信号（源视频信号）
	input							sb_din_vsync		;	// 输入数据场有效信号
	input							sb_din_hsync		;	// 输入数据行有效信号
	input		[DW-1:0]			sb_din				;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号（Sobel边缘检测后的信号）
	output							sb_dout_vsync		;	// 输出数据场有效信号
	output							sb_dout_hsync		;	// 输出数据行有效信号
	output	reg	[DW-1:0]			sb_dout				; 	// 输出梯度数据（与 输出数据行有效信号 同步）
	output		[DW_NOR-1:0]		sb_dout_angle		;	// 输出梯度与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
	
	// Sobel选择参数
	input							is_binary			;	// 是否要对边缘检测结果进行二值化（二值化 即 输出只能为0或全1）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// Sobel x、y核滤波前 的信号
	wire							sb_x_y_din_vsync	;	// Sobel x、y核滤波模块 输入数据场有效标志
	wire							sb_x_y_din_hsync	;	// Sobel x、y核滤波模块 输入数据行有效标志
	wire			[DW-1:0]		sb_x_y_din			; 	// Sobel x、y核滤波模块 输入数据（与 输出数据有效标志 同步）
	
	// Sobel x、y核滤波后 的信号
	wire							sb_x_y_dout_vsync	;	// Sobel x、y核滤波模块 输出数据场有效信号
	wire							sb_x_y_dout_hsync	;	// Sobel x、y核滤波模块 输出数据行有效信号
	wire	signed	[DW_x_y-1:0]	sb_x_y_dout_grad_x	; 	// Sobel x、y核滤波模块 输出x方向的梯度数据（与输出数据行有效信号同步）
	wire	signed	[DW_x_y-1:0]	sb_x_y_dout_grad_y	; 	// Sobel x、y核滤波模块 输出y方向的梯度数据（与输出数据行有效信号同步）
	
	// Cordic总旋转后的信号（目的向量0°，故不需要符号位）
	wire							cordic_dout_vsync	;	// Cordic总旋转 输出数据场有效信号
	wire							cordic_dout_hsync	;	// Cordic总旋转 输出数据行有效信号
	wire			[DW_x_y-1:0]	cordic_dout_radians	;	// Cordic总旋转 输出源向量的模长（与 输出数据行有效信号 同步）
	wire			[DW_NOR-1:0]	cordic_dout_angle	;	// Cordic总旋转 输出源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
	// *******************************************************************************************
	
	
	// 根据参数决定是否需要补充边界
	generate
	begin
		
		if(IS_BOUND_ADD) // 补充边界
		begin: bound_add
			
			// 实例化 上下左右边界补充模块
			// 通过复制边界的像素点，
			// 在图像的上下边界各添加 (正方形核边长-1)/2 行像素点，
			// 在图像的左右边界各添加 (正方形核边长-1)/2 个像素点
			bound_add_top #(
				// 核参数
				.KSZ				(KSZ				),	// 核尺寸（正方形核的边长）（kernel size）（可选择3,5,7）
				
				// 视频数据流参数
				.DW					(DW					),	// 输入数据位宽
				.IW					(IW					),	// 输入图像宽（image width）
				.IH					(IH					),	// 输入图像高（image height）
				
				// 行参数（多少个时钟周期）
				.H_TOTAL			(H_TOTAL			),	// 行总时间
				// 场参数（多少个时钟周期，注意这里不是多少行！！！）
				.V_FRONT_CLK		(V_FRONT_CLK		),	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
				
				// 单时钟FIFO（用于行缓存）参数
				.FIFO_DEPTH			(FIFO_DEPTH			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW		),	// SCFIFO 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY		)	// SCFIFO 支持的设备系列
				)
			bound_add_top_u0(
				// 系统信号
				.clk				(clk				),	// 时钟（clock）
				.rst_n				(rst_n				),	// 复位（reset）
				
				// 输入信号
				.din_vsync			(sb_din_vsync		),	// 输入数据场有效信号
				.din_hsync			(sb_din_hsync		),	// 输入数据行有效信号
				.din				(sb_din				),	// 输入数据（与 输入数据行有效信号 同步）
				
				// 输出信号
				.dout_vsync			(sb_x_y_din_vsync	),	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
				.dout_hsync			(sb_x_y_din_hsync	),	// 输出数据行有效信号（左对齐，即在行有效期右边扩充列）
				.dout				(sb_x_y_din			) 	// 输出数据（与 输出数据行有效信号 同步）
				);
			
			// 实例化 Sobel x、y核滤波模块
			// 计算x、y方向的梯度
			sobel_x_y_kernel #(
				// 视频数据流参数
				.DW					(DW					),	// 输入数据位宽（输出数据位宽为DW*2）
				.IW					(IW+KSZ-1'b1		),	// 输入图像宽（image width）（多了KSZ-1行）
				
				// 行参数（多少个时钟周期）
				.H_TOTAL			(H_TOTAL			),	// 行总时间
				
				// 单时钟FIFO（用于行缓存）参数
				.FIFO_DEPTH			(FIFO_DEPTH			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW		),	// SCFIFO 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY		)	// SCFIFO 支持的设备系列
				)
			sobel_x_y_kernel_u0(
				// 系统信号
				.clk				(clk				),	// 时钟（clock）
				.rst_n				(rst_n				),	// 复位（reset）
				
				// 输入信号（源视频信号）
				.din_vsync			(sb_x_y_din_vsync	),	// 输入数据场有效信号
				.din_hsync			(sb_x_y_din_hsync	),	// 输入数据行有效信号
				.din				(sb_x_y_din			),	// 输入数据（与 输入数据行有效信号 同步）
				
				// 输出信号（Sobel核滤波后的信号）
				.dout_vsync			(sb_x_y_dout_vsync	),	// 输出数据场有效信号
				.dout_hsync			(sb_x_y_dout_hsync	),	// 输出数据行有效信号
				.dout_grad_x		(sb_x_y_dout_grad_x	), 	// 输出x方向的梯度数据（与 输出数据行有效信号 同步）
				.dout_grad_y		(sb_x_y_dout_grad_y	) 	// 输出y方向的梯度数据（与 输出数据行有效信号 同步）
				);
					
		end
		else // 忽略边界
		begin: bound_ignore
			
			// 不实例化边界补充模块，输入直接连接到Sobel x、y核滤波模块
			assign		sb_x_y_din_vsync	=	sb_din_vsync	;
			assign		sb_x_y_din_hsync	=	sb_din_hsync	;
			assign		sb_x_y_din			=	sb_din			;
			
			// 实例化 Sobel x、y核滤波模块
			// 计算x、y方向的梯度
			sobel_x_y_kernel #(
				// 视频数据流参数
				.DW					(DW					),	// 输入数据位宽（输出数据位宽为DW*2）
				.IW					(IW					),	// 输入图像宽（image width）
				
				// 行参数（多少个时钟周期）
				.H_TOTAL			(H_TOTAL			),	// 行总时间
				
				// 单时钟FIFO（用于行缓存）参数
				.FIFO_DEPTH			(FIFO_DEPTH			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW		),	// SCFIFO 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY		)	// SCFIFO 支持的设备系列
				)
			sobel_x_y_kernel_u0(
				// 系统信号
				.clk				(clk				),	// 时钟（clock）
				.rst_n				(rst_n				),	// 复位（reset）
				
				// 输入信号（源视频信号）
				.din_vsync			(sb_x_y_din_vsync	),	// 输入数据场有效信号
				.din_hsync			(sb_x_y_din_hsync	),	// 输入数据行有效信号
				.din				(sb_x_y_din			),	// 输入数据（与 输入数据行有效信号 同步）
				
				// 输出信号（Sobel核滤波后的信号）
				.dout_vsync			(sb_x_y_dout_vsync	),	// 输出数据场有效信号
				.dout_hsync			(sb_x_y_dout_hsync	),	// 输出数据行有效信号
				.dout_grad_x		(sb_x_y_dout_grad_x	), 	// 输出x方向的梯度数据（与 输出数据行有效信号 同步）
				.dout_grad_y		(sb_x_y_dout_grad_y	) 	// 输出y方向的梯度数据（与 输出数据行有效信号 同步）
				);
			
		end
	end
	endgenerate
	
	
	// 实例化 Cordic顶层模块
	// 计算x、y方向梯度的向量的模长（总梯度）、方向（与0°轴的夹角）
	cordic_top #(
		// 视频数据流参数
		.DW					(DW_x_y				),	// 输出数据x、y坐标位宽
		
		// Cordic参数
		.T_IR_NUM			(T_IR_NUM			),	// 总迭代次数（total iteration number）（可选 15~18）
		.DW_DOT				(DW_DOT				)	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输入数据x、y坐标位宽=DW+DW_DOT 须<=32）
		)
	cordic_top_u0(
		// 系统信号
		.clk				(clk				),	// 时钟（clock）
		.rst_n				(rst_n				),	// 复位（reset）
		
		// 一次Cordic总旋转前的信号（源向量[0°,360°) ，故需要符号位）
		.din_vsync			(sb_x_y_dout_vsync	),	// 输入数据场有效信号
		.din_hsync			(sb_x_y_dout_hsync	),	// 输入数据行有效信号
		.din_x				(sb_x_y_dout_grad_x	),	// 输入数据的x坐标（与 输入数据行有效信号 同步）
		.din_y				(sb_x_y_dout_grad_y	),	// 输入数据的y坐标（与 输入数据行有效信号 同步）
		
		// 一次Cordic总旋转后的信号（目的向量0°，故不需要符号位）
		.dout_vsync			(cordic_dout_vsync	),	// 输出数据场有效信号
		.dout_hsync			(cordic_dout_hsync	),	// 输出数据行有效信号
		.dout_radians		(cordic_dout_radians),	// 输出源向量的模长（与 输出数据行有效信号 同步）
		.dout_angle			(cordic_dout_angle	)	// 输出源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
		);
	
	
	// ---Sobel边缘检测顶层模块 输出信号---
	assign	sb_dout_vsync	=	cordic_dout_vsync	;
	assign	sb_dout_hsync	=	cordic_dout_hsync	;
	assign	sb_dout_angle	=	cordic_dout_angle	;
	always @(*)
	begin
		if(is_binary) // 如果要进行二值化，则大于等于二值化阈值的输出全1，小于二值化阈值的输出0
			sb_dout = (cordic_dout_radians>=BIANRY_THRESHOLD) ? {DW{1'b1}} : {DW{1'b0}};
		else // 如果不进行二值化，则超范围时才阈值化为范围内的最大值
			sb_dout = (cordic_dout_radians>{DW{1'b1}}) ? {DW{1'b1}} : cordic_dout_radians;
	end
	// ------
	
	
endmodule
