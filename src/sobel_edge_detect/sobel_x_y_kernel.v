/*
用Sobel 3*3的核，求x、y方向的梯度

Sobel x方向滤波核为
Gx = [-1, 0, +1]
	 [-2, 0, +2]
	 [-1, 0, +1]
Sobel y方向滤波核为
Gy = [+1, +2, +1]
	 [ 0,  0,  0]
	 [-1, -2, -1]
*/
module sobel_x_y_kernel(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 输入信号（源视频信号）
	din_vsync			,	// 输入数据场有效信号
	din_hsync			,	// 输入数据行有效信号
	din					,	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号（Sobel核滤波后的信号）
	dout_vsync			,	// 输出数据场有效信号
	dout_hsync			,	// 输出数据行有效信号
	dout_grad_x			, 	// 输出x方向的梯度数据（与 输出数据行有效信号 同步）
	dout_grad_y			 	// 输出y方向的梯度数据（与 输出数据行有效信号 同步）
	);
	
	
	// *******************************************参数声明***************************************
	// 核参数
	parameter	KSZ				=	'd3							;	// 核尺寸（正方形核的边长）（kernel size）（本例只实现了核尺寸为3的，所以不要更改）
	
	// 视频数据流参数
	parameter	DW				=	'd8							;	// 输入数据位宽（输出数据位宽为DW*2）
	parameter	IW				=	'd640						;	// 输入图像宽（image width）
	
	// 行参数（多少个时钟周期）
	parameter	H_TOTAL			=	'd1440						;	// 行总时间
	
	// 要删除（置低）的场同步信号所占时钟周期数
	// 因为至少要等流过 KSZ-1 行数据后，才能得到首次核滤波结果，所以场同步信号应该置低 KSZ-1 行时钟
	parameter	DELETE_CLK		=	(KSZ-1'b1)*H_TOTAL			;	// 要删除（置低）的场同步信号所占时钟周期数
	
	// 单时钟FIFO（用于行缓存）参数
	parameter	FIFO_DW			=	DW							;	// SCFIFO 数据位宽
	parameter	FIFO_DEPTH		=	'd1024						;	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
	parameter	FIFO_DEPTH_DW	=	'd10						;	// SCFIFO 深度位宽
	parameter	DEVICE_FAMILY	=	"Stratix III"				;	// SCFIFO 支持的设备系列
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号
	input							clk					;	// 时钟（clock）
	input							rst_n				;	// 复位（reset）
	
	// 输入信号（源视频信号）
	input							din_vsync			;	// 输入数据场有效信号
	input							din_hsync			;	// 输入数据行有效信号
	input		[DW-1:0]			din					;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号（Sobel核滤波后的信号）
	output							dout_vsync			;	// 输出数据场有效信号
	output							dout_hsync			;	// 输出数据行有效信号
	output	signed	[DW*2-1:0]		dout_grad_x			; 	// 输出x方向的梯度数据（与 输出数据行有效信号 同步）
	output	signed	[DW*2-1:0]		dout_grad_y			; 	// 输出y方向的梯度数据（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// 输入场有效信号 边沿检测
	reg							din_vsync_r0			;	// 输入场有效信号 打1拍
	wire						din_vsync_pos			;	// 输入场有效信号 上升沿
	
	// 输入行有效信号 打拍
	reg							din_hsync_r0			;	// 输入行有效信号 打1拍
	
	// 输入数据信号 打拍
	reg		[DW-1:0]			din_r0					;	// 输入数据信号 打1拍
	
	// 行缓存（SCFIFO） 信号
	wire	[KSZ-2:0]			line_wr_en				;	// FIFO写使能（KSZ-1个）
	wire	[FIFO_DW-1:0]		line_wr_data[0:KSZ-2]	;	// FIFO写数据（与 写使能 同步）（KSZ-1个）
	wire	[KSZ-2:0]			line_rd_en				;	// FIFO读使能（KSZ-1个）
	wire	[FIFO_DW-1:0]		line_rd_data[0:KSZ-2]	;	// FIFO读数据（比 读使能 滞后1拍）（KSZ-1个）
	wire	[FIFO_DEPTH_DW-1:0]	line_usedw[0:KSZ-2]		;	// FIFO中现有的数据个数
	
	// 行缓存（SCFIFO） 信号 打拍
	reg		[KSZ-2:0]			line_rd_en_r0			;	// FIFO读使能（KSZ-1个） 打1拍
	
	// SCFIFO 辅助信号
	reg		[KSZ-2:0]			line_wr_done			;	// 一行图像核行之和写进FIFO完成标志（KSZ-1个）（写完后就一直为1）
	
	// Sobel核中的数据
	wire	[FIFO_DW-1:0]		sobel_c2[0:KSZ-1]		;	// Sobel核中的第2列数据
	reg		[FIFO_DW-1:0]		sobel_c1[0:KSZ-1]		;	// Sobel核中的第1列数据
	reg		[FIFO_DW-1:0]		sobel_c0[0:KSZ-1]		;	// Sobel核中的第0列数据
	
	// Sobel核中的数据正在输出中标志
	wire	[KSZ-1:0]			sobel_c2_valid			;	// Sobel核中的第2列数据 正在输出中标志
	reg		[KSZ-1:0]			sobel_c1_valid			;	// Sobel核中的第1列数据 正在输出中标志
	reg		[KSZ-1:0]			sobel_c0_valid			;	// Sobel核中的第0列数据 正在输出中标志
	
	// Sobel核3*3所有数据都在输出中标志
	wire						sobel_valid				;	// Sobel核3*3所有数据都在输出中标志
	reg							sobel_valid_r0			;	// Sobel核3*3所有数据都在输出中标志 打1拍
	reg							sobel_valid_r1			;	// Sobel核3*3所有数据都在输出中标志 打2拍
	reg							sobel_valid_r2			;	// Sobel核3*3所有数据都在输出中标志 打3拍
	
	// Sobel核求x方向梯度 的流水线信号
	// 第一级流水线 信号
	reg		[DW*2-1:0]			add_c0r0_c0r2			;	// Sobel核中 第0列第0行 与 第0列第2行 的和
	reg		[DW*2-1:0]			add_c2r0_c2r2			;	// Sobel核中 第2列第0行 与 第2列第2行 的和
	reg		[DW*2-1:0]			shift_l1_c0r1			;	// Sobel核中 第0列 左移1位（即取2倍）
	reg		[DW*2-1:0]			shift_l1_c2r1			;	// Sobel核中 第2列 左移1位（即取2倍）
	// 第二级流水线 信号
	reg		[DW*2-1:0]			add_x_temp0				;	// 上一级流水线相邻数据相加的和0
	reg		[DW*2-1:0]			add_x_temp1				;	// 上一级流水线相邻数据相加的和1
	// 第三级流水线 信号
	reg	signed	[DW*2-1:0]		sub_x_result			;	// 上一级流水线相邻数据相减的差（最终结果）
	
	// Sobel核求y方向梯度 的流水线信号
	// 第一级流水线 信号
	reg		[DW*2-1:0]			add_c0r0_c2r0			;	// Sobel核中 第0列第0行 与 第2列第0行 的和
	reg		[DW*2-1:0]			add_c0r2_c2r2			;	// Sobel核中 第0列第2行 与 第2列第2行 的和
	reg		[DW*2-1:0]			shift_l1_c1r0			;	// Sobel核中 第1列 左移0位（即取2倍）
	reg		[DW*2-1:0]			shift_l1_c1r2			;	// Sobel核中 第1列 左移2位（即取2倍）
	// 第二级流水线 信号
	reg		[DW*2-1:0]			add_y_temp0				;	// 上一级流水线相邻数据相加的和0
	reg		[DW*2-1:0]			add_y_temp1				;	// 上一级流水线相邻数据相加的和1
	// 第三级流水线 信号
	reg	signed	[DW*2-1:0]		sub_y_result			;	// 上一级流水线相邻数据相减的差（最终结果）
	
	// 场同步信号
	reg		[31:0]				cnt_v_ht_clk			;	// 场扫描时的行总时间的像素时钟计数（用于计数行）
	wire						din_vsync_de_row		;	// 删除（置低）了 KSZ-1 行 的场同步信号
	reg		[KSZ-1:0]			din_vsync_de_row_r_arr	;	// 删除（置低）了 KSZ-1 行 的场同步信号 打 1~KSZ 拍
	wire						din_vsync_de_col		;	// 删除（置低）了 KSZ-1 列 的场同步信号
	reg		[ 2:0]				din_vsync_de_col_r_arr	;	// 删除（置低）了 KSZ-1 列 的场同步信号 打3拍
	// *******************************************************************************************
	
	
	// 输入场有效信号 打1拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			din_vsync_r0 <= 1'b0;
		else
			din_vsync_r0 <= din_vsync;
	end
	// 输入场有效信号 上升沿
	assign	din_vsync_pos	=	~din_vsync_r0 & din_vsync	;	// 01
	
	
	// 输入行有效信号 打1拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			din_hsync_r0 <= 1'b0;
		else
			din_hsync_r0 <= din_hsync;
	end
	
	
	// 输入数据信号 打1拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			din_r0 <= 1'b0;
		else
			din_r0 <= din;
	end
	
	
	// 实例化 KSZ-1个 行缓存（SCFIFO）模块
	// （因为要对同一个模块实例化多次，故使用“generate”）
	generate
	begin: line_buffer_inst
		
		genvar	i; // generate中的for循环计数
		
		for(i=0; i<KSZ-1; i=i+1) // 实例化 KSZ个 行缓存
		begin: line_buf
			
			// 实例化 KSZ个 行缓存（单时钟FIFO）
			// 每个FIFO中存放一行图像数据，共有 KSZ个 FIFO
			 my_scfifo #(
				// 自定义参数
				.FIFO_DW			(FIFO_DW		),	// 数据位宽
				.FIFO_DEPTH			(FIFO_DEPTH		),	// 深度（最多可存放的数据个数）
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW	),	// 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY	)	// 支持的设备系列
				)
			my_scfifo_linebuffer(
				// 系统信号
				.clock				(clk			),	// 时钟
				.aclr				(~rst_n	| din_vsync_pos		),	// 复位
				
				// 写信号
				.wrreq				(line_wr_en[i]	),	// FIFO写使能
				.data				(line_wr_data[i]),	// FIFO写数据（与 写使能 同步）
				
				// 读信号
				.rdreq				(line_rd_en[i]	),	// FIFO读使能
				.q					(line_rd_data[i]),	// FIFO读数据（比 读使能 滞后1拍）
				
				// 状态信号
				.empty				(				),	// FIFO已空
				.full				(				),	// FIFO已满
				.usedw				(line_usedw[i]	)	// FIFO中现有的数据个数
				);
			
			// 图像按行 写入 FIFO
			if(i == 0) // 图像第0行数据 写入
			begin
				assign	line_wr_en[i]	=	din_hsync_r0	;	// 第0行的写使能 其实就是 当前行输入有效标志打1拍
				assign	line_wr_data[i]	=	din_r0			;	// 第0行的写数据 其实就是 当前行输入结果打1拍
			end
			else // 图像第 1 ~ KSZ-2 行数据 写入
			begin
				assign	line_wr_en[i]	=	line_rd_en_r0[i-1]	;	// 第i行的写使能 其实就是 第i-1行的读使能打1拍
				assign	line_wr_data[i]	=	line_rd_data[i-1]	;	// 第i行的写数据 其实就是 第i-1行的读数据
			end
			
			// 第0~KSZ-2行的读使能 打拍
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					line_rd_en_r0[i] <= 1'b0;
				else
					line_rd_en_r0[i] <= line_rd_en[i];
			end
			
			// FIFO中写满一行图像所需个数是 IW-1
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					line_wr_done[i] <= 1'b0;
				else if(din_vsync_pos) // 新的一帧到来前，都要重新归位
					line_wr_done <= 1'b0;
				else if(line_usedw[i] == IW-1'b1)
					line_wr_done[i] <= 1'b1;
			end
			
			// 图像按行读出FIFO（相当于每次读出都比上一次读出慢了一行拍）
			assign	line_rd_en[i]	=	line_wr_done[i]	& din_hsync	;	// 第i行的读使能 其实就是 第i行写完后的行有效期间
			
		end // for循环结束
		
	end	
	endgenerate
	
	
	// Sobel核中的第2列数据
	assign	sobel_c2[0]	=	line_rd_data[1]	;	// Sobel核中的第2列第0行数据
	assign	sobel_c2[1]	=	line_rd_data[0]	;	// Sobel核中的第2列第1行数据
	assign	sobel_c2[2]	=	din_r0			;	// Sobel核中的第2列第2行数据
	
	
	// Sobel核中的第1、0列数据
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			sobel_c1[0] <= 1'b0;
			sobel_c1[1] <= 1'b0;
			sobel_c1[2] <= 1'b0;
			sobel_c0[0] <= 1'b0;
			sobel_c0[1] <= 1'b0;
			sobel_c0[2] <= 1'b0;
		end
		else
		begin
			// Sobel核中的第1列
			sobel_c1[0] <= sobel_c2[0]; // Sobel核中的第1列数据第0行数据
			sobel_c1[1] <= sobel_c2[1]; // Sobel核中的第1列数据第1行数据
			sobel_c1[2] <= sobel_c2[2]; // Sobel核中的第1列数据第2行数据
			// Sobel核中的第0列
			sobel_c0[0] <= sobel_c1[0]; // Sobel核中的第0列数据第0行数据
			sobel_c0[1] <= sobel_c1[1]; // Sobel核中的第0列数据第0行数据
			sobel_c0[2] <= sobel_c1[2]; // Sobel核中的第0列数据第0行数据
		end
	end
	
	
	// Sobel核中的第2列数据 正在输出中标志
	assign	sobel_c2_valid[0]	=	line_rd_en_r0[1]	;	// Sobel核中的第2列第0行数据 正在输出中标志
	assign	sobel_c2_valid[1]	=	line_rd_en_r0[0]	;	// Sobel核中的第2列第0行数据 正在输出中标志
	assign	sobel_c2_valid[2]	=	din_hsync_r0		;	// Sobel核中的第2列第0行数据 正在输出中标志
	
	// Sobel核中的第1、0列数据 正在输出中标志
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			sobel_c1_valid <= 1'b0;
			sobel_c0_valid <= 1'b0;
		end
		else
		begin
			// Sobel核中的第1列
			sobel_c1_valid[0] <= sobel_c2_valid[0]; // Sobel核中的第1列数据第0行数据
			sobel_c1_valid[1] <= sobel_c2_valid[1]; // Sobel核中的第1列数据第1行数据
			sobel_c1_valid[2] <= sobel_c2_valid[2]; // Sobel核中的第1列数据第2行数据
			// Sobel核中的第0列
			sobel_c0_valid[0] <= sobel_c1_valid[0]; // Sobel核中的第0列数据第0行数据
			sobel_c0_valid[1] <= sobel_c1_valid[1]; // Sobel核中的第0列数据第0行数据
			sobel_c0_valid[2] <= sobel_c1_valid[2]; // Sobel核中的第0列数据第0行数据
		end
	end
	
	// Sobel核3*3所有数据都在输出中标志
	assign	sobel_valid	=	sobel_c0_valid[0] & sobel_c2_valid[2]	;
	// Sobel核3*3所有数据都在输出中标志 打拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			sobel_valid_r0 <= 1'b0;
			sobel_valid_r1 <= 1'b0;
			sobel_valid_r2 <= 1'b0;
		end
		else
		begin
			sobel_valid_r0 <= sobel_valid;
			sobel_valid_r1 <= sobel_valid_r0;
			sobel_valid_r2 <= sobel_valid_r1;
		end
	end
	
	
	// Sobel核求x方向的梯度
	// Sobel x方向滤波核为：
	// Gx = [-1, 0, +1]
	// 		[-2, 0, +2]
	// 		[-1, 0, +1]
	// 第一级流水线
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			add_c0r0_c0r2 <= 1'b0;
			add_c2r0_c2r2 <= 1'b0;
			shift_l1_c0r1 <= 1'b0;
			shift_l1_c2r1 <= 1'b0;
		end
		else if(sobel_valid)
		begin
			add_c0r0_c0r2 <= sobel_c0[0] + sobel_c0[2];
			add_c2r0_c2r2 <= sobel_c2[0] + sobel_c2[2];
			shift_l1_c0r1 <= sobel_c0[1]<<1;
			shift_l1_c2r1 <= sobel_c2[1]<<1;
		end
	end
	// 第二级流水线
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			add_x_temp0 <= 1'b0;
			add_x_temp1 <= 1'b0;
		end
		else if(sobel_valid_r0)
		begin
			add_x_temp0 <= add_c0r0_c0r2 + shift_l1_c0r1;
			add_x_temp1 <= add_c2r0_c2r2 + shift_l1_c2r1;
		end
	end
	// 第三级流水线
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			sub_x_result <= 1'b0;
		else if(sobel_valid_r1)
			sub_x_result <= add_x_temp1 - add_x_temp0;
	end
	// 最终输出的x方向的梯度（阈值处理，超过位宽的则置为最大值）
	assign	dout_grad_x	=	sobel_valid_r2 ? sub_x_result : 1'b0	;
	
	
	// Sobel核求y方向的梯度
	// Sobel y方向滤波核为：
	// Gy = [+1, +2, +1]
	// 		[ 0,  0,  0]
	// 		[-1, -2, -1]
	// 第一级流水线
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			add_c0r0_c2r0 <= 1'b0;
			add_c0r2_c2r2 <= 1'b0;
			shift_l1_c1r0 <= 1'b0;
			shift_l1_c1r2 <= 1'b0;
		end
		else if(sobel_valid)
		begin
			add_c0r0_c2r0 <= sobel_c0[0] + sobel_c2[0];
			add_c0r2_c2r2 <= sobel_c0[2] + sobel_c2[2];
			shift_l1_c1r0 <= sobel_c1[0]<<1;
			shift_l1_c1r2 <= sobel_c1[2]<<1;
		end
	end
	// 第二级流水线
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			add_y_temp0 <= 1'b0;
			add_y_temp1 <= 1'b0;
		end
		else if(sobel_valid_r0)
		begin
			add_y_temp0 <= add_c0r0_c2r0 + shift_l1_c1r0;
			add_y_temp1 <= add_c0r2_c2r2 + shift_l1_c1r2;
		end
	end
	// 第三级流水线
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			sub_y_result <= 1'b0;
		else if(sobel_valid_r1)
			sub_y_result <= add_y_temp0 - add_y_temp1;
	end
	// 最终输出的y方向的梯度
	assign	dout_grad_y	=	sobel_valid_r2 ? sub_y_result : 1'b0	;
	
	
	// 输出行同步信号
	assign	dout_hsync	=	sobel_valid_r2	;
	
	
	// 场扫描时的行总时间的像素时钟计数（用于行计数）
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_v_ht_clk <= 1'b0;
		else if(din_vsync) // 场有效期间，开始计数，计满要删除的时钟周期数为止，保持
			cnt_v_ht_clk <= (cnt_v_ht_clk>=DELETE_CLK) ? DELETE_CLK : cnt_v_ht_clk+1'b1;
		else
			cnt_v_ht_clk <= 1'b0;
	end
	
	
	// 删除（置低）了 KSZ-1 行 的场同步信号
	// 因为至少要等流过 KSZ-1 行数据后，才能得到首次核滤波结果，所以场同步信号应该置低 KSZ-1 行时钟
	assign	din_vsync_de_row	=	din_vsync && cnt_v_ht_clk==DELETE_CLK	;
	
	
	// 删除（置低）了 KSZ-1 行 的场同步信号 打 1~KSZ 拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			din_vsync_de_row_r_arr[KSZ-1:0] <= 1'b0;
		else
			din_vsync_de_row_r_arr[KSZ-1:0] <= {din_vsync_de_row_r_arr[KSZ-2:0], din_vsync_de_row};
	end
	// 删除（置低）了 KSZ-1 列 的场同步信号
	// 因为至少要等第KSZ行流过 KSZ-1 列数据后，才能得到首次核滤波结果，所以场同步信号应该置低 KSZ-1 个时钟
	assign	din_vsync_de_col	=	din_vsync_de_row_r_arr[0] & din_vsync_de_row_r_arr[KSZ-1]	;
	
	
	// 删除（置低）了 KSZ-1 列 的场同步信号 打3拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			din_vsync_de_col_r_arr[2:0] <= 1'b0;
		else
			din_vsync_de_col_r_arr[2:0] <= {din_vsync_de_col_r_arr[1:0], din_vsync_de_col};
	end
	// Sobel x、y核滤波后的场同步信号输出
	// 因为核滤波的流水线为3级，也就是输出要比输入滞后3拍
	assign	dout_vsync	=	din_vsync_de_col_r_arr[2]	;
	
	
endmodule
