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
    motiondata = readedf(fullfile(ROOTPATH, 'mems.edf'));
    
    
    
    % a(t)
    sensor = 1:3; % which sensor to use, 1 for left/right, 2 for up/down, 3 for forward/backward
    varargout{2} = motiondata(sensor, :);
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

if exist("trialsData", "var") && exist("rules", "var")
    trialAll = opts.behaviorProcessFcn(trialsData, rules);

    % start from the first 1
    if codes(1) ~= 1
        warning("Head information lost. Code should start with 1.");
    end
    % assert(codes(1) == 1, "Head information lost. Code should start with 1.");
    
    % exclude non-stimulus/cue codes
    exIdx = ismember(codes, [1; 2; 3]) | isnan(codes) | ~ismember(codes, rules.code) | latency > size(EEG.data, 2) - fix(window(2) / 1000 * fs);
    codes(exIdx) = [];
    latency(exIdx) = [];

    % For EEG-App latest version
    if isfield(trialAll, "events")
        % validate
        temp = arrayfun(@(x) [x.events(ismember([x.events.type], ["stimuli", "cue"])).code]', trialAll, "UniformOutput", false);
        temp = cat(1, temp{:}); % full record
        assert(mu.findvectorloc(temp, codes, "first") == 1, "Missing codes in EEG recording! Please check data manually.");
    
        % find first stimulus/cue code in each trial
        ncode = arrayfun(@(x) sum(ismember([x.events.type], ["stimuli", "cue"])), trialAll);
        assert(all(ncode == ncode(1)), "Inconsistent trial information.");
        ncode = ncode(1); % total number of stimuli/cue per trial
        ntrial = floor(numel(codes) / ncode); % in case of incomplete trial presented at last
        ntrial0 = numel(trialAll);
        trialAll = trialAll(1:ntrial);
        latency = latency(1:ncode:ncode * ntrial);

        fprintf("\nValid trials: %d/%d.\n\n", ntrial, ntrial0);
    end
else
    trialAll = [];
end

% filter
EEG.data = mu.filter(EEG.data, fs, "fhp", fhp, "flp", flp, "fnotch", 50);

% epoching
fprintf("\nEpoching aligned to the first stimulus/cue onset of each trial.\n");
trialsEEG = mu_selectWave(EEG.data, fs, latency / fs * 1e3, window);

% ICA
if mu.OptionState.create(opts.icaOpt).toLogical && nargout >= 4
    if ~isempty(ICAPATH) && exist(fullfile(ICAPATH, "ICA res.mat"), "file")
        fprintf("\nReconstructing data using existed ICA result...\n\n");
        load(fullfile(ICAPATH, "ICA res.mat"), "-mat", "comp");
        channels = comp.channels;
        ICs = comp.ICs;
        badChs = comp.badChs;

        % Re-reference
        if strcmpi(opts.reref, "CAR")
            fprintf("\nRe-referencing with CAR...\n\n");
            trialsEEG = cellfun(@(x) x - mean(x(channels, :), 1), trialsEEG, "UniformOutput", false);
        end

    else
        fprintf("\nICA result does not exist. Performing ICA on data...\n\n");
        channels = 1:size(trialsEEG{1}, 1);
        Fig = mu_plotWaveArray(struct("chMean", mu.calchMean(trialsEEG), "chErr", mu.calchStd(trialsEEG)), window);
        mu.addTitle(Fig, "Original");
        mu.scaleAxes(Fig, "y", [-20, 20], "symOpts", "max");
        bc = validateinput(sprintf('Input extra bad channels (besides [%s]): ', strjoin(string(badChs), ', ')), ...
                           @(x) isempty(x) || all(fix(x) == x & x > 0));
        badChs = [badChs(:); bc(:)]';
        if isvalid(Fig)
            close(Fig);
        end

        % first trial exclusion
        tIdx = mu_excludeTrials(trialsEEG, 0.4, 20, "userDefineOpt", "off", "badCHs", badChs);
        trialsEEG(tIdx) = [];
        latency(tIdx) = [];
        if ~isempty(trialAll)
            trialAll(tIdx) = [];
        end

        if ~isempty(badChs)
            fprintf('Channels %s are excluded from analysis.\n', strjoin(string(badChs), ', '));
            channels(badChs) = [];
        end

        % Re-reference
        if strcmpi(opts.reref, "CAR")
            fprintf("\nRe-referencing with CAR...\n\n");
            trialsEEG = cellfun(@(x) x - mean(x(channels, :), 1), trialsEEG, "UniformOutput", false);
        end
        
        if isempty(nMaxIcaTrial)
            idx = 1:numel(trialsEEG);
        else
            idx = 1:numel(trialsEEG);
            idx = idx(randperm(numel(trialsEEG), min(numel(trialsEEG), nMaxIcaTrial)));
        end
        
        fprintf("\nThe total number of trials included in ICA is %d.\n\n", numel(idx));
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
if ~isempty(trialAll)
    trialAll(exIdx) = [];
else
    trialAll = struct("trialNum", num2cell((1:numel(trialsEEG))'));
end

% convert latency to time, unit: sec
latency = latency / fs;
trialAll = mu.addfield(trialAll, "latency", latency);

return;
end