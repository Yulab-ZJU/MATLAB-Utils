function [trialsEEG, trialAll, fs, varargout] = mu_preprocess_Neuracle(ROOTPATH, opts)
narginchk(1, 2);

if nargin < 2
    opts = [];
end

%% Parameter settings
opts = mu.getorfull(opts, mu_preprocess_configEEG);
window = opts.window; % variable name conflicts with built-in function
mu.parsestruct(opts);

%% Data loading
% convert ROOTPATH to char
ROOTPATH = char(ROOTPATH);
if ~strcmp(ROOTPATH(end), '\')
    ROOTPATH = [ROOTPATH, '\'];
end

% read from BDF data
EEG = readbdfdata({'data.bdf', 'evt.bdf'}, ROOTPATH);
if exist(fullfile(ROOTPATH, 'data.1.bdf'), 'file')
    EEG1 = readbdfdata({'data.1.bdf'}, ROOTPATH);
    EEG.data = [EEG.data, EEG1.data];
end

% read motion signal from edf data
if opts.load_speed && exist(fullfile(ROOTPATH, 'mems.edf'), "file")
    motiondata = readedf(fullfile(ROOTPATH, 'mems.edf')); % a(t)
    sensor = 2; % which sensor to use, 1 for left/right, 2 for up/down, 3 for forward/backward
    speed = cumsum(motiondata(sensor, :)) * 1/fsSensor; % v(t)
    speed = mu.filter(speed, fsSensor, "fhp", 0.5, "flp", 2);
    varargout{2} = speed;
else
    disp("No mem.edf found.");
    varargout{2} = [];
end

% load MAT data
temp = dir(fullfile(ROOTPATH, '*.mat'));
if numel(temp) > 1
    error("More than 1 MAT data found in your directory.");
elseif isempty(temp)
    warning("No MAT data found in your directory. Proceed without MAT data.");
else
    load(fullfile(temp.folder, temp.name), "rules", "trialsData");
    if ~exist("rules", "var") || ~exist("trialsData", "var")
        error("MAT data not matched. Related MAT data is missing.");
    end
end

%% Preprocess
codes = arrayfun(@(x) str2double(x.type), EEG.event); % marker
latency = [EEG.event.latency]'; % unit: sample
fs = EEG.srate; % Hz
if exist("trialsData", "var")
    trialAll = opts.behaviorProcessFcn(trialsData, rules);
end

% exclude accidental codes
if exist("rules", "var")
    exIdx = isnan(codes) | ~ismember(codes, rules.code) | latency > size(EEG.data, 2) - fix(window(2) / 1000 * fs);
    latency(exIdx) = [];
end
latency = latency(find(arrayfun(@(x) str2double(x.type), EEG.event) == 1, 1):end);

% filter
EEG.data = mu.filter(EEG.data, fs, "fhp", fhp, "flp", flp, "fnotch", 50);

% epoching
trialsEEG = mu_selectWave(EEG.data, fs, latency / fs * 1e3, window);

% ICA
if strcmpi(icaOpt, "on") && nargout >= 4
    if ~isempty(ICAPATH) && exist(fullfile(ICAPATH, "ICA res.mat"), "file")
        load(fullfile(ICAPATH, "ICA res.mat"), "-mat", "comp");
        channels = comp.channels;
        ICs = comp.ICs;
        badChs = comp.badChs;

        % Re-reference
        if strcmpi(opts.reref, "CAR")
            trialsEEG = cellfun(@(x) x - mean(x(channels, :), 1), trialsEEG, "UniformOutput", false);
        end

    else
        disp('ICA result does not exist. Performing ICA on data...');
        channels = 1:size(trialsEEG{1}, 1);
        mu_plotWaveArray(struct("chMean", mu.calchMean(trialsEEG), "chErr", mu.calchStd(trialsEEG)), window);
        mu.scaleAxes("y", [-20,20], "symOpts", "max");
        bc = validateinput(['Input extra bad channels (besides ', num2str(badChs(:)'), '): '], @(x) isempty(x) || all(fix(x) == x & x > 0));
        badChs = [badChs(:); bc(:)]';

        % first trial exclusion
        tIdx = mu_excludeTrials(trialsEEG, 0.4, 20, "userDefineOpt", "off", "badCHs", badChs);
        trialsEEG(tIdx) = [];
        latency(tIdx) = [];

        if exist("trialAll", "var")
            trialAll(tIdx) = [];
        end

        if ~isempty(badChs)
            disp(['Channel ', num2str(badChs(:)'), ' are excluded from analysis.']);
            channels(badChs) = [];
        end

        % Re-reference
        if strcmpi(opts.reref, "CAR")
            trialsEEG = cellfun(@(x) x - mean(x(channels, :), 1), trialsEEG, "UniformOutput", false);
        end
        
        if isempty(nMaxIcaTrial)
            idx = 1:length(trialsEEG);
        else
            idx = 1:length(trialsEEG);
            idx = idx(randperm(length(trialsEEG), min(length(trialsEEG), nMaxIcaTrial)));
        end
        
        [comp, ICs] = mu_ica(trialsEEG(idx), window, fs, EEGPos, "chs2doICA", channels);
    end
    
    % reconstruct data
    trialsEEG = cellfun(@(x) x(channels, :), trialsEEG, "UniformOutput", false);
    trialsEEG = mu_ica_reconstructData(trialsEEG, comp, ICs);
    trialsEEG = cellfun(@(x) mu.insertrows(x, badChs), trialsEEG, "UniformOutput", false);
    trialsEEG = mu_interpolateBadChannels(trialsEEG, badChs, EEGPos.neighbours);

    comp.channels = channels;
    comp.ICs = ICs;
    comp.badChs = sort(badChs, "ascend");

    varargout{1} = comp;
end

% baseline correction
trialsEEG = mu_baselineCorrectionEEG(trialsEEG, fs, window, windowBase);

% exclude bad trials
params = {trialsEEG, tTh, chTh};
if ~isempty(absTh)
    params = [params, {"absTh", absTh}];
end
if ~isempty(badChs)
    params = [params, {"badCHs", badChs}];
end
exIdx = mu_excludeTrials(params{:});
trialsEEG(exIdx) = [];
latency(exIdx) = [];

if exist("trialAll", "var")
    trialAll(exIdx) = [];
else
    trialAll = struct("trialNum", num2cell((1:length(trialsEEG))'));
end

% convert latency to time, unit: sec
latency = latency / fs;
trialAll = mu.addfield(trialAll, "latency", latency);

return;
end