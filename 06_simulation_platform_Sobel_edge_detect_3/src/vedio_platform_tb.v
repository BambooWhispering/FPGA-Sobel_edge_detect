/*
图像处理视频仿真平台 顶层仿真文件
*/
`timescale 1ns/1ps
module vedio_platform_tb();
	
	// 系统信号
	reg					clk				;	// 参考时钟（clock）（51.84MHz）
	reg					rst_n			;	// 复位（reset）
	
	// 控制信号
	reg		[ 1:0]		src_sel			;	// 数据源选择（source selection）（用于选择要输入的图像文本文件）
	
	// 源视频信号
	wire				src_pclk		;	// 源视频 像素时钟输出（pixel clock）
	wire				src_hsync		;	// 源视频 行同步信号
	wire				src_vsync		;	// 源视频 场同步信号
	wire	[ 7:0]		src_data_out	;	// 源视频 像素数据输出
	
	// 捕获视频信号
	reg					cap_pclk		;	// 捕获视频 像素时钟（pixel clock）
	wire				cap_hsync		;	// 捕获视频 行同步信号（数据有效输出中标志）
	wire				cap_vsync		;	// 捕获视频 场同步信号
	wire	[ 7:0]		cap_data_out	;	// 捕获视频 像素数据输出（单通道8位灰度时）
	// wire	[23:0]		cap_data_out	;	// 捕获视频 像素数据输出（三通道RGB888时）
	
	// Sobel边缘检测后的信号
	wire				sobel_vsync		;	// 输出数据场有效信号
	wire				sobel_hsync		;	// 输出数据行有效信号
	wire	[7:0]		sobel_data_out	; 	// 输出梯度数据（与 输出数据行有效信号 同步）
	wire	[19:0]		sobel_angle		;	// 输出梯度与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
	
	// 目的视频信号
	wire				dst_pclk		;	// 目的视频 像素时钟输出（pixel clock）
	wire				dst_hsync		;	// 目的视频 行同步信号
	wire				dst_vsync		;	// 目的视频 场同步信号
	wire	[ 7:0]		dst_data_out	;	// 目的视频 像素数据输出（单通道8位灰度时）
	// wire	[23:0]		dst_data_out	;	// 目的视频 像素数据输出（三通道RGB888时）
	
	
	// 实例化 源视频数据产生模块
	// 数据来源：从matlab生成的图像的.txt文件
	// ----通道数为1时（灰度图像）：
	// 单场所需像素时钟数 = H_TOTAL*V_TOTAL = 1440*600 = 864,000
	// 扫描频率为60Hz时（即每s扫描60帧图像），1s内所需像素时钟数 = 单场所需像素时钟数*每s扫描的场数 = 864,000*60 = 51,840,000
	// 故，像素时钟频率至少为 51,840,000Hz = 51.84MHz
	// 取 像素时钟频率 = 51.84MHz
	// -----通道数为3时（RGB888）：
	// 单场所需像素时钟数 = H_TOTAL*SRC_CHN*V_TOTAL = 1440*3*600 = 2,592,000
	// 扫描频率为60Hz时（即每s扫描60帧图像），1s内所需像素时钟数 = 单场所需像素时钟数*每s扫描的场数 = 2,592,000*60 = 155,520,000
	// 故，像素时钟频率至少为 155,520,000Hz = 155.52MHz
	// 取 像素时钟频率 = 155.52MHz
	vedio_src #(
		// 图像基本参数
		.IW				('d640			),	// 图像宽（image width）
		.IH				('d480			),	// 图像高（image height）
		
		// 源视频参数
		// 基本参数
		.SRC_DW			('d8			),	// 源视频输出像素数据位宽（data width of source）
		.SRC_CHN		('d1			),	// 源视频通道数（channels of source）（单通道8位灰度时）
		// .SRC_CHN		('d3			),	// 源视频通道数（channels of source）（三通道RGB888时）
		// 行参数（对完整的像素（该像素必须包含所有通道）进行计数）
		.H_TOTAL		('d1440			),	// 行总时间
		// 场参数（对行数进行计数）
		.V_TOTAL		('d600			),	// 场总时间
		.V_SYNC			('d45			),	// 场同步时间
		.V_BACK			('d55			),	// 场后肩
		
		// 调试辅助信号
		.FILE_ADDR0		("D:/FPGA_learning/Projects/08_ImageProcessing/06_simulation_platform_Sobel_edge_detect_3/doc/img_src/img_src0.txt"),	// src_sel为0时选择的输入文件地址
		.FILE_ADDR1		("D:/FPGA_learning/Projects/08_ImageProcessing/06_simulation_platform_Sobel_edge_detect_3/doc/img_src/img_src1.txt"),	// src_sel为1时选择的输入文件地址
		.FILE_ADDR2		("D:/FPGA_learning/Projects/08_ImageProcessing/06_simulation_platform_Sobel_edge_detect_3/doc/img_src/img_src2.txt"),	// src_sel为2时选择的输入文件地址
		.FILE_ADDR3		("D:/FPGA_learning/Projects/08_ImageProcessing/06_simulation_platform_Sobel_edge_detect_3/doc/img_src/img_src3.txt")	// src_sel为3时选择的输入文件地址
		)
	vedio_src_u0(
		// 系统信号
		.clk			(clk			),	// 参考时钟（clock）
		.rst_n			(rst_n			),	// 复位（reset）
		
		// 控制信号
		.src_sel		(src_sel		),	// 数据源选择（source selection）（用于选择要输入的图像文本文件）
		
		// 源视频信号
		.src_pclk		(src_pclk		),	// 源视频 像素时钟输出（pixel clock）
		.src_hsync		(src_hsync		),	// 源视频 行同步信号
		.src_vsync		(src_vsync		),	// 源视频 场同步信号
		.src_data_out	(src_data_out	)	// 源视频 像素数据输出
		);
	
	
	// 实例化 视频捕获模块（相当于缓存）：
	// 将虚拟产生的图像数据源 捕获并转换为 所需的数据格式。
	// 因为一般来说，若采用RGB888的格式，
	// 则摄像头输出的数据是8位的，
	// 所以需要将摄像头输出的连续的3个8位数据即RGB三通道的数据合并，才能得到一个完整的24位像素数据
	vedio_cap #(
		// 图像基本参数
		.IW				('d640			),	// 图像宽（image width）
		.IH				('d480			),	// 图像高（image height）
		
		// 源视频参数（摄像头输出参数）
		.SRC_DW			('d8			),	// 源视频的像素数据位宽（data width of source）
		.SRC_CHN		('d1			),	// 源视频通道数（channels of source）（单通道8位灰度时）
		// .SRC_CHN		('d3			),	// 源视频通道数（channels of source）（三通道RGB888时）
		
		// 捕获视频参数（捕获输出参数）
		.CAP_DW			('d8			)	// 目的视频的像素数据位宽（data width of capture）（单通道8位灰度时）
		// .CAP_DW			('d24			)	// 目的视频的像素数据位宽（data width of capture）（三通道RGB888时）
		)
	vedio_cap_u0(
		// 系统信号
		.rst_n			(rst_n			),	// 复位（reset）
		
		// 源视频信号（源视频产生模块 输出给 视频捕获模块）
		.src_pclk		(src_pclk		),	// 源视频 像素时钟（pixel clock）
		.src_hsync		(src_hsync		),	// 源视频 行同步信号（数据有效输出中标志）
		.src_vsync		(src_vsync		),	// 源视频 场同步信号
		.src_data_out	(src_data_out	),	// 源视频 像素数据输出
		
		// 捕获视频信号
		.cap_pclk		(cap_pclk		),	// 捕获视频 像素时钟（pixel clock）（捕获周期 = 源周期*3）
		.cap_hsync		(cap_hsync		),	// 捕获视频 行同步信号（数据有效输出中标志）
		.cap_vsync		(cap_vsync		),	// 捕获视频 场同步信号
		.cap_data_out	(cap_data_out	)	// 捕获视频 像素数据输出
		);
	
	
	// 实例化 Sobel边缘检测模块
	sobel_top #(
		// 视频数据流参数
		.DW					('d8			),	// 输入数据位宽
		.IW					('d640			),	// 输入图像宽（image width）
		.IH					('d480			),	// 输入图像高（image height）
	
		// 行参数
		.H_TOTAL			('d1440			),	// 行总时间
		// 场参数（多少个时钟周期，注意这里不是多少行！！！）
		.V_FRONT_CLK		('d28800		),	// 场前肩（一般为V_FRONT*H_TOTAL，也有一些相机给的就是时钟周期数而不需要乘以行数）
		
		// 单时钟FIFO（用于行缓存）参数
		.FIFO_DEPTH			('d1024			),	// SCFIFO 深度（最多可存放的数据个数）（2的整数次幂，且>=图像宽（也就是一行））
		.FIFO_DEPTH_DW		('d10			),	// SCFIFO 深度位宽
		.DEVICE_FAMILY		("Stratix III"	),	// SCFIFO 支持的设备系列
		
		// 参数选择
		.IS_BOUND_ADD		(1'b1			),	// 是否要进行边界补充（1——补充边界；0——忽略边界）
		
		// Cordic参数
		.T_IR_NUM			('d15			),	// 总迭代次数（total iteration number）（可选 15~18）
		.DW_DOT				('d4			),	// 输入数据x、y坐标的扩展小数位宽（用于提高精度）（输入数据x、y坐标位宽=DW_x_y+DW_DOT 须<=32）
		
		// Sobel结果二值化阈值参数
		.BIANRY_THRESHOLD	('d128			)	// 二值化时的阈值（大于等于该阈值的输出全1，小于该阈值的输出0）（一般取输入值的一半=256/2=128）
		)
	sobel_top_u0(
		// 系统信号
		.clk				(cap_pclk		),	// 时钟（clock）
		.rst_n				(rst_n			),	// 复位（reset）
		
		// 输入信号（源视频信号）
		.sb_din_vsync		(cap_vsync		),	// 输入数据场有效信号
		.sb_din_hsync		(cap_hsync		),	// 输入数据行有效信号
		.sb_din				(cap_data_out	),	// 输入数据（与 输入数据行有效信号 同步）
		
		// 输出信号（Sobel边缘检测后的信号）
		.sb_dout_vsync		(sobel_vsync	),	// 输出数据场有效信号
		.sb_dout_hsync		(sobel_hsync	),	// 输出数据行有效信号
		.sb_dout			(sobel_data_out	), 	// 输出梯度数据（与 输出数据行有效信号 同步）
		.sb_dout_angle		(sobel_angle	),	// 输出梯度与0°轴的夹角α∈[0°, 360°)的归一化值：α/(2π)*(2^20)（与输出数据行有效信号同步）
		
		// Sobel选择参数
		.is_binary			(1'b0			)	// 是否要对边缘检测结果进行二值化（二值化 即 输出只能为0或全1）
	);
	
	
	// 实例化 目的视频保存模块
	// 将处理后的目的视频 保存为txt文件，以便用matlab生成目的图片
	vedio_store #(
		.DST_DW			('d8			),	// 目的视频输出像素数据位宽（data width of source）（单通道8位灰度时）
		// .DST_DW			('d24			),	// 目的视频输出像素数据位宽（data width of source）（三通道RGB888时）
		
		// 调试辅助信号
		.FILE_ADDR0		("D:/FPGA_learning/Projects/08_ImageProcessing/06_simulation_platform_Sobel_edge_detect_3/doc/img_dst/img_dst0.txt"),	// src_sel为0时选择的输出文件地址
		.FILE_ADDR1		("D:/FPGA_learning/Projects/08_ImageProcessing/06_simulation_platform_Sobel_edge_detect_3/doc/img_dst/img_dst1.txt"),	// src_sel为1时选择的输出文件地址
		.FILE_ADDR2		("D:/FPGA_learning/Projects/08_ImageProcessing/06_simulation_platform_Sobel_edge_detect_3/doc/img_dst/img_dst2.txt"),	// src_sel为2时选择的输出文件地址
		.FILE_ADDR3		("D:/FPGA_learning/Projects/08_ImageProcessing/06_simulation_platform_Sobel_edge_detect_3/doc/img_dst/img_dst3.txt")	// src_sel为3时选择的输出文件地址
		)
	vedio_store_u0(
		// 系统信号
		.rst_n			(rst_n			),	// 复位（reset）
		
		// 控制信号
		.src_sel		(src_sel		),	// 数据源选择（source selection）（用于选择要输出的图像文本文件）
		
		// 目的视频信号
		.dst_pclk		(dst_pclk		),	// 目的视频 像素时钟输出（pixel clock）
		.dst_hsync		(dst_hsync		),	// 目的视频 行同步信号（数据有效输出中标志）
		.dst_vsync		(dst_vsync		),	// 目的视频 场同步信号
		.dst_data_out	(dst_data_out	)	// 目的视频 像素数据输出
		);
	assign	dst_pclk		=	cap_pclk		;
	assign	dst_hsync		=	sobel_hsync		;
	assign	dst_vsync		=	sobel_vsync		;
	assign	dst_data_out	=	sobel_data_out	;
	
	
	// 系统时钟信号（源视频像素时钟） 产生
	localparam T_CLK = 19.29; // 系统时钟（51.84MHz）周期：19.29ns	（单通道8位灰度时）
	// localparam T_CLK = 6.43; // 系统时钟（155.52MHz）周期：6.43ns	（三通道RGB888时）
	initial
		clk = 1'b1;
	always #(T_CLK/2)
		clk = ~clk;
	// 捕获视频 像素时钟信号 产生
	localparam T_CAP_CLK = 19.29; // 系统时钟（51.84MHz）周期：19.29ns
	initial
		cap_pclk = 1'b1;
	always #(T_CAP_CLK/2)
		cap_pclk = ~cap_pclk;
	
	
	// 复位 任务
	task task_reset;
	begin
		rst_n = 1'b0;
		repeat(10) @(negedge clk)
			rst_n = 1'b1;
	end
	endtask
	
	
	// 系统初始化 任务
	task task_sysinit;
	begin
		src_sel = 4'd0; // （单通道8位灰度时）
		// src_sel = 4'd1; // （三通道RGB888时）
	end
	endtask
	
	
	// 激励信号 产生
	initial
	begin
		task_sysinit;
		task_reset;
		
		#17_300_000 $stop;
		// #34_000_000 $stop;
	end
	
endmodule
