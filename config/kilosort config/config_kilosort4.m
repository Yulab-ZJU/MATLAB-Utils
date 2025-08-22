function [settings, opts] = config_kilosort4(varargin)
% Configuration of kilosort4
% Items marked with (*) are a must.

for index = 1:2:nargin
    args.(varargin{index}) = varargin{index + 1};
end

%% Python setup
[status, cmdout] = system('conda run -n kilosort where python');
if status == 0
    temp = regexp(cmdout, '\n', 'split');
    if any(contains(temp, 'kilosort'))
        envPythonLine = temp(contains(temp, 'kilosort'));
        settings.pythonExe = strtrim(envPythonLine{1});
    else
        error("Kilosort env not found.");
    end
else
    error("Unable to get python.exe paths.");
end

%% settings
% See ~\resources\parameters.py for a full list of parameters
%%% Main parameters %%%
% number of channels, must be specified here (*)
settings.n_chan_bin = mu.getor(args, "n_chan_bin");

% sample rate, Hz (*)
settings.fs = mu.getor(args, "fs");

% Number of samples included in each batch of data
settings.batch_size = mu.getor(args, "batch_size", 6e4);

% Number of non-overlapping blocks for drift correction 
% Additional nblocks-1 blocks are created in the overlaps
settings.nblocks = mu.getor(args, "nblocks", 1);

% Spike detection threshold for universal templates
% Th(1) in previous versions of Kilosort
settings.Th_universal = mu.getor(args, "Th_universal", 9);

% Spike detection threshold for learned templates
% Th(2) in previous versions of Kilosort
settings.Th_learned = mu.getor(args, "Th_learned", 8);

% settings.tmin = 0;
% settings.tmax = inf;

%%% Extra parameters %%%
% Number of samples per waveform. Also size of symmetric padding for filtering
settings.nt = mu.getor(args, "nt", 61);

%% options
% Full path of probe file (*)
opts.probe_name = mu.getor(args, "probe_name");

% Full path of binary data file (*)
opts.filename = mu.getor(args, "filename");

% Directory where results will be stored
% By default, will be set to [data_dir]/'kilosort4'
opts.results_dir = mu.getor(args, "results_dir", fullfile(fileparts(mu.getabspath(opts.filename)), 'kilosort4'));

% dtype of data in binary file (*)
% By default, dtype is assumed to be 'int16'
opts.data_dtype = mu.getor(args, "data_dtype", 'int16');

% If True, save a pre-processed copy of the data (including drift
% correction) to `temp_wh.dat` in the results directory and format Phy
% output to use that copy of the data.
opts.save_preprocessed_copy = mu.getor(args, "save_preprocessed_copy", false);

% A list of channel indices (rows in the binary file) that should not be
% included in sorting. Listing channels here is equivalent to excluding
% them from the probe dictionary.
opts.bad_channels = mu.getor(args, "bad_channels");

return;