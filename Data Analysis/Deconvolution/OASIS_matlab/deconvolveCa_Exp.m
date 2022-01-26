function [c, s, options] = deconvolveCa_Exp(y, RiseDecay, varargin)
%% infer the most likely discretized spike train underlying an fluorescence trace
%% Solves mutliple formulation of the problem
%  1) FOOPSI,
%       mininize_{c,s} 1/2 * norm(y-c,2)^2 + lambda * norm(s,1)
%       subject to  c>=0, s>=0, s=Gc
%  2) constrained FOOPSI
%       minimize_{c,s} norm(s, q)
%       subject to  norm(y-c,2) <= sn*sqrt(T), c>=0, s>=0, s=Gc
%       where q is either 1 or 0, rendering the problem convex or non-convex.
%  3) hard threshrinkage
%       minimize_{c,s} 1/2 * norm(y-c, 2)^2
%       subjec to c>=0, s=Gc, s=0 or s>=smin
%  4) Nonnegative least square problem (NNLS)
%       min_{s} norm(y - s*h, 2)^2 + lambda * norm(s,1)
%       subject to s>=0

%% inputs:
%   y: T x 1 vector, fluorescence trace
%   varargin: variable input arguments
%       type: string, defines the model of the deconvolution kernel. possible
%           options are:
%           'ar1':  auto-regressive model with order p=1
%           'ar2':  auto-regressive model with order p=2
%           'exp2': the convolution kernel is modeled as the difference of two
%               exponential functions -
%               h(t) = (exp(-t/tau_d) - exp(-t/tau_r)) / (tau_d-tau_r)
%           'kernel':   a vector of the convolution kernel
%       pars: parameters for the specified convolution kernel. it has
%           different shapes for differrent types of the convolution model:
%           'ar1':  scalar
%           'ar2':  2 x 1 vector, [r_1, r_2]
%           'exp2': 2 x 1 vector, [tau_r, tau_d]
%           'kernel': maxISI x 1 vector, the kernel.
%       sn:  scalar, standard deviation of the noise distribution. If no
%           values is give, then sn is estimated from the data based on power
%           spectual density method.
%       b:  fluorescence baseline vlaues. default is 0
%       optimize_pars:  estimate the parameters of the convolution kernel. default: 0
%       optimize_b:     estimate the baseline. default: 0
%       lambda:     penalty parameter
%       method: methods for running deconvolution. {'foopsi',
%       'constrained_foopsi' (default), 'thresholded'},

%% outputs:
%   c: T x 1 vector, denoised trace
%   s: T x 1 vector, deconvolved signal
%   b: fluorescence baseline
%   kernel: struct variable containing the parameters for the selected
%       convolution model
%   lambda: Optimal Lagrange multiplier for noise constraint under L1 penalty
%     """olves the noise constrained sparse nonnegat

%% Authors: Pengcheng Zhou, Carnegie Mellon University, 2016
% ported from the Python implementation from Johannes Friedrich

%% References
% Friedrich J et.al., NIPS 2016, Fast Active Set Method for Online Spike Inference from Calcium Imaging

%% input arguments
y = reshape(y, [], 1);  % reshape the trace as a vector
options = parseinputs(varargin{:});     % parse input arguments
if isempty(y)
    c = []; s = [];
    return;
end
win = options.window;   % length of the convolution kernel
% estimate the noise
if isempty(options.sn)
    options.sn = GetSn(y);
end
% estimate time constant
if isempty(options.pars) || all(options.pars==0)
    switch options.type
        case 'exp2'
            g = estimate_time_constant(y, 2, options.sn);
            % changed by changliang guo
            options.pars = RiseDecay;    
            % changed by changliang guo
    end
end

%% run deconvolution
c = y;
s = y;
switch lower(options.method)
    case 'foopsi'  %% use FOOPSI
        if strcmpi(options.type, 'exp2')   % difference of two exponential functions
            kernel = exp2kernel(options.pars, options.window);
            [c, s] = onnls(y-options.b, kernel, options.lambda, ...
                options.shift, options.window);      
        else
            disp('to be done');
        end 
end

% deal with large residual
if options.remove_large_residuals && strcmpi(options.method, 'foopsi')
    ind = (abs(smooth(y-c, 3))>options.smin);
    c(ind) = max(0, y(ind));
end


function options=parseinputs(varargin)
%% parse input variables

%% default options
options.type = 'ar1';
options.pars = [];
options.sn = [];
options.b = 0;
options.lambda = 0;
options.optimize_b = false;
options.optimize_pars = false;
options.optimize_smin = false;
options.method = 'constrained';
options.window = 200;
options.shift = 100;
options.smin = 0;
options.maxIter = 10;
options.thresh_factor = 1.0;
options.extra_params = [];
options.p_noise = 0.9999; 
options.max_tau = 100; 
options.tau_range = []; 
options.remove_large_residuals = false; 

if isempty(varargin)
    return;
elseif isstruct(varargin{1}) && ~isempty(varargin{1})
    tmp_options = varargin{1};
    field_nams = fieldnames(tmp_options);
    for m=1:length(field_nams)
        eval(sprintf('options.%s=tmp_options.%s;', field_nams{m}, field_nams{m}));
    end
    k = 2;
else
    k = 1;
end
%% parse all input arguments
while k<=nargin
    if isempty(varargin{k})
        k = k+1;
    end
    switch lower(varargin{k})
        case {'ar1', 'ar2', 'exp2', 'kernel'}
            % convolution kernel type
            options.type = lower(varargin{k});
            if (k<nargin) && (isnumeric(varargin{k+1}))
                options.pars = varargin{k+1};
                k = k + 1;
            end
            k = k + 1;
        case 'pars'
            % parameters for the kernel
            options.pars = varargin{k+1};
            k = k+2;
        case 'sn'
            % noise
            options.sn = varargin{k+1};
            k = k+2;
        case 'b'
            % baseline
            options.b = varargin{k+1};
            k = k+2;
        case 'optimize_b'
            % optimize the baseline
            options.optimize_b = true;
            if (k<nargin) && (islogical(varargin{k+1}))
                options.optimize_b = varargin{k+1};
                k = k + 1;
            end
            k = k+1;
        case 'optimize_pars'
            % optimize the parameters of the convolution kernel
            options.optimize_pars = true;
            if (k<nargin) && (islogical(varargin{k+1}))
                options.optimize_pars = varargin{k+1};
                k = k+1;
            end
            k = k + 1;
            
        case 'optimize_smin'
            % optimize the parameters of the convolution kernel
            options.optimize_smin = true;
            if (k<nargin) && (islogical(varargin{k+1}))
                options.optimize_smin = varargin{k+1};
                k = k+1;
            end
            k = k+1;
        case 'lambda'
            % penalty
            options.lambda = varargin{k+1};
            k = k+2;
        case {'foopsi', 'constrained', 'thresholded', 'mcmc'}
            % method for running the deconvolution
            options.method = lower(varargin{k});
            k = k+1;
            if strcmpi(options.method, 'mcmc') && (k<=length(varargin)) && (~ischar(varargin{k}))
                options.extra_params = varargin{k};
                k = k+1;
            end
        case 'window'
            % maximum length of the kernel
            options.window = varargin{k+1};
            k = k+2;
        case 'shift'
            % number of frames by which to shift window from on run of NNLS
            % to the next
            options.shift = varargin{k+1};
            k = k+2;
        case 'smin'
            % number of frames by which to shift window from on run of NNLS
            % to the next
            options.smin = varargin{k+1};
            k = k+2;
        case 'maxiter'
            % number of frames by which to shift window from on run of NNLS
            % to the next
            options.maxIter = varargin{k+1};
            k = k+2;
        case 'thresh_factor'
            % number of frames by which to shift window from on run of NNLS
            % to the next
            options.thresh_factor = varargin{k+1};
            k = k+2;
        case 'p_noise'
            % number of frames by which to shift window from on run of NNLS
            % to the next
            options.p_noise = varargin{k+1};
            k = k+2;
        case 'tau_range'
            options.tau_range = varargin{k+1}; 
            k = k+2; 
        case 'remove_large_residuals'
            % remove large residuals by setting c(t) = y(t) 
            options.remove_large_residuals = true;
            if (k<nargin) && (islogical(varargin{k+1}))
                options.remove_large_residuals = varargin{k+1};
                k = k+1;
            end
            k = k+1;   
        otherwise
            k = k+1;
    end
end

%% correct some wrong inputs
if strcmpi(options.type, 'kernel')
    options.window = numel(options.pars);
end
