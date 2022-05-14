/*
Cordic单次迭代（微伪旋转）处理单元：
将一次总旋转拆分为n次微伪旋转，一次总旋转 从[0°, 45°)开始旋转，最终旋转到0°。
已知 一次微伪旋转前的x、y、z坐标，求一次微伪旋转后的x、y、z坐标。

可套用Cordic公式：
第i次微伪旋转后，
x_(i+1) = x_(i) - d_(i)*y_(i)*(2^-i)
y_(i+1) = y_(i) + d_(i)*x_(i)*(2^-i)
z_(i+1) = z_(i) - d_(i)*arctan(2^(-i)) 归一化为 z_(i+1) = z_(i) - d_(i)*arctan(2^(-i))/(2π)*(2^20)
其中，d_(i) = -1 (表示当次微伪旋转方向为顺时针方向), +1 (表示当次微伪旋转方向为顺时针方向)
因为旋转的目的是，使y趋近于0，所以可以使用y的符号位来判断旋转方向，
即 d_(i) = -1 (y_(i)为正数时), +1 (y_(i)为负数时)
*/
module cordic_ir_uint(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 单次Cordic迭代前的信号
	din_vsync			,	// 输入数据场有效信号
	din_hsync			,	// 输入数据行有效信号
	din_x				,	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	din_y				,	// 输入数据的y坐标（与 输入数据行有效信号 同步）
	din_z				,	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	
	// 单次Cordic迭代后的信号
	dout_vsync			,	// 输出数据场有效信号
	dout_hsync			,	// 输出数据行有效信号
	dout_x				,	// 输出数据的x坐标（与 输出数据行有效信号 同步）
	dout_y				,	// 输出数据的y坐标（与 输出数据行有效信号 同步）
	dout_z					// 输出数据的z坐标（与 输出数据行有效信号 同步）
	);
	
	
	// *******************************************参数声明***************************************
	// 视频数据流参数
	// 设x、y绝对值最大值为max_x_y，则迭代结果最大值不超过2*max_x_y，故需要保留一位用于迭代过程。
	// 即 输入数据x、y坐标的 最高位为符号位，次高位保留为0，
	// 即 输入数据x、y坐标的绝对值 保存在 低DW-2位
	parameter	DW			=	'd16		;	// 输入数据x、y坐标位宽
	
	// Cordic参数
	parameter	P_IR_ID		=	'd0			;	// 当前迭代次数编号（present iteration identity）
	parameter	T_IR_NUM	=	'd15		;	// 总迭代次数（total iteration number）（可选 15~18）
	parameter	DW_NOR		=	'd20		;	// 输入数据z坐标归一化位宽（不要更改）
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input							clk					;	// 时钟（clock）
	input							rst_n				;	// 复位（reset）
	
	// 单次Cordic迭代前的信号
	input							din_vsync			;	// 输入数据场有效信号
	input							din_hsync			;	// 输入数据行有效信号
	input		signed	[DW-1:0]	din_x				;	// 输入数据的x坐标（与 输入数据行有效信号 同步）
	input		signed	[DW-1:0]	din_y				;	// 输入数据的y坐标（与 输入数据行有效信号 同步）
	input		signed	[DW_NOR-1:0]din_z				;	// 输入数据的z坐标（与 输入数据行有效信号 同步）
	
	// 单次Cordic迭代后的信号
	output							dout_vsync			;	// 输出数据场有效信号
	output							dout_hsync			;	// 输出数据行有效信号
	output	reg	signed	[DW-1:0]	dout_x				;	// 输出数据的x坐标（与 输出数据行有效信号 同步）
	output	reg	signed	[DW-1:0]	dout_y				;	// 输出数据的y坐标（与 输出数据行有效信号 同步）
	output	reg	signed	[DW_NOR-1:0]dout_z				;	// 输出数据的z坐标（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// arctan的查找表（look up table of arctan）
	wire	[DW_NOR-1:0]		arctan_lut[0:17]	;	// arctan的查找表（总迭代次数 个 数据）
	
	// 旋转方向因子（逆时针为1，顺时针为0）
	wire						dir					;	// 旋转方向因子（逆时针为1，顺时针为0）
	
	// 当前次迭代（微伪旋转）后的各坐标变化量
	wire	signed	[DW-1:0]	delta_x				;	// 当前次迭代（微伪旋转）后的x坐标变化量（△x）
	wire	signed	[DW-1:0]	delta_y				;	// 当前次迭代（微伪旋转）后的y坐标变化量（△y）
	wire	signed	[DW_NOR-1:0]delta_z				;	// 当前次迭代（微伪旋转）后的z坐标变化量（△z）
	
	// 当前次迭代（微伪旋转）后的各坐标变化量 未处理完全的临时量
	wire	signed	[DW-1:0]	delta_x_temp		;	// 当前次迭代（微伪旋转）后的x坐标变化量 未处理完全的临时量
	wire	signed	[DW-1:0]	delta_y_temp		;	// 当前次迭代（微伪旋转）后的y坐标变化量 未处理完全的临时量
	
	// 单次Cordic迭代后的信号 未处理完全的临时量
	wire	signed	[DW-1:0]	dout_temp_x			;	// 输出数据的x坐标 未处理完全的临时量
	wire	signed	[DW-1:0]	dout_temp_y			;	// 输出数据的y坐标 未处理完全的临时量
	wire	signed	[DW_NOR-1:0]dout_temp_z			;	// 输出数据的z坐标 未处理完全的临时量
	
	// 单次Cordic迭代前的 行、场同步信号 打拍
	reg							din_vsync_r			;	// 输入数据场有效信号 打1拍
	reg							din_hsync_r			;	// 输入数据行有效信号 打1拍
	// *******************************************************************************************
	
	
	// ---arctan的查找表---
	// 因为 z_(i+1) = z_(i) - d_(i)*arctan(2^(-i)) ，
	// 所以可以事先求出 i=0~T_IR_NUM-1 的 arctan(2^(-i)) 的查找表。
	// 但是由于这个查找表的值为小数，所以，对其进行归一化（整体放大），即查找表中存放的是 arctan(2^(-i)) /(2π) *(2^20) 。
	// 故，重新令 z_(i+1) = z_(i) - d_(i)*arctan(2^(-i))/(2π)*(2^20) 。
	// 比如：arctan(2^(-0)) = 45° = π/4，则 最终存放进查找表中的值 = (π/4) /(2π) *(2^20) = 131072 = 0x2_0000
	assign	arctan_lut[ 0]	=	20'h2_0000	;	// i=0时的 arctan(2^(-i)) /(2π) *(2^20)
	assign	arctan_lut[ 1]	=	20'h1_2E40	;
	assign	arctan_lut[ 2]	=	20'h0_9FB4	;
	assign	arctan_lut[ 3]	=	20'h0_5111	;
	assign	arctan_lut[ 4]	=	20'h0_28B1	;
	assign	arctan_lut[ 5]	=	20'h0_145D	;
	assign	arctan_lut[ 6]	=	20'h0_0A2F	;
	assign	arctan_lut[ 7]	=	20'h0_0518	;
	assign	arctan_lut[ 8]	=	20'h0_028C	;
	assign	arctan_lut[ 9]	=	20'h0_0146	;
	assign	arctan_lut[10]	=	20'h0_00A3	;	// i=10时的 arctan(2^(-i)) /(2π) *(2^20)
	assign	arctan_lut[11]	=	20'h0_0051	;
	assign	arctan_lut[12]	=	20'h0_0029	;
	assign	arctan_lut[13]	=	20'h0_0014	;
	assign	arctan_lut[14]	=	20'h0_000A	;
	assign	arctan_lut[15]	=	20'h0_0005	;
	assign	arctan_lut[16]	=	20'h0_0003	;
	assign	arctan_lut[17]	=	20'h0_0001	;
	// 对于位宽为20位的来说，从第18个数据开始，已经为0，即再算下去就没有意义了
	// ------
	
	
	// 旋转方向因子（逆时针为1，顺时针为0）
	// 因为旋转的目的是，使y趋近于0，所以可以使用y的符号位来判断旋转方向。
	// 例如：旋转前的y为正数（有符号数y的最高位为0）时，说明当前次旋转方向应该为顺时针，即d=-1，即dir=0；
	//       旋转前的y为负数（有符号数y的最高位为1）时，说明当前次旋转方向应该为逆时针，即d=+1，即dir=1。
	assign	dir	=	din_y[DW-1];
	
	
	// ---当前次迭代（微伪旋转）后的z坐标变化量（△z）---
	// 第i次旋转后，
	// d_(i) = -1 (y_(i)为正数时), +1 (y_(i)为负数时)
	// z_(i+1) = z_(i) - d_(i)*arctan(2^(-i))/(2π)*(2^20)
	// 故，令 △z = delta_z = arctan(2^(-i))/(2π)*(2^20)
	// 则，dout_z = din_z - d_(i)*delta_z
	assign	delta_z	=	arctan_lut[P_IR_ID]	;
	// ------
	
	
	// ---当前次迭代（微伪旋转）后的x、y坐标变化量（△x、△y）---
	generate
		
		if(P_IR_ID == 'd0) // 当前迭代次数为0时
		begin: shift_none // 由于2^0=1，所以不需要移位
			// d_(0) = -1 (y为正数时), +1 (y为负数时)
			// 第0次旋转后，
			// x_(1) = x_(0) - d_(0)*y_(0)*(2^-0) = x_(0) - d_(0)*y_(0)
			// y_(1) = y_(0) + d_(0)*x_(0)*(2^-0) = y_(0) + d_(0)*x_(0)
			// 故，令 △x = delta_x = y_(0) = din_y
			//        △y = delta_y = x_(0) = din_x
			// 则，dout_x = din_x - d_(0)*delta_x
			//     dout_y = din_y + d_(0)*delta_y
			assign	delta_x	=	din_hsync ? din_y : 1'b0;
			assign	delta_y	=	din_hsync ? din_x : 1'b0;
		end
		
		else // 当前迭代次数不为0时
		begin: shift_right // 由于i>0且i为整数，所以2^(-i)相当于右移i位
			// d_(i) = -1 (y_(i)为正数时), +1 (y_(i)为负数时)
			// 第i次旋转后，
			// x_(i+1) = x_(i) - d_(i)*y_(i)*(2^-i)
			// y_(i+1) = y_(i) + d_(i)*x_(i)*(2^-i)
			// 故，令 △x = delta_x = y_(i)*(2^-i) = din_y >> i
			//        △y = delta_y = x_(i)*(2^-i) = din_x >> i
			// 则，dout_x = din_x - d_(i)*delta_x
			//     dout_y = din_y + d_(i)*delta_y
			
			// 带符号位右移i位前
			assign	delta_x_temp	=	din_hsync ? din_y : 1'b0;
			assign	delta_y_temp	=	din_hsync ? din_x : 1'b0;
			// 带符号位右移i位后
			assign	delta_x	=	delta_x_temp[DW-1] ? 
								{{P_IR_ID{1'b1}}, delta_x_temp[DW-1:P_IR_ID]} : 
								{{P_IR_ID{1'b0}}, delta_x_temp[DW-1:P_IR_ID]}; 
								// 带符号位的负数（最高位为1）右移时，高位全部补1；带符号位的正数（最高位为0）右移时，高位全部补0。
			assign	delta_y	=	delta_y_temp[DW-1] ? 
								{{P_IR_ID{1'b1}}, delta_y_temp[DW-1:P_IR_ID]} : 
								{{P_IR_ID{1'b0}}, delta_y_temp[DW-1:P_IR_ID]}; 
								// 带符号位的负数（最高位为1）右移时，高位全部补1；带符号位的正数（最高位为0）右移时，高位全部补0。
		end
		
	endgenerate
	// ------
	
	
	// ---单次Cordic迭代后的信号 未处理完全的临时量---
	// 因为 dout_x = din_x - d_(i)*delta_x
	//      dout_y = din_y + d_(i)*delta_y
	//      dout_z = din_z - d_(i)*delta_z
	// 而 d_(i) = -1 (y_(i)为正数时) 即 dir=0
	//    d_(i) = +1 (y_(i)为负数时) 即 dir=1
	assign	dout_temp_x	=	~dir ? (din_x+delta_x) : (din_x-delta_x);
	assign	dout_temp_y	=	 dir ? (din_y+delta_y) : (din_y-delta_y);
	assign	dout_temp_z	=	~dir ? (din_z+delta_z) : (din_z-delta_z);
	// ------
	
	
	// ---单次Cordic迭代后的信号---
	// 单次Cordic迭代后的x、y、坐标：只有行有效期间才有效
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			dout_x <= 1'b0;
			dout_y <= 1'b0;
			dout_z <= 1'b0;
		end
		else if(din_hsync)
		begin
			dout_x <= dout_temp_x;
			dout_y <= dout_temp_y;
			dout_z <= dout_temp_z;
		end
		else
		begin
			dout_x <= 1'b0;
			dout_y <= 1'b0;
			dout_z <= 1'b0;
		end
	end
	
	// 单次Cordic迭代前的行、场同步信号 打1拍
	// 因为 单次Cordic迭代后的x、y、坐标 采用了时序逻辑，也就是会比 迭代前的有效信号 滞后1拍，
	// 所以 迭代后的行、场同步信号 也需要比 迭代前的行、场同步信号 滞后1拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			din_hsync_r <= 1'b0;
			din_vsync_r <= 1'b0;
		end
		else
		begin
			din_hsync_r <= din_hsync;
			din_vsync_r <= din_vsync;
		end
	end
	
	// 单次Cordic迭代后的行、场同步信号（迭代前的行、场同步信号 打1拍）
	assign	dout_hsync	=	din_hsync_r;
	assign	dout_vsync	=	din_vsync_r;
	// ------
	
	
endmodule
