function varargout = mu_plotRaster(opts)
% All unit in ms

%% Params parse
arguments
    opts.data               (1,1) struct
    opts.trialAll           (:,1) = []

    opts.window             (1,2) double = [-100, 500] % ms
    
    opts.clus               (1,1) double {mustBeInteger} = -1 % -1 for all

    opts.TrigField          {mustBeTextScalar} = "Swep" % evt=epocs.(TrigField).onset*1e3
    opts.filter             = [] % e.g., "epocs.ordr.data==1" or a logical array
    opts.evt                = [] % event time array in ms, first priority

    opts.rasterSize         (1,1) double {mustBePositive}  = 20
    opts.psthParams         (1,:) cell = {"Color", "k", "LineWidth", 2}
    opts.psthBinSize        (1,1) double = 10 % ms
    opts.psthStep           (1,1) double = 5  % ms

    opts.latency            (1,1) logical = true
    opts.latencyWindowBase  (1,2) double = [-100, 0] % ms
    opts.latencyWindowOnset (1,2) double = [0, 300]  % ms
end
validateattributes(opts.window, 'numeric', {'increasing'});
validateattributes(opts.latencyWindowBase, 'numeric', {'increasing'});
validateattributes(opts.latencyWindowOnset, 'numeric', {'increasing'});

if ~isempty(opts.trialAll)
    if isstruct(opts.trialAll)
        assert(isfield(opts.trialAll, "spike"), "[trialAll] should contain field [spike]");
        spikesByTrial = {opts.trialAll.spike}';
    elseif iscell(opts.trialAll)
        sz = cellfun(@(x) size(x, 2), opts.trialAll);
        assert(all(sz == sz(1)), "Invalid [spike] trial data. Dimension differs.");
        spikesByTrial = opts.trialAll;
    end
elseif ~isempty(opts.data)
    assert(isfield(opts.data, "epocs"), "[data] should contain field [epocs]");
    assert(isfield(opts.data, "sortdata"), "[data] should contain field [sortdata]");
    sortdata = opts.data.sortdata;
    sortdata(:, 1) = sortdata(:, 1) * 1e3; % ms

    if isempty(opts.evt)
        assert(isfield(opts.data.epocs, opts.TrigField), "[%s] is not a field of [epocs]", opts.TrigField);
        evt = opts.data.epocs.(opts.TrigField).onset * 1e3; % ms
    else
        evt = opts.evt;
    end
    validateattributes(evt, 'numeric', {'vector', 'increasing'});
    if ~isempty(opts.filter)
        if mu.isTextScalar(opts.filter)
            filt = eval(strcat("opts.data.", opts.filter));
        else
            filt = opts.filter;
        end
        validateattributes(filt, 'logical', {'vector', 'numel', numel(evt)});
        evt = evt(filt);
    end
    spikesByTrial = mu_selectSpikes(sortdata, evt, opts.window, [], true);
else
    error("No sort data or spike data provided!");
end

if opts.clus == -1
    spikesByTrial = mu_selectSpikes(spikesByTrial, [], false);
else
    spikesByTrial = mu_selectSpikes(spikesByTrial, opts.clus, false);
end

%% Plot
Fig = figure;
tl = mu.tiledlayout(Fig, 3, 1, ...
    "nSize", [0.5, 1], ...
    "margins", [0, 0, 0.05, 0.05], ...
    "TileSpacing", "none");
axRaster = mu.subplot(tl, [1, 1, 2, 1]);
rasterData.X = spikesByTrial;
mu.rasterplot(axRaster, rasterData, opts.rasterSize);
ylim(axRaster, [0, numel(rasterData.X) + 1]);
xticklabels(axRaster, '');
yticklabels(axRaster, '');

axPSTH = mu.subplot(tl, [3, 1, 1, 1]);
[psth, edges] = mu_calPSTH(spikesByTrial, opts.window, opts.psthBinSize, opts.psthStep);
plot(axPSTH, edges, psth, opts.psthParams{:});
ylabel(axPSTH, "Firing rate (Hz)");
xlabel(tl, "Time (ms)");

mu.scaleAxes(Fig, "x", opts.window);

if opts.latency
    latency = mu_calLatency(spikesByTrial, opts.latencyWindowOnset, opts.latencyWindowBase);
else
    latency = [];
end

if ~isempty(latency)
    mu.addLines(Fig, struct("X", latency, "color", "r"));
    if opts.clus ~= -1
        titleStr = sprintf('Cluster %d | Latency for onset response: %.2f ms', opts.clus, latency);
    else
        titleStr = sprintf('Latency for onset response: %.2f ms', latency);
    end
else
    if opts.latency
        if opts.clus ~= -1
            titleStr = sprintf('Cluster %d | No significant onset response found', opts.clus);
        else
            titleStr = 'No significant onset response found';
        end
    else
        if opts.clus ~= -1
            titleStr = sprintf('Cluster %d', opts.clus);
        else
            titleStr = '';
        end
    end
end
title(tl, titleStr);

if nargout == 1
    varargout{1} = tl;
end

return;
end