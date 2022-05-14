% 均值滤波

close;
clear;
clc;

% 读取原始灰度图片，到矩阵中
img = imread('./img_src/img_gray.jpeg'); 

% 3*3的核进行Sobel边缘检测后，存入矩阵中
txt_sobel = edge(img, 'sobel'); % 对原始灰度矩阵进行3*3核的均值滤波，结果存入矩阵中

% 矩阵转为图片
imwrite(txt_sobel, './img_dst_gray/img_gray_sobel.jpeg');