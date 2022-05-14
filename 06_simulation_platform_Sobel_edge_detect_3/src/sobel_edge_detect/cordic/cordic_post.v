/*
Cordic一次总旋转（伪旋转）的后处理：
进行模长补偿 以求出真正的x坐标（即 总旋转前 源向量模长），
进行角度补偿、转换 以求出真正的z坐标（即 总旋转前 源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)）
*/
module cordic_post(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 一次Cordic总旋转（伪旋转）后处理前的信号
	din_vsync			,	// 输入数据场有效信号
	din_hsync			,	// 输入数据行有效信号
	din_x				,	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	din_z				,	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	// 输入总旋转前的源向量信息（与 输出数据行有效信号 同步）：
	// 第2位表示源向量x坐标符号（0表示正数，1表示负数），
	// 第1位表示源向量y坐标符号（0表示正数，1表示负数），
	// 第0位表示映射到第一象限后的x、y坐标是否需要经过互换才能继续映射到1/4象限（0表示不需要互换，1表示需要互换）。
	din_info			,	// 输入总旋转前的源向量信息（与 输出数据行有效信号 同步）
	
	// 一次Cordic总旋转（伪旋转）后处理后的信号
	dout_vsync			,	// 输出数据场有效信号
	dout_hsync			,	// 输出数据行有效信号
	dout_x				,	// 输出数据的x坐标（与 输出数据行有效信号 同步）（源向量的模长）
	dout_z					// 输出数据的z坐标（源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)）
	);
	
	
	// *******************************************参数声明***************************************
	// 视频数据流参数
	parameter	DW			=	'd16		;	// 输出数据x、y坐标位宽
	
	// Cordic参数
	parameter	T_IR_NUM	=	'd15		;	// 总迭代次数（total iteration number）（可选 15~18）
	parameter	DW_DOT		=	'd4			;	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输入数据x、y坐标位宽=DW+DW_DOT 须<=32）
	parameter	DW_NOR		=	'd20		;	// 输入数据z坐标归一化位宽（不要更改）
	
	// 角度归一化补偿参数（固定值，不要修改）
	localparam	PI_HALF		=	21'h04_0000	;	// (π/2)/(2π)*(2^20)
	localparam	PI			=	21'h08_0000	;	// (π)/(2π)*(2^20)
	localparam	PI_DOUBLE	=	21'h10_0000	;	// (2π)/(2π)*(2^20)=0x10_0000，超位宽溢出为0x0_0000
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input							clk					;	// 时钟（clock）
	input							rst_n				;	// 复位（reset）
	
	// 一次Cordic总旋转（伪旋转）后处理前的信号
	input							din_vsync			;	// 输入数据场有效信号
	input							din_hsync			;	// 输入数据行有效信号
	input		[DW+DW_DOT-1:0]		din_x				;	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	input		[DW_NOR-1:0]		din_z				;	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	// 输入总旋转前的源向量信息（与 输出数据行有效信号 同步）：
	// 第2位表示源向量x坐标符号（0表示正数，1表示负数），
	// 第1位表示源向量y坐标符号（0表示正数，1表示负数），
	// 第0位表示映射到第一象限后的x、y坐标是否需要经过互换才能继续映射到1/4象限（0表示不需要互换，1表示需要互换）。
	input		[ 2:0]				din_info			;	// 输入总旋转前的源向量信息（与 输出数据行有效信号 同步）
	
	// 一次Cordic总旋转（伪旋转）后处理后的信号
	output							dout_vsync			;	// 输出数据场有效信号
	output							dout_hsync			;	// 输出数据行有效信号
	output		[DW-1:0]			dout_x				;	// 输出数据的x坐标（与 输出数据行有效信号 同步）（源向量的模长）
	output	reg	[DW_NOR-1:0]		dout_z				;	// 输出数据的z坐标（源向量与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// 模长补偿 第一级流水线结果
	reg			[DW+DW_DOT-1:0]		din_x_r_shift_1		;	// 输入x数据右移1位
	reg			[DW+DW_DOT-1:0]		din_x_r_shift_4		;	// 输入x数据右移4位
	reg			[DW+DW_DOT-1:0]		din_x_r_shift_5		;	// 输入x数据右移5位
	reg			[DW+DW_DOT-1:0]		din_x_r_shift_7		;	// 输入x数据右移7位
	reg			[DW+DW_DOT-1:0]		din_x_r_shift_8		;	// 输入x数据右移8位
	
	// 模长补偿 第二级流水线结果
	reg			[DW+DW_DOT-1:0]		add_rs1_rs4			;	// 输入x数据右移1位 与 输入x数据右移4位 的和
	reg			[DW+DW_DOT-1:0]		add_rs5_rs7			;	// 输入x数据右移5位 与 输入x数据右移7位 的和
	reg			[DW+DW_DOT-1:0]		add_rs8				;	// 输入x数据右移8位 与 0 的和
	
	// 模长补偿 第三级流水线结果
	reg			[DW+DW_DOT-1:0]		add_temp1			;	// 上一级流水线相邻数据相加的和1
	reg			[DW+DW_DOT-1:0]		add_temp2			;	// 上一级流水线相邻数据相加的和2
	
	// 模长补偿 第四级流水线结果
	reg			[DW+DW_DOT-1:0]		add_temp3			;	// 上一级流水线相邻数据相加的和3
	
	// 角度归一化补偿 三级流水线结果
	reg			[DW_NOR:0]			z_temp0				;	// 第一级流水线结果：第一象限的1/4象限 映射回 第一象限
	reg			[DW_NOR:0]			z_temp1				;	// 第二级流水线结果：第一、二象限 映射回 第三、四象限
	reg			[DW_NOR:0]			z_temp2				;	// 第三级流水线结果：第一、四象限 映射回 第二、三象限
	
	// 一次Cordic总旋转（伪旋转）后处理前的 场、行同步信号 打拍
	reg			[ 3:0]				din_vsync_r_arr		;	// 一次Cordic总旋转（伪旋转）后处理前的 场同步信号 打4拍
	reg			[ 3:0]				din_hsync_r_arr		;	// 一次Cordic总旋转（伪旋转）后处理前的 行同步信号 打4拍
	
	// 一次Cordic总旋转（伪旋转）后处理前的 源向量信息 打拍
	reg			[ 2:0]				din_info_r0			;	// 一次Cordic总旋转（伪旋转）后处理前的 源向量信息 打1拍
	reg			[ 2:0]				din_info_r1			;	// 一次Cordic总旋转（伪旋转）后处理前的 源向量信息 打2拍
	// *******************************************************************************************
	
	
	// ---模长补偿---
	// 总的模长补偿因子 = (i=0~n)∏ ( 1 / ((1+2^(-2*i))^0.5) )
	// 当迭代次数在8次及以上时，总模长补偿因子 k ≈ 0.60725
	// 0.60725 = 0000.1001_1011B = 2^-1 + 2^-4 + 2^-5 + 2^-7 + 2^-8
	
	// 第一级流水线（移位）
	always @(posedge clk, negedge rst_n)
	begin
		if(~rst_n)
		begin
			din_x_r_shift_1 <= 1'b0;
			din_x_r_shift_4 <= 1'b0;
			din_x_r_shift_5 <= 1'b0;
			din_x_r_shift_7 <= 1'b0;
			din_x_r_shift_8 <= 1'b0;
		end
		else if(din_hsync)
		begin
			din_x_r_shift_1 <= din_x>>1;
			din_x_r_shift_4 <= din_x>>4;
			din_x_r_shift_5 <= din_x>>5;
			din_x_r_shift_7 <= din_x>>7;
			din_x_r_shift_8 <= din_x>>8;
		end
	end
	
	// 第二级流水线（加法）
	always @(posedge clk, negedge rst_n)
	begin
		if(~rst_n)
		begin
			add_rs1_rs4	 <= 1'b0;
			add_rs5_rs7	 <= 1'b0;
			add_rs8		 <= 1'b0;
		end
		else if(din_hsync_r_arr[0])
		begin
			add_rs1_rs4	 <= din_x_r_shift_1 + din_x_r_shift_4;
			add_rs5_rs7	 <= din_x_r_shift_5 + din_x_r_shift_7;
			add_rs8		 <= din_x_r_shift_8;
		end
	end
	
	// 第三级流水线（加法）
	always @(posedge clk, negedge rst_n)
	begin
		if(~rst_n)
		begin
			add_temp1	 <= 1'b0;
			add_temp2	 <= 1'b0;
		end
		else if(din_hsync_r_arr[1])
		begin
			add_temp1	 <= add_rs1_rs4 + add_rs5_rs7;
			add_temp2	 <= add_rs8;
		end
	end
	
	// 第四级流水线（加法）
	always @(posedge clk, negedge rst_n)
	begin
		if(~rst_n)
			add_temp3	 <= 1'b0;
		else if(din_hsync_r_arr[2])
			add_temp3	 <= add_temp1 + add_temp2;
	end
	
	// 模长补偿后的最终x坐标（总旋转前源向量的模长）输出（比输入滞后了4拍）
	assign	dout_x	=	din_hsync_r_arr[3] ? add_temp3[DW+DW_DOT-1:DW_DOT] : 1'b0;
	// ------
	
	
	// ---角度归一化补偿---
	
	// 第一级流水线
	// 从第一象限的1/4象限 映射回 第一象限：
	// 读取din_info[0]，若其为1，说明映射回第一象限时，x、y坐标需要进行互换。
	// 即 设映射前坐标为(x, y)，则 映射后坐标为(y, x)。
	// 又 arctan(y/x) + arctan(x/y) = π/2 ，
	// 故 第一象限（映射后）的向量与0°轴的夹角的归一化值z_temp0 = arctan(x/y)/(2π)*(2^20) = (π/2)/(2π)*(2^20) - arctan(y/x)/(2π)*(2^20)
	//	= 0x4_0000 - din_z
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			z_temp0 <= 1'b0;
		else if(din_hsync)
			z_temp0 <= din_info[0] ? (PI_HALF-din_z) : din_z;
	end
	
	// 第二级流水线
	// 从第一象限 映射回 第二象限：
	// 读取din_info[2]，若其为1，说明映射回第二、三象限时，x坐标需要进行取相反数。
	// 即 设映射前坐标为(x, y)，则 映射后坐标为(-x, y)。
	// 又 arctan(y/x) + arctan(y/(-x)) = π ，
	// 故 第一、四象限（映射后）的向量与0°轴的夹角的归一化值z_temp1 = arctan(y/(-x))/(2π)*(2^20) = (π)/(2π)*(2^20) - arctan(y/x)/(2π)*(2^20)
	//	= 0x8_0000 - z_temp0
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			z_temp1 <= 1'b0;
		else if(din_hsync_r_arr[0])
			z_temp1 <= din_info_r0[2] ? (PI-z_temp0) : z_temp0;
	end
	
	// 第三级流水线
	// 从第一、二象限 映射回 第三、四象限：
	// 读取din_info[1]，若其为1，说明映射回第三、四象限时，y坐标需要进行取相反数。
	// 即 设映射前坐标为(x, y)，则 映射后坐标为(x, -y)。
	// 又 arctan(y/x) + arctan((-y)/x) = 2π ，
	// 故 第一、二象限（映射后）的向量与0°轴的夹角的归一化值z_temp2 = arctan((-y)/x)/(2π)*(2^20) = (2π)/(2π)*(2^20) - arctan(y/x)/(2π)*(2^20)
	//	= 0x10_0000 - z_temp1
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			z_temp2 <= 1'b0;
		else if(din_hsync_r_arr[1])
			z_temp2 <= din_info_r1[1] ? (PI_DOUBLE-z_temp1) : z_temp1;
	end
	
	// 角度归一化补偿后的最终z坐标（总旋转前源向量与0°轴的夹角的归一化值）输出（比输入滞后了4拍）
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			dout_z <= 1'b0;
		else if(din_hsync_r_arr[2])
			dout_z <= z_temp2;
		else
			dout_z <= 1'b0;
	end
	
	// 一次Cordic总旋转（伪旋转）后处理前的 源向量信息 打拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			din_info_r0 <= 1'b0;
			din_info_r1 <= 1'b0;
		end
		else
		begin
			din_info_r0 <= din_info;
			din_info_r1 <= din_info_r0;
		end
	end
	// ------
	
	
	// ---输出场、行同步信号---
	// 因为 输出x、z坐标 均比输入滞后4拍，
	// 所以为了同步，输出场、行同步信号也需比输入滞后4拍
	
	// 输入场、行同步信号 打4拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			din_vsync_r_arr <= 1'b0;
			din_hsync_r_arr <= 1'b0;
		end
		else
		begin
			din_vsync_r_arr[3:0] <= {din_vsync_r_arr[2:0], din_vsync};
			din_hsync_r_arr[3:0] <= {din_hsync_r_arr[2:0], din_hsync};
		end
	end
	
	// 输出场、行同步信号（比输入滞后了4拍）
	assign	dout_vsync	=	din_vsync_r_arr[3]	;
	assign	dout_hsync	=	din_hsync_r_arr[3]	;
	// ------
	
	
endmodule
