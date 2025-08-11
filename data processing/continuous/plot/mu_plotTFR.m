function varargout = mu_plotTFR(data, f, windowData, varargin)
% Plot time-frequency response (TFR) for multi-channel data.
%
%--------------------------------------------------------------------------------
% SYNTAX
%--------------------------------------------------------------------------------
%   plotTFA(trialsData, fs, windowData, ...)
%
%   If [data] is [trialsData] ([ntrial x 1] cell with [nch x ntime] data), 
%   perform `cwt` on each trial and average the result. The second input should be 
%   sample rate [fs].
%
%--------------------------------------------------------------------------------
%   plotTFA(chMean, fs, windowData, ...)
%
%   If [data] is an [nch x ntime] matirx, perform `cwt` on the averaged 
%   wave [chMean]. The second input should be sample rate [fs].
%
%--------------------------------------------------------------------------------
%   plotTFA(cwtres, f, windowData, ...)
%
%   If [data] is [cwtres] ([ntrial x nch x nfreq x ntime] complex/real or
%   [nch x nfreq x ntime] real), plot cwt result averaged across trials. 
%   The second inputs should be frequency [f]. The cone of influence [coi] 
%   can be specified using Name-Value parameter 'coi'.
%
%--------------------------------------------------------------------------------
% NAME-VALUE PARAMETERS
%   - 'coi': cone of influence (default='auto', show [coi] when input is
%            [trialsData] or [chMean]. When input is [cwtres], not show)
%
%   - 'fLimits': [fl,fh] that specifies frequency limits to plot. (default=[])
%
%   - 'GridSize': [nrow,ncol] that specifies the subplot grid to plot 
%        (default=mu.autoplotsize(nch)).
%
%   - 'Channels': a vector/2-D matrix that specifies channel numbers to plot.
%        If [Channels] is a vector, it is reshaped to fit [GridSize].
%        If [Channels] is a 2-D matrix, size(Channels) should be equal 
%        to [GridSize] and for subplot to skip, use NAN value.
%        numel(Channels)<prod(GridSize) is okay. The last several subplots
%        are hided. numel(Channels)>prod(GridSize) reports an error.
%
%   - 'margings': [left,right,bottom,top] (default=[.05, .05, .1, .1])
%   - 'paddings': [left,right,bottom,top] (default=[.01, .03, .01, .01])
%        See `mu.subplot` for detail.
% 
%--------------------------------------------------------------------------------
% OUTPUT
%   Figure handle of the TFR plot.
%


mIp = inputParser;
mIp.addRequired("f", @(x) validateattributes(x, 'numeric', {'positive', 'vector'}));
mIp.addRequired("windowData", @(x) validateattributes(x, 'numeric', {'numel', 2, 'increasing'}));
mIp.addParameter("fLimits", [], @(x) validateattributes(x, 'numeric', {'numel', 2, 'positive', 'increasing'}));
mIp.addParameter("coi", 'auto');
mIp.addParameter("GridSize", [], @(x) validateattributes(x, 'numeric', {'numel', 2, 'positive'}));
mIp.addParameter("Channels", [], @(x) validateattributes(x, 'numeric', {'2d'}));
mIp.addParameter("margins", [.05, .05, .1, .1], @(x) validateattributes(x, 'numeric', {'numel', 4}));
mIp.addParameter("paddings", [.01, .03, .01, .01], @(x) validateattributes(x, 'numeric', {'numel', 4}));

mIp.parse(f, windowData, varargin{:});

GridSize = mIp.Results.GridSize;
Channels = mIp.Results.Channels;
coi0 = mIp.Results.coi;
fLimits = mIp.Results.fLimits;
margins = mIp.Results.margins;
paddings = mIp.Results.paddings;

f_c = 0.8125; % morlet wavelet center frequency

% compute TFR
if iscell(data)
    trialsData = data;
    [nch, ntime] = mu.checkdata(trialsData);
    
    % validate input sample rate
    fs = f;
    if ~(isscalar(fs) && fs > 0)
        error("Invalid sample rate input");
    end

    padFlag = false;
    if ~isempty(fLimits)
        [tPad, idx] = max([ntime / fs, 1 / fLimits(1), f_c / fLimits(1)]);
        if idx ~= 1
            padFlag = true;
        end
    end

    if padFlag
        [~, f, coi] = mu.cwt(trialsData{1}(1, :), fs, "mode", "CPU", "tPad", tPad);
        cwtres = mu.cwt(trialsData, fs, 10, "mode", "GPU", "tPad", tPad, "outType", "power");
    else
        [~, f, coi] = mu.cwt(trialsData{1}(1, :), fs, "mode", "CPU");
        cwtres = mu.cwt(trialsData, fs, 10, "mode", "GPU", "outType", "power");
    end

    cwtres = squeeze(mean(cwtres, 1)); % [nch x nfreq x ntime]
else
    switch ndims(data)
        case 2
            % chMean [nch x ntime]
            chMean = data;
            ntime = size(chMean, 2);
            fs = f;

            padFlag = false;
            if ~isempty(fLimits)
                [tPad, idx] = max([ntime / fs, 1 / fLimits(1), f_c / fLimits(1)]);
                if idx ~= 1
                    padFlag = true;
                end
            end

            if padFlag
                [~, f, coi] = mu.cwt(chMean(1, :), fs, "mode", "CPU", "tPad", tPad);
                cwtres = mu.cwt(chMean, fs, 10, "mode", "GPU", "tPad", tPad, "outType", "power");
            else
                [~, f, coi] = mu.cwt(chMean(1, :), fs, "mode", "CPU");
                cwtres = mu.cwt(chMean, fs, 10, "mode", "GPU", "outType", "power");
            end

            cwtres = squeeze(mean(cwtres, 1)); % [nch x nfreq x ntime]
            [nch, nfreq, ntime] = size(cwtres);
        case 3
            % cwtres [nch x nfreq x ntime]
            cwtres = data;
            [nch, nfreq, ntime] = size(cwtres);

        case 4
            % cwtres [ntrial x nch x nfreq x ntime]
            cwtres = squeeze(mean(abs(data), 1)); % [nch x nfreq x ntime]
            [nch, nfreq, ntime] = size(cwtres);

        otherwise
            error("Unsupported data dimensions");
    end

    validateattributes(f, 'numeric', {'vector', 'positive', 'numel', nfreq});
    if ismatrix(data) % chMean
        if isempty(coi0)
            coi = [];
        elseif ~strcmpi(coi0, 'auto')
            warning("Ignore user-specified [coi].");
        end
    else % cwtres
        if strcmpi(coi0, 'auto') || isempty(coi0)
            coi = [];
        else
            coi = coi0;
            validateattributes(coi, 'numeric', {'vector', 'numel', ntime});
        end
    end
end
t = linspace(windowData(1), windowData(2), ntime);

% grid size and channel map
if isempty(GridSize)
    GridSize = mu.autoplotsize(nch);
end
if isempty(Channels)
    Channels = reshape(1:prod(GridSize), flip(GridSize))';
else
    if isvector(Channels)
        assert(numel(Channels) <= prod(GridSize), "The number of channels should not exceed grid size");
        Channels = [Channels(:); nan(prod(GridSize) - numel(Channels), 1)];
    else % matrix
        assert(isequal(size(Channels), GridSize), "Size of Channels should be equal to GridSize");
        Channels = Channels';
    end
end
Channels = Channels(:);
Channels(Channels > nch) = nan;

% plot
Fig = figure("WindowState", "maximized");
for rIndex = 1:GridSize(1)

    for cIndex = 1:GridSize(2)
        ch = Channels((rIndex - 1) * GridSize(2) + cIndex);

        if isnan(ch)
            continue;
        end

        ax = mu.subplot(Fig, GridSize(1), GridSize(2), (rIndex - 1) * GridSize(2) + cIndex, ...
                        "margins", margins, "paddings", paddings);
        imagesc(ax, "XData", t, ...
                    "YData", f, ...
                    "CData", squeeze(cwtres(ch, :, :)));

        title(ax, ['CH ', num2str(ch)]);
        xlim(ax, windowData);
        set(ax, "YScale", "log");
        set(ax, "YLimitMethod", "tight");
        yticks(ax, [0, 2.^(-1:nextpow2(max(f)) - 1)]);

        if ~mod(((rIndex - 1) * GridSize(2) + cIndex - 1), GridSize(2)) == 0
            yticklabels(ax, '');
        end

        if (rIndex - 1) * GridSize(2) + cIndex < (GridSize(1) - 1) * GridSize(2) + 1
            xticklabels(ax, '');
        end

    end
end

colorbar('position', [1 - paddings(2) * 1.2, 0.1, 0.01, 0.8]);
mu.scaleAxes(Fig, "c");

if ~isempty(coi)
    mu.addLines(struct("X", t, "Y", coi, "color", "w", "style", "--", "width", 0.6));
end

if nargout == 1
    varargout{1} = Fig;
end

return;
end
