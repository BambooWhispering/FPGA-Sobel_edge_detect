% ��ֵ�˲�

close;
clear;
clc;

% ��ȡԭʼ�Ҷ�ͼƬ����������
img = imread('./img_src/img_gray.jpeg'); 

% 3*3�ĺ˽���Sobel��Ե���󣬴��������
txt_sobel = edge(img, 'sobel'); % ��ԭʼ�ҶȾ������3*3�˵ľ�ֵ�˲���������������

% ����תΪͼƬ
imwrite(txt_sobel, './img_dst_gray/img_gray_sobel.jpeg');