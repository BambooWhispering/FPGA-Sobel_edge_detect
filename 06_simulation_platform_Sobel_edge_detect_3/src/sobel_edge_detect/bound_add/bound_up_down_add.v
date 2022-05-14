/*
上下边界补充：
通过复制边界的像素点，在图像的上下边界各添加 (正方形核边长-1)/2 行像素点
*/
module bound_up_down_add(
	// 系统信号
	clk					,	// 时钟（clock）
	rst_n				,	// 复位（reset）
	
	// 输入信号
	din_vsync			,	// 输入数据场有效信号
	din_hsync			,	// 输入数据行有效信号
	din					,	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号
	dout_vsync			,	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	dout_hsync			,	// 输出数据行有效信号
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
	parameter	H_DISP			=	IW					;	// 行显示时间
	parameter	H_SYNC			=	H_TOTAL-H_DISP		;	// 行同步时间
	// 场参数（多少个时钟周期，注意这里不是多少行！！！）
	parameter	V_FRONT_CLK		=	'd28800				;	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
	
	// 单时钟FIFO（用于行缓存）参数
	parameter	FIFO_DW			=	DW					;	// SCFIFO 数据位宽
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
	output						dout_hsync				;	// 输出数据行有效信号
	output	reg	[DW-1:0]		dout					; 	// 输出数据（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// 输入场有效信号 边沿检测
	reg							din_vsync_r0			;	// 输入场有效信号 打1拍
	wire						din_vsync_pos			;	// 输入场有效信号 上升沿
	
	// 输入行有效信号 边沿检测
	reg							din_hsync_r0			;	// 输入行有效信号 打1拍
	wire						din_hsync_neg			;	// 输入行有效信号 下降沿
	
	// 输入数据信号 打拍
	reg		[DW-1:0]			din_r0					;	// 输入数据信号 打1拍
	reg		[DW-1:0]			din_r1					;	// 输入数据信号 打2拍
	
	// 行、场计数
	reg							cnt_ht_clk_en			;	// 行扫描时的行总时间的像素时钟计数 使能标志
	reg		[13:0]				cnt_ht_clk				;	// 行扫描时的行总时间的像素时钟计数
	reg		[13:0]				cnt_v_row				;	// 场扫描时的显示行数计数
	reg		[31:0]				cnt_vf_clk				;	// 场扫描时的场前肩的像素时钟计数
	reg		[31:0]				cnt_v_ht_clk			;	// 场扫描时的行总时间的像素时钟计数
	
	// 添加了上下边界的 场、行有效信号
	wire						din_add_ud_vsync		;	// 添加了上下边界的 场有效信号（多了 KSZ-1 行）
	wire						din_add_ud_hsync		;	// 添加了上下边界的 行有效信号（多了 KSZ 行）
	
	// 添加了上下边界的 场、行有效信号 打拍
	reg							din_add_ud_vsync_r0		;	// 添加了上下边界的 场有效信号 打1拍（多了 KSZ-1 行）
	reg							din_add_ud_hsync_r0		;	// 添加了上下边界的 行有效信号 打1拍（多了 KSZ 行）
	
	// 行缓存（SCFIFO） 信号
	wire	[KSZ-1:0]			line_wr_en				;	// FIFO写使能（KSZ个）
	wire	[FIFO_DW-1:0]		line_wr_data[0:KSZ-1]	;	// FIFO写数据（与 写使能 同步）（KSZ个）
	wire	[KSZ-1:0]			line_rd_en				;	// FIFO读使能（KSZ个）
	wire	[FIFO_DW-1:0]		line_rd_data[0:KSZ-1]	;	// FIFO读数据（比 读使能 滞后1拍）（KSZ个）
	wire	[FIFO_DEPTH_DW-1:0]	line_usedw[0:KSZ-1]		;	// FIFO中现有的数据个数
	
	// 行缓存（SCFIFO） 信号 打拍
	reg		[KSZ-1:0]			line_rd_en_r0			;	// FIFO读使能（KSZ个） 打1拍
	
	// SCFIFO 辅助信号
	reg		[KSZ-1:0]			line_wr_done			;	// 一行图像核行之和写进FIFO完成标志（KSZ个）（写完后就一直为1）
	
	// 输出行有效信号 边沿检测
	reg							dout_hsync_r0			;	// 输出行有效信号 打1拍
	wire						dout_hsync_neg			;	// 输出行有效信号 下降沿
	
	// 行读出计数
	reg		[15:0]				cnt_line_rd				;	// 行读出计数
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
	// 输入行有效信号 下降沿
	assign	din_hsync_neg	=	din_hsync_r0 & ~din_hsync	;	// 10
	
	
	// 输入数据信号 打2拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			din_r0 <= 1'b0;
			din_r0=1 <= 1'b0;
		end
		else
		begin
			din_r0 <= din;
			din_r1 <= din_r0;
		end
	end
	
	
	// 行扫描时的行总时间的像素时钟计数 使能标志
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_ht_clk_en <= 1'b0;
		else if(din_vsync_pos) // 输入场有效信号上升沿时，行扫描时的行总时间的像素时钟计数使能标志 无效
			cnt_ht_clk_en <= 1'b0;
		else if(din_hsync_neg) // 直到 第一个输入行有效信号下降沿之后，行扫描时的行总时间的像素时钟计数使能标志 就一直有效
			cnt_ht_clk_en <= 1'b1;
	end
	
	
	// 行扫描时的行总时间的像素时钟计数（每行的时钟周期计数）
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_ht_clk <= 1'b0;
		else if(cnt_ht_clk_en) // 每来一个时钟，计数值+1；计满清0
			cnt_ht_clk <= (cnt_ht_clk>=H_TOTAL-1'b1) ? 1'b0 : cnt_ht_clk+1'b1;
		else
			cnt_ht_clk <= 1'b0;
	end
	
	
	// 场扫描时的显示行数计数（每场的行数计数）
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_v_row <= 1'b0;
		else if(cnt_ht_clk_en)
		begin
			if(cnt_ht_clk == H_TOTAL-1'b1) // 每行最后一个像素的下一拍，行数计数值+1，计满（源图像行数（IH）+要补充的行数（KSZ-1）+1）保持
				cnt_v_row <= (cnt_v_row>=IH+KSZ) ? (IH+KSZ) : cnt_v_row+1'b1;
			else
				cnt_v_row <= cnt_v_row;
		end
		else if(din_hsync_neg) // 补上首行
			cnt_v_row <= cnt_v_row+1'b1;
		else
			cnt_v_row <= 1'b0;
	end
	
	
	// 添加了上下边界的 行同步信号（多了 KSZ 行）（比 源输入行同步信号 滞后一拍） 的生成
	// 源图像行同步信号打1拍，补上要补充的行（要显示的补充后的行数未计满，且该行的显示期（>行同步时期）时）
	assign	din_add_ud_hsync	=	(din_hsync_r0 || (cnt_v_row<IH+KSZ && cnt_ht_clk>=H_SYNC));
	
	
	// 场扫描时的场前肩的像素时钟计数（要补充的场前肩的时钟周期计数）
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_vf_clk <= 1'b0;
		else if(cnt_v_row == IH+KSZ) // 要显示的补充后的行数计满时，开始进行场前肩像素时钟计数
			cnt_vf_clk <= (cnt_vf_clk>=V_FRONT_CLK) ? V_FRONT_CLK : cnt_vf_clk+1'b1;
		else
			cnt_vf_clk <= 1'b0;
	end
	
	
	// 场扫描时的行总时间的像素时钟计数（要删除的首行的时钟周期计数）（因为缓存了KSZ行，实际需要KSZ-1行，所以舍弃掉源首行）
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_v_ht_clk <= 1'b0;
		else if(din_vsync_r0) // 场有效期间，开始计数，计满要删除的时钟周期数为止，保持
			cnt_v_ht_clk <= (cnt_v_ht_clk>=H_TOTAL) ? H_TOTAL : cnt_v_ht_clk+1'b1;
		else
			cnt_v_ht_clk <= 1'b0;
	end
	
	
	// 添加了上下边界的 场同步信号（多了 KSZ-1 行） 的生成
	// 源图像场同步信号打1拍，补上要补充的行、以及被忽略的场前肩
	assign	din_add_ud_vsync	=	((din_vsync_r0 && cnt_v_ht_clk>=H_TOTAL) || 
									(cnt_v_row>1'b0 && cnt_v_row<IH+KSZ) || 
									(cnt_v_row==IH+KSZ && cnt_vf_clk<V_FRONT_CLK));
	
	
	// 添加了上下边界的 场同步信号（多了 KSZ-1 行） 打1拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			din_add_ud_vsync_r0 <= 1'b0;
		else
			din_add_ud_vsync_r0 <= din_add_ud_vsync;
	end
	
	
	// 添加了上下边界的 行同步信号（多了 KSZ 行） 打1拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			din_add_ud_hsync_r0 <= 1'b0;
		else
			din_add_ud_hsync_r0 <= din_add_ud_hsync;
	end
	
	
	// 实例化 KSZ个 行缓存（SCFIFO）模块
	// 因为需要在上下边界各复制添加 (KSZ-1)/2 行，也就是总共需要缓存 (KSZ-1) 行，
	// 但是为了方便，直接缓存KSZ行，然后舍弃掉源首行即可
	// （因为要对同一个模块实例化多次，故使用“generate”）
	generate
	begin: line_buffer_inst
		
		genvar	i; // generate中的for循环计数
		
		for(i=0; i<KSZ; i=i+1) // 实例化 KSZ个 行缓存
		begin: line_buf
			
			// 实例化 KSZ个 行缓存（单时钟FIFO）
			// 每个FIFO中存放一行图像数据，共有 KSZ个 FIFO
			 my_scfifo #(
				// 自定义参数
				.FIFO_DW			(FIFO_DW				),	// 数据位宽
				.FIFO_DEPTH			(FIFO_DEPTH				),	// 深度（最多可存放的数据个数）
				.FIFO_DEPTH_DW		(FIFO_DEPTH_DW			),	// 深度位宽
				.DEVICE_FAMILY		(DEVICE_FAMILY			)	// 支持的设备系列
				)
			my_scfifo_linebuffer(
				// 系统信号
				.clock				(clk					),	// 时钟
				.aclr				(~rst_n	| din_vsync_pos	),	// 复位
				
				// 写信号
				.wrreq				(line_wr_en[i]			),	// FIFO写使能
				.data				(line_wr_data[i]		),	// FIFO写数据（与 写使能 同步）
				
				// 读信号
				.rdreq				(line_rd_en[i]			),	// FIFO读使能
				.q					(line_rd_data[i]		),	// FIFO读数据（比 读使能 滞后1拍）
				
				// 状态信号
				.empty				(						),	// FIFO已空
				.full				(						),	// FIFO已满
				.usedw				(line_usedw[i]			)	// FIFO中现有的数据个数
				);
			
			// 写入第0行，写满一行后开始读出第0行；
			// 读出第0行的下一拍，开始写入第1行。
			// 写入第1行，写满一行后开始读出第1行；
			// 读出第1行的下一拍，开始写入第2行。
			// 以此类推。
			
			// 若希望写与读不同步，那么 写应该比读滞后1拍。
			// 故，若读的使能基准为 din_add_ud_hsync，
			// 则写的使能基准应该为 din_add_ud_hsync_r0
			
			// 图像按行 写入 FIFO
			if(i == 0) // 图像第0行数据 写入
			begin
				// 若 写的使能基准为 din_add_ud_hsync_r0，由于 din_add_ud_hsync_r0 比 din 滞后2拍，
				// 故 写的数据基准为 din_r1
				assign	line_wr_en[i]	=	din_add_ud_hsync_r0	;	// 第0行的写使能
				assign	line_wr_data[i]	=	din_r1				;	// 第0行的写数据
			end
			else // 图像第 1 ~ KSZ-1 行数据 写入
			begin
				assign	line_wr_en[i]	=	line_rd_en_r0[i-1]	;	// 第i行的写使能 其实就是 第i-1行的读使能打1拍
				assign	line_wr_data[i]	=	line_rd_data[i-1]	;	// 第i行的写数据 其实就是 第i-1行的读数据
			end
			
			// 第0~KSZ-1行的读使能 打拍
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					line_rd_en_r0[i] <= 1'b0;
				else
					line_rd_en_r0[i] <= line_rd_en[i];
			end
			
			// FIFO中写满一行图像所需个数是 IW，
			// FIFO中每帧每写完一行，写完成标志置1
			always @(posedge clk, negedge rst_n)
			begin
				if(!rst_n)
					line_wr_done[i] <= 1'b0;
				else if(din_vsync_pos) // 新的一帧到来前，都要重新归位
					line_wr_done <= 1'b0;
				else if(line_usedw[i] == IW-1'b1)
					line_wr_done[i] <= 1'b1;
			end
			
			// 图像按行读出FIFO
			// 读的使能基准为 din_add_ud_hsync，且应该在FIFO写完一行时才能读出，以达到行缓存的目的。
			// 相当于 第0行读使能 比 din_add_ud_hsync 少了1行；
			//        第1行读使能 比 din_add_ud_hsync 少了2行；
			// 以此类推。
			assign	line_rd_en[i]	=	line_wr_done[i]	& din_add_ud_hsync	;	// 第i行的读使能 其实就是 第i行写完后的下一拍
			
		end // for循环结束
		
	end	
	endgenerate
	
	
	// 输出行同步信号（多了 KSZ-1 行）
	// 为了使输出行同步信号 比 源输入行同步信号 多 KSZ-1 行，可以把第0行的读使能作为输出行同步信号，
	// （第0行读使能 比 din_add_ud_hsync 少了 1 行，而 din_add_ud_hsync 比 din_hsync 多了 KSZ 行）
	assign	dout_hsync	=	line_rd_en_r0[0]	;
	
	
	// 输出行同步信号 打1拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			dout_hsync_r0 <= 1'b0;
		else
			dout_hsync_r0 <= dout_hsync;
	end
	// 输出行同步信号下降沿
	assign	dout_hsync_neg	=	dout_hsync_r0 & ~dout_hsync	;	// 10
	
	
	// 一帧中的输出行计数（用于确定数据输出）
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_line_rd <= 1'b0;
		else if(din_vsync_pos)
			cnt_line_rd <= 1'b0;
		else if(dout_hsync_neg)
			cnt_line_rd <= cnt_line_rd + 1'b1;
	end
	
	
	// 输出数据
	generate
	begin: line_add
		
		if(KSZ == 3)
		begin: line_add_ksz_3
			always @(*)
			begin
				if(dout_hsync)
				begin
					case(cnt_line_rd)
						'd0		:	dout = line_rd_data[0];
						IH+1'b1	:	dout = line_rd_data[2];
						default	:	dout = line_rd_data[1];
					endcase
				end
				else
					dout = 1'b0;
			end
		end
		
		else if(KSZ == 5)
		begin: line_add_ksz_5
			always @(*)
			begin
				if(dout_hsync)
				begin
					case(cnt_line_rd)
						'd0		:	dout = line_rd_data[0];
						'd1		:	dout = line_rd_data[1];
						IH+'d2	:	dout = line_rd_data[3];
						IH+'d3	:	dout = line_rd_data[4];
						default	:	dout = line_rd_data[2];
					endcase
				end
				else
					dout = 1'b0;
			end
		end
		
		else if(KSZ == 7)
		begin: line_add_ksz_7
			always @(*)
			begin
				if(dout_hsync)
				begin
					case(cnt_line_rd)
						'd0		:	dout = line_rd_data[0];
						'd1		:	dout = line_rd_data[1];
						'd2		:	dout = line_rd_data[2];
						IH+'d3	:	dout = line_rd_data[4];
						IH+'d4	:	dout = line_rd_data[5];
						IH+'d5	:	dout = line_rd_data[6];
						default	:	dout = line_rd_data[3];
					endcase
				end
				else
					dout = 1'b0;
			end
		end
		
	end
	endgenerate
	
	
	// 输出场同步信号（多了KSZ-1行）
	// 因为 读的使能基准为 din_add_ud_hsync，而 输出行同步信号使用了 读使能打1拍的信号 作为基准，
	// 所以 为了保证数据同步，输出场同步信号 也需要为 din_add_ud_vsync 打1拍
	assign	dout_vsync		=	din_add_ud_vsync_r0	;
	
	
endmodule
