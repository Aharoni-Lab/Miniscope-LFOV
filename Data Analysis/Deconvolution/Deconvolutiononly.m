clear all;
close all;
clc;
addpath('E:\Wirefree_Data\Deconvolution_Compare\CNMF_E-master\OASIS_matlab\','-begin');
addpath('E:\Wirefree_Data\Deconvolution_Compare\CNMF_E-master\OASIS_matlab\functions\','-begin');
addpath('E:\Wirefree_Data\Deconvolution_Compare\CNMF_E-master\OASIS_matlab\packages\constrained-foopsi\','-begin');


Folder1      = 'E:\Wirefree_Data\Deconvolution_Compare\';
load([Folder1 'A_neuron_good_idx.mat']);
Cell_idx     = foo;
% load([Folder1 'memmap__d1_550_d2_608_d3_1_order_C_frames_13085_C_trace.mat']);
% C_Raw_d      = foo;
% C_Raw_g_d    = C_Raw_d(Cell_idx+1,:);

load([Folder1 'C_Raw_good.mat']);
% C_Raw      = C_Raw_g;
% C_Raw_g    = C_Raw(Cell_idx+1,:);


d1           = designfilt('lowpassfir','PassbandFrequency',0.3,'StopbandFrequency',0.4);

% bpFilt       = designfilt('bandpassfir','FilterOrder',20, ...
%               'CutoffFrequency1',1,'CutoffFrequency2',300, ...
%               'SampleRate',1500);
% fvtool(bpFilt)
parfor cellno         = 1:size(C_Raw_g,1)   
C_Raw_g_temp          = C_Raw_g(cellno,:);
C_Raw_g(cellno,:)     = C_Raw_g_temp;
C_Raw_g_flt(cellno,:) = filtfilt(d1,C_Raw_g(cellno,:));
end
dt_m                  = 0.069;
figure(100);
yshift=1;
for cellno            = 1:100  

        C_raw_fn  = C_Raw_g_flt(cellno,:);
        C_rawn    = C_Raw_g(cellno,:);
%         C_rawn_d  = C_Raw_g_d(cellno,:);      
        
        Max       = max([max(C_raw_fn(:)),max(C_rawn(:))]);
        C_raw_fn  = C_raw_fn/Max;        
        C_rawn    = C_rawn/Max;    
%         C_rawn_d  = C_rawn_d/Max;   
%         plot(C_rawn_d(1:1:size(C_rawn,2))+(cellno-1)*yshift,'g','LineWidth',0.2);
%         hold on;
        plot(C_rawn(1:1:size(C_rawn,2))+(cellno-1)*yshift,'Color',[100/255 100/255 100/255]);
        hold on;
        plot(C_raw_fn(1:1:size(C_rawn,2))+(cellno-1)*yshift,'r','LineWidth',0.2);
        axis tight

        xlim([1 size(C_rawn,2)])
        xticks(1:1*1000:size(C_rawn,2))
        xticklabels( string(dt_m*1:dt_m*1000:dt_m*size(C_rawn,2)) )
        hold on;
        
    end
 

C_Raw_g_flt_good  = C_Raw_g_flt;
tau_dr            = [15,0.5];
window            = 200;
ht                = exp2kernel(tau_dr, window);
figure(1)
plot(ht)
lambda           = 2;
parfor segs    = 1:size(C_Raw_g_flt_good,1)
[c_Dnl, s_Dnl, options]= deconvolveCa(C_Raw_g_flt_good(segs,:), 'exp2', tau_dr, 'foopsi','optimize_pars',false,'optimize_b',true,'lambda',lambda,'maxIter',5,'window',300,'shift',100)
c_2d(segs,:)   = c_Dnl;
s_2d(segs,:)   = s_Dnl;
options_cells(segs,:) = options;
segs
end