/*
左右边界补充：
通过复制边界的像素点，在图像的左右边界各添加 (正方形核边长-1)/2 个像素点
*/
module bound_left_right_add(
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
	// ******************************************************************************************
	
	
	// *******************************************端口声明***************************************
	// 系统信号c
	input						clk						;	// 时钟（clock）
	input						rst_n					;	// 复位（reset）
	
	// 输入信号
	input						din_vsync				;	// 输入数据场有效信号
	input						din_hsync				;	// 输入数据行有效信号
	input		[DW-1:0]		din						;	// 输入数据（与 输入数据行有效信号 同步）
	
	// 输出信号
	output						dout_vsync				;	// 输出数据场有效信号（左右对齐，即场后肩、场前肩不变）
	output						dout_hsync				;	// 输出数据行有效信号（左对齐，即在行有效期右边扩充列）
	output	reg	[DW-1:0]		dout					; 	// 输出数据（与 输出数据行有效信号 同步）
	// *******************************************************************************************
	
	
	// *****************************************内部信号声明**************************************
	// 输入信号 打拍
	reg		[KSZ-1:0]			din_vsync_r_arr			;	// 输入场同步信号 打 KSZ 拍
	reg		[KSZ-1:0]			din_hsync_r_arr			;	// 输入行同步信号 打 KSZ 拍
	reg		[DW-1:0]			din_r_arr[0:KSZ-1]		;	// 输入数据信号 打 KSZ 拍
	
	// for循环计数
	integer						i						;	// for循环计数
	
	// 输出行显示期的时钟周期计数
	reg		[13:0]				cnt_hs					;	// 输出行显示期的时钟周期计数
	// *******************************************************************************************
	
	
	// 输入场同步信号、行同步信号、输入有效数据信号 打 KSZ 拍
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
		begin
			for(i=0; i<KSZ; i=i+1)
			begin
				din_vsync_r_arr[i] <= 1'b0;
				din_hsync_r_arr[i] <= 1'b0;
				din_r_arr[i] <= 1'b0;
			end
		end
		else
		begin
			din_vsync_r_arr[0] <= din_vsync;
			din_hsync_r_arr[0] <= din_hsync;
			din_r_arr[0] <= din;
			for(i=1; i<KSZ; i=i+1)
			begin
				din_vsync_r_arr[i] <= din_vsync_r_arr[i-1];
				din_hsync_r_arr[i] <= din_hsync_r_arr[i-1];
				din_r_arr[i] <= din_r_arr[i-1] ;
			end
		end
	end
	
	
	// 输出行有效信号（与输入行有效信号左对齐）
	assign	dout_hsync	=	din_hsync_r_arr[0] | din_hsync_r_arr[ KSZ-1'b1 ]	;	// 需要在左右共补充（KSZ-1）个
	
	
	// 输出场有效信号（与输入场有效信号左右对齐）
	assign	dout_vsync	=	din_vsync_r_arr[0] | din_vsync_r_arr[ KSZ-1'b1 ]	;
	
	
	// 输出行显示期的时钟周期计数
	always @(posedge clk, negedge rst_n)
	begin
		if(!rst_n)
			cnt_hs <= 1'b0;
		else if(dout_hsync) // 输出行显示期间，对时钟继续计数
			cnt_hs <= cnt_hs + 1'b1;
		else
			cnt_hs <= 1'b0;
	end
	
	
	// 输出数据
	generate
	begin: col_add
		
		if(KSZ == 3)
		begin: col_add_ksz_3
			always @(*)
			begin
				if(dout_hsync)
				begin
					case(cnt_hs)
						'd0		:	dout = din_r_arr[0];
						IW+1'b1	:	dout = din_r_arr[2];
						default	:	dout = din_r_arr[1];
					endcase
				end
				else
					dout = 1'b0;
			end
		end
		
		else if(KSZ == 5)
		begin: col_add_ksz_5
			always @(*)
			begin
				if(dout_hsync)
				begin
					case(cnt_hs)
						'd0		:	dout = din_r_arr[0];
						'd1		:	dout = din_r_arr[1];
						IW+'d2	:	dout = din_r_arr[3];
						IW+'d3	:	dout = din_r_arr[4];
						default	:	dout = din_r_arr[2];
					endcase
				end
				else
					dout = 1'b0;
			end
		end
		
		else if(KSZ == 7)
		begin: col_add_ksz_7
			always @(*)
			begin
				if(dout_hsync)
				begin
					case(cnt_hs)
						'd0		:	dout = din_r_arr[0];
						'd1		:	dout = din_r_arr[1];
						'd2		:	dout = din_r_arr[2];
						IW+'d3	:	dout = din_r_arr[4];
						IW+'d4	:	dout = din_r_arr[5];
						IW+'d5	:	dout = din_r_arr[6];
						default	:	dout = din_r_arr[3];
					endcase
				end
				else
					dout = 1'b0;
			end
		end
		
	end
	endgenerate
	
	
endmodule
