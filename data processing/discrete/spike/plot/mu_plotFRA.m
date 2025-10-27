function varargout = mu_plotFRA(trialAll, window, clus, windowOnset)
% trialAll(i).spike should be a vector
% Unit: ms

narginchk(1, 4);

if nargin < 2
    window = [0, 300]; % ms
end

if nargin < 3
    clus = [];
end

if nargin < 4
    windowOnset = [0, 150]; % ms
end

trialAll = mu_selectSpikes(trialAll, clus, false);
freq = unique([trialAll.freq])';
att = unique([trialAll.att])';
intensity = max(att) - att;
nfreq = numel(freq);
nintensity = numel(intensity);
ntrial = ceil(numel(trialAll) / nfreq / nintensity);

fr = nan(nintensity, nfreq);
[X, Y] = deal(cell(nintensity, nfreq));
[SpikeTimeCell, TrialNumCell, FreqCell, IntCell] = deal(cell(nintensity, nfreq));

for fIndex = 1:numel(freq)
    for aIndex = 1:numel(att)
        idx = [trialAll.freq] == freq(fIndex) & [trialAll.att] == att(aIndex);
        temp = cell(ntrial, 1);
        temp(1:sum(idx)) = {trialAll(idx).spike};

        % Firing rate
        spikes = cat(1, temp{:});
        spikes = spikes(spikes >= windowOnset(1) & spikes <= windowOnset(2));
        fr(aIndex, fIndex) = numel(spikes) / diff(windowOnset) * 1000 / sum(idx); % Hz
        if sum(idx) < ntrial
            warning('Trial miss: frequency-%g  intensity-%g', freq(fIndex), intensity(aIndex));
            temp(sum(idx) + 1:end) = {nan};
        end

        % Concatenation
        X{aIndex, fIndex} = cellfun(@(x) x + (fIndex - 1) * diff(window), temp, "UniformOutput", false);
        X{aIndex, fIndex} = [{nan}; X{aIndex, fIndex}; {nan}];
        Y{aIndex, fIndex} = mu.rowfun(@(x, y) ones(numel(x{1}), 1) * y, X{aIndex, fIndex}, [nan, 1:ntrial, nan]' + (nintensity - aIndex) * (ntrial + 0.5), "UniformOutput", false);
        
        % For data tip
        SpikeTimeCell{aIndex, fIndex} = [{nan}; temp; {nan}];
        TrialNumCell{aIndex, fIndex} = mu.rowfun(@(x, y) ones(numel(x{1}), 1) * y, SpikeTimeCell{aIndex, fIndex}, [nan, 1:ntrial, nan]', "UniformOutput", false);
        FreqCell{aIndex, fIndex} = cellfun(@(x) ones(numel(x), 1) * freq(fIndex), X{aIndex, fIndex}, "UniformOutput", false);
        IntCell{aIndex, fIndex} = cellfun(@(x) ones(numel(x), 1) * intensity(aIndex), X{aIndex, fIndex}, "UniformOutput", false);
    end
end

X = cat(1, X{:});
Y = cat(1, Y{:});
idxEmpty = cellfun(@isempty, X);
[X{idxEmpty}] = deal(nan);
[Y{idxEmpty}] = deal(nan);
X = cat(1, X{:});
Y = cat(1, Y{:});

SpikeTimeCell = cat(1, SpikeTimeCell{:});
TrialNumCell  = cat(1, TrialNumCell{:});
FreqCell      = cat(1, FreqCell{:});
IntCell       = cat(1, IntCell{:});
[SpikeTimeCell{idxEmpty}] = deal(nan);
[TrialNumCell{idxEmpty}]  = deal(nan);
[FreqCell{idxEmpty}]      = deal(nan);
[IntCell{idxEmpty}]       = deal(nan);
SpikeTime = cat(1, SpikeTimeCell{:});
TrialNum  = cat(1, TrialNumCell{:});
FreqVal   = cat(1, FreqCell{:});
IntVal    = cat(1, IntCell{:});

Fig = figure("WindowState", "maximized");
% Rasterplot
ax1 = mu.subplot(Fig, 1, 1, 1, [1, 0.48], ...
                "paddings", [0.04, 0.06, 0.02, 0.08], ...
                "alignment_vertical", "top", "margins", zeros(1, 4));
S = scatter(X, Y, 10, "red", "filled");
S.UserData = struct('Freq', FreqVal, 'Int', IntVal, 'Trial', TrialNum, 'Time', SpikeTime);
xline((1:nfreq - 1) * window(2), "Color", [0, 0, 0], "LineWidth", 1);
yline((1:nintensity - 1) * (ntrial + 0.5) + 0.25, "Color", [0, 0, 0], "LineWidth", 1);
xlim([window(1), nfreq * diff(window)]);
ylim([0, (ntrial + 0.5) * nintensity + 0.5]);
xticks(window);
yticks((0.5:nintensity - 0.5) * (ntrial + 0.5));
yticklabels(compose('%d', att));
text(window(1) + (0.5:nfreq - 0.5) * diff(window), ...
     ones(nfreq, 1) * (ntrial + 0.5) * nintensity * 1.04, ...
     compose('%g', freq), ...
     "HorizontalAlignment", "center", ...
     "FontSize", 11);
ylabel('Intensity (dB)');
ax1.Box = "on";
ax1.TickLength = [0, 0];

% Heat map of firing rate
ax2 = mu.subplot(Fig, 1, 1, 1, [1, 0.48], ...
                "paddings", [0.04, 0.06, 0.02, 0.08], ...
                "alignment_vertical", "bottom", "margins", zeros(1, 4));
h = imagesc(ax2, fr);
set(ax2, "XLimitMethod", "tight");
set(ax2, "YLimitMethod", "tight");
colormap(ax2, slanCM('YlOrRd'));
cb = mu.colorbar(ax2, "Location", "eastoutside");
cb.Label.String = 'Firing rate (Hz)';
cb.Label.Rotation = -90;
cb.Label.FontSize = 12;
ax2.TickLength = [0, 0];
set(ax2, "XTickLabels", '');
yticks(ax2, 1:numel(intensity));
yticklabels(ax2, num2str(intensity(:)));
ylabel(ax2, 'Intensity (dB)');
set(h  , 'HitTest', 'off', 'PickableParts', 'none');
set(cb , 'HitTest', 'off');
set(ax2, 'HitTest', 'off');

% Data tip of rasterplot
dcm = datacursormode(Fig);
set(dcm, 'UpdateFcn', @(obj, event) localUpdateFcn(event, S));

% Figure title
mu.addTitle(Fig, mu.ifelse(isempty(clus), 'FRA', @() sprintf('FRA of cluster-%g', clus)));

if nargout == 1
    varargout{1} = Fig;
end

return;
end

%% callback
function txt = localUpdateFcn(event, S)
    idx = event.DataIndex;
    UD  = S.UserData;
    txt = {sprintf('Freq (Hz): %g', UD.Freq(idx))
           sprintf('Int (dB): %g' , UD.Int(idx))
           sprintf('Trial: %g'    , UD.Trial(idx))
           sprintf('Time (ms): %g', UD.Time(idx))};
end
