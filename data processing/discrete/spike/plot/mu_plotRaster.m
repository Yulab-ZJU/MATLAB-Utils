function varargout = mu_plotRaster(opts)
% All unit in ms

%% Params parse
arguments
    opts.data               (1,1) struct = struct([])
    opts.window             (1,2) double = [-100, 500] % ms
    opts.trialAll           (:,1) = []
    opts.clus               (1,1) double {mustBeInteger} = -1 % -1 for all
    opts.TrigField          {mustBeTextScalar} = "Swep"
    opts.rasterSize         (1,1) double {mustBePositive}  = 20
    opts.psthParams         (1,:) cell = {"Color", "k", "LineWidth", 2}
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

    assert(isfield(opts.data.epocs, opts.TrigField), "[%s] is not a field of [epocs]", opts.TrigField);
    evt = [opts.data.epocs.(opts.TrigField).onset] * 1e3; % ms
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
axRaster = mu.subplot(Fig, 1, 1, 1, [1/2, 2/3], "alignment", "center-top");
rasterData.X = spikesByTrial;
mu.rasterplot(axRaster, rasterData, opts.rasterSize);
ylim(axRaster, [0, numel(rasterData.X) + 1]);
xticklabels(axRaster, '');
yticklabels(axRaster, '');

axPSTH = mu.subplot(Fig, 1, 1, 1, [1/2, 1/3], "alignment", "center-bottom");
[psth, edges] = mu_calPSTH(spikesByTrial, opts.window, 10, 5);
plot(axPSTH, edges, psth, opts.psthParams{:});
xlabel(axPSTH, "Time (ms)");
ylabel(axPSTH, "Firing rate (Hz)");

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
    title(axRaster, titleStr);
else
    if opts.clus ~= -1
        titleStr = sprintf('Cluster %d | No significant onset response found', opts.clus);
    else
        titleStr = 'No significant onset response found';
    end
    title(axRaster, titleStr);
end

if nargout == 1
    varargout{1} = Fig;
elseif nargout == 2
    varargout{2} = axRaster;
elseif nargout == 3
    varargout{3} = axPSTH;
end

return;
end