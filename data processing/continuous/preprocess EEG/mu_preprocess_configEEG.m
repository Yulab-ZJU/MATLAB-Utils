function opts = mu_preprocess_configEEG(varargin)
% Default parameters for EEG preprocessing.
% You can change parameters with input name-value pairs.
% Copy this file to 'config\local' folder as your local config file.

% skip existed files
opts.skipExisted = true; % set false to re-export data

% EEG pos file
opts.EEGPos = [];

% for behavior process
opts.behaviorProcessFcn = @mu_preprocess_generalProcessFcn;

% for trial segmentation
opts.window = [-1000, 3000]; % ms

% for re-reference
% opts.reref = "CAR"; % common average reference
opts.reref = "none"; % no re-reference

% for baseline correction
opts.windowBase = [-300, 0]; % ms

% for filter
opts.fhp = 0.5; % Hz
opts.flp = 40; % Hz

% for trial exclusion
opts.tTh = 0.2;
opts.chTh = 20;
opts.absTh = [];
opts.badChs = [];

% for ICA
opts.icaOpt = "on";
opts.ICAPATH = []; % If [ICA res.mat] already exists in the SAVEPATH, ICA 
                   % will not be done
opts.nMaxIcaTrial = 100; % If left empty, use all trials
opts.sameICAOpt = "off"; % If set "on", apply the ICA result of one 
                         % protocol to the others for one subject

% for motion sensor
opts.load_speed = true;
opts.fsSensor = 100; % Hz

% for joint processing
opts.sep_save = true; % save as separate mat
opts.joint_save = true; % save as a joint mat

% parse name-value pairs
for index = 1:2:nargin
    opts.(varargin{index}) = varargin{index + 1};
end

return;
end