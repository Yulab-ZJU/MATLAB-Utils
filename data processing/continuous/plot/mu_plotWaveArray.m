function varargout = mu_plotWaveArray(chData, window, opts)
%MU_PLOTWAVEARRAY  Plot multi-group waves for multi-channel data (grid of subplots).
%
% This function is designed for "multi-group" waveforms (e.g., conditions),
% plotted across many channels arranged into a subplot grid.
%
% -------------------------------------------------------------------------
% INPUTS
%   chData : [nGroup x 1] struct array (fieldname is CASE-INSENSITIVE)
%       Required field:
%         - chMean  : [nCh x nSample] mean waveform for each channel
%
%       Optional fields:
%         - chErr   : [nCh x nSample] error (SE/STD/CI ...), if empty or missing -> no shading
%         - color   : [1x3] RGB or color char/string
%         - errColor: shading color (default derived from color)
%         - errAlpha: shading alpha (default 0.5)
%         - legend  : legend label; if empty -> not shown
%
%       Additionally, any other fields are treated as line properties for plot(),
%       e.g. LineWidth / LineStyle / Marker / MarkerSize ... (CASE-INSENSITIVE).
%
%   window : [1x2] time window [tStart, tEnd], must be strictly increasing
%
% OPTIONS (Name-Value via opts.*)
%   opts.GridSize : [] (auto) or [nRow nCol]
%   opts.Channels : [] or vector or [nRow x nCol] matrix
%       - [] : auto map 1:(nRow*nCol)
%       - vector : will be packed into grid (remaining slots are NaN)
%       - matrix : NaN means skip subplot
%
%   opts.Labels   : {} or vector cellstr/string or [nRow x nCol] cell
%       - {} : default labels "CH %d"
%       - vector : must match number of non-NaN channels in grid
%
%   opts.LineParameters : full NV cell, used as default line params
%                         (e.g. {'linewidth',1,'linestyle','-'}).
%                         Normalized to lower-case names.
%
%   opts.BarParameters  : full NV cell, used by mu.addBars()
%                         Common fields: 'mask', 'color', 'alpha'
%                         Normalized to lower-case struct fields.
%
%   opts.Margins  : [left right bottom top] for mu.subplot
%   opts.Paddings : [left right bottom top] for mu.subplot
%
% -------------------------------------------------------------------------
% OUTPUTS
%   Fig : figure handle
% -------------------------------------------------------------------------

arguments
    chData (:,1) struct
    window (1,2) double {mustBeIncreasing2}

    % Allow [] here; validate later if not empty
    opts.GridSize double = []
    opts.Channels double = []

    opts.Labels cell = {}

    % NV cells
    opts.BarParameters  cell = {}
    opts.LineParameters cell = {}

    opts.Margins  (1,4) double = [0.05, 0.05, 0.1, 0.1]
    opts.Paddings (1,4) double = [0.01, 0.05, 0.01, 0.05]
end

% -------------------------
% 0) Normalize + validate "style" inputs (NV pipeline)
% -------------------------
% BarParameters is used via dot-indexing (mask/color/alpha),
% so normalize to STRUCT with lower-case fieldnames.
BarParams = opts.BarParameters;
BarParams = mu.nvnorm(BarParams, FieldCase="lower", OutType="S", ValidateNV=true);

% LineParameters is used as plot() name-value, so normalize to NV with lower-case names.
LineParams = opts.LineParameters;
LineParams = mu.nvnorm(LineParams, FieldCase="lower", OutType="nv", ValidateNV=true);

% Add function-level defaults for line properties if missing/empty in LineParams.
% (default is provided as FULL NV cell; no "Name,Value,... defaults" usage)
LineParams = mu.getorfull(LineParams, {'linewidth', 1, 'linestyle', '-'});
LineParams = mu.nvdropempty(LineParams); % remove any pairs whose VALUE is still empty

% -------------------------
% 1) Normalize chData to case-insensitive field access
% -------------------------
% Convert all fieldnames of chData to lower-case once.
% After this, we ONLY use lower-case names: chmean, cherr, errcolor, erralpha, legend, linewidth...
chData = chData(:);
chData = mu.nvnorm(chData, OutType="S", FieldCase="lower", ValidateNV=false);

% Required field: chMean (now "chmean")
assert(all(isfield(chData, "chmean")), ...
    "Each element of chData must contain field 'chMean' (case-insensitive).");

ngroup = numel(chData);
[nch, nsample] = mu.checkdata({chData.chmean});
t = linspace(window(1), window(2), nsample);

% -------------------------
% 2) Grid / channel mapping / label mapping
% -------------------------
GridSize = opts.GridSize;
Channels = opts.Channels;
Labels   = opts.Labels;

if isempty(GridSize)
    GridSize = mu.autoplotsize(nch);
else
    validateattributes(GridSize, {'numeric'}, {'numel',2,'integer','positive'});
    GridSize = reshape(GridSize, 1, 2);
end

[ChannelMap, LabelMap] = mapChs2Grid_(GridSize, Labels, Channels, nch);

% -------------------------
% 3) Colors and shading defaults
% -------------------------
% If no color provided, assign lines(ngroup).
if ~isfield(chData, "color")
    chData = mu.addfield(chData, "color", lines(ngroup));
end

% For errColor/errAlpha, we compute defaults per group.
% errColor default = slightly reduced saturation or adjusted brightness (for gray).
[errColorCell, errAlphaCell] = deal(cell(ngroup, 1));
for gIndex = 1:ngroup
    baseColor = validatecolor(chData(gIndex).color);
    hsi = rgb2hsv(baseColor);

    if hsi(2) == 0
        % gray/black: tweak brightness
        hsi(3) = min([1.1 * hsi(3), 0.9]);
    else
        % colored: reduce saturation
        hsi(2) = 0.7 * hsi(2);
    end

    errColorCell{gIndex} = mu.getor(chData(gIndex), "errcolor", hsv2rgb(hsi), true);
    errAlphaCell{gIndex} = mu.getor(chData(gIndex), "erralpha", 0.5, true);
end
chData = mu.addfield(chData, "errcolor", errColorCell);
chData = mu.addfield(chData, "erralpha", errAlphaCell);

% -------------------------
% 4) Precompute legend line params per group (match actual plot)
% -------------------------
% Key idea:
%   - Each group may carry its own line properties in chData(g)
%   - We merge them with LineParams defaults using getorfull(... ReplaceEmpty=true)
%   - Then drop empty NV pairs to avoid passing invalid properties to line/plot
legendLineNV = cell(ngroup, 1);
for gIndex = 1:ngroup
    groupLineNV = groupLineParamsNV_(chData(gIndex), LineParams);
    legendLineNV{gIndex} = groupLineNV;
end

% -------------------------
% 5) Plot
% -------------------------
margins  = opts.Margins;
paddings = opts.Paddings;

Fig = figure("WindowState", "maximized");
lastAx = [];

nrow = GridSize(1);
ncol = GridSize(2);

for rIndex = 1:nrow
    for cIndex = 1:ncol
        ch = ChannelMap(rIndex, cIndex);
        if isnan(ch)
            continue; % skipped subplot
        end

        subIndex = (rIndex - 1) * ncol + cIndex;

        ax = mu.subplot(Fig, nrow, ncol, subIndex, ...
            "margins", margins, "paddings", paddings);
        lastAx = ax;
        hold(ax, "on");

        % ---- plot all groups on this channel ----
        for gIndex = 1:ngroup
            chMean = chData(gIndex).chmean;
            chErr  = mu.getor(chData(gIndex), "cherr"); % missing -> []

            % Derive group-specific line params (same logic as legend)
            chLineNV = legendLineNV{gIndex};

            baseColor = validatecolor(chData(gIndex).color);
            eColor = chData(gIndex).errcolor;
            eAlpha = chData(gIndex).erralpha;

            % Shaded error region
            if ~isempty(chErr)
                y1 = chMean(ch, :) + chErr(ch, :);
                y2 = chMean(ch, :) - chErr(ch, :);
                fill(ax, [t, fliplr(t)], [y1, fliplr(y2)], eColor, ...
                    'edgealpha', 0, 'facealpha', eAlpha);
            end

            % Main line
            idx = find(strcmpi(chLineNV, "linestyle"));
            if strcmpi(chLineNV{idx + 1}, "dash") % manual dashed line
                tempNV = chLineNV;
                tempNV(idx:idx + 1) = [];
                tempNV = [tempNV(:)', {"color", baseColor}];
                mu.dashline(ax, t, chMean(ch, :), "DashLength", 10, "GapLength", 5, tempNV{:});
            else
                plot(ax, t, chMean(ch, :), "Color", baseColor, chLineNV{:});
            end
            
        end

        % ---- Bars (significance, etc.) ----
        if ~isempty(BarParams)
            maskAll = mu.getor(BarParams, "mask", []);
            if ~isempty(maskAll)
                idx = resolveBarMaskIndex_(maskAll, ch, subIndex, cIndex, GridSize);
                if ~isempty(idx)
                    mu.addBars(ax, ...
                        idx, ...
                        mu.getor(BarParams, "color", "k"), ...
                        mu.getor(BarParams, "alpha", 0.1));
                end
            end
        end

        xlim(ax, window);
        title(ax, LabelMap{rIndex, cIndex});

        % A lightweight tick rule (kept close to your original logic)
        % Hide y ticklabels for non-first column
        if cIndex ~= 1
            yticklabels(ax, '');
        end
        % Hide x ticklabels for non-last row
        if rIndex ~= nrow
            xticklabels(ax, '');
        end
    end
end

mu.scaleAxes(Fig, "y");

% -------------------------
% 6) Legend (match line style/width from final chLineParams)
% -------------------------
if isfield(chData, "legend") && any(~cellfun(@isempty, {chData.legend}))
    legendHandles = gobjects(1, ngroup);

    % Make an invisible overlay axes to host legend items
    axLeg = mu.subplot(Fig, 1, 1, 1, "paddings", zeros(1, 4), "margins", zeros(1, 4));
    hold(axLeg, "on");

    for gIndex = 1:ngroup
        if isempty(chData(gIndex).legend)
            continue;
        end

        % replace "dash" style with "--"
        idx = find(strcmpi(legendLineNV{gIndex}, "linestyle"));
        if strcmpi(legendLineNV{gIndex}{idx + 1}, "dash")
            legendLineNV{gIndex}{idx + 1} = "--";
        end

        legendHandles(gIndex) = line(axLeg, nan, nan, ...
            "Color", chData(gIndex).color, ...
            legendLineNV{gIndex}{:});  % <-- use final NV (linewidth/linestyle etc.)
    end

    idx = isgraphics(legendHandles);
    legend(axLeg, legendHandles(idx), {chData(idx).legend}', ...
        'Location', 'northeast', 'AutoUpdate', 'off');

    set(axLeg, "Visible", "off", "HitTest", "off", "PickableParts", "none");

    % Return focus to last real axes
    if ~isempty(lastAx) && isgraphics(lastAx)
        axes(lastAx);
    end
end

if nargout == 1
    varargout{1} = Fig;
end
end

%% ========================================================================
% Local validators / utilities
% ========================================================================

function mustBeIncreasing2(x)
% Compatible with older MATLAB versions (no built-in mustBeIncreasing).
if ~(x(2) > x(1))
    error("window must be strictly increasing: window(2) > window(1).");
end
end

function nv = groupLineParamsNV_(groupStructLower, lineDefaultsNV)
% Compute the final Name-Value list used for plotting a group line.
%
% Steps:
%   1) Remove non-line fields from chData element
%   2) Normalize to NV with lower-case names
%   3) Fill missing fields from default (ReplaceEmpty=true handles struct expansion [])
%   4) Drop empty-value pairs to avoid passing invalid props to plot/line

% Remove known non-line fields (already lower-case)
rmNames = intersect(fieldnames(groupStructLower), ...
    ["chmean","cherr","color","errcolor","erralpha","legend"], 'stable');

lineStruct = rmfield(groupStructLower, rmNames);

% Normalize group line struct to NV (lower-case)
nv = mu.nvnorm(lineStruct, FieldCase="lower", OutType="nv", ValidateNV=true);

% Fill missing fields from default; replace empty values using default
% This fixes the common "struct array expansion created []" issue.
nv = mu.getorfull(nv, lineDefaultsNV, "ReplaceEmpty", true);

% Drop any pairs whose VALUE is still empty (e.g., default doesn't specify it)
nv = mu.nvdropempty(nv);
end

function idx = resolveBarMaskIndex_(maskAll, ch, subIndex, cIndex, GridSize)
% Resolve bar mask indices from BarParams.mask.
%
% We accept several conventions (to be robust):
%   - size(mask,1) == GridSize(2) : each COLUMN has a mask row (your original cIndex usage)
%   - size(mask,1) == prod(GridSize): each SUBPLOT has a mask row (subIndex)
%   - size(mask,1) == nch          : each CHANNEL has a mask row (ch)
%
% Returned idx are time indices to draw bars.

idx = [];

if ~ismatrix(maskAll)
    return;
end

nrow = GridSize(1);
ncol = GridSize(2);

if size(maskAll, 1) == ncol
    row = cIndex;
elseif size(maskAll, 1) == nrow * ncol
    row = subIndex;
elseif size(maskAll, 1) >= ch
    % This also covers "mask has nch rows"
    row = ch;
else
    return;
end

if row <= size(maskAll,1)
    idx = find(maskAll(row, :));
end
end

function [chMap, labelMap] = mapChs2Grid_(gsz, labels, chs, nch)
% Map channels to subplot grid and generate label map.
%
% chMap: [nRow x nCol] numeric, NaN = skip subplot
% labelMap: [nRow x nCol] cellstr

nrow = gsz(1);
ncol = gsz(2);

% -------------------------
% Channel map
% -------------------------
if isempty(chs)
    % default: fill 1:prod(gsz) into grid, then clip by nch
    chMap = reshape(1:(nrow*ncol), [ncol, nrow])';
else
    if isvector(chs)
        assert(numel(chs) <= nrow*ncol, "The number of channels should not exceed grid size.");
        tmp = [chs(:); nan(nrow*ncol - numel(chs), 1)];
        chMap = reshape(tmp, [ncol, nrow])';
        % allow explicit skipping (NaN in chs): keep NaN as skip
        % also blank out any padded indices
        chMap(~ismember(chMap, chs)) = nan;
    else
        assert(isequal(size(chs), gsz), "Size of Channels should be equal to GridSize.");
        chMap = chs;
    end
end

% Clip invalid channel indices
chMap(chMap > nch) = nan;
chMap(chMap < 1)   = nan;

% -------------------------
% Label map
% -------------------------
if isempty(labels)
    labelMap = compose('CH %d', chMap);
else
    if isvector(labels)
        nNeed = sum(~isnan(chMap), "all");
        assert(numel(labels) == nNeed, ...
            "The number of Labels should equal the number of non-NaN Channels.");

        labelMapStr = strings(nrow, ncol);
        labelMapStr(:) = "";

        labelMapStr(~isnan(chMap)) = string(labels(:));
        labelMap = cellstr(labelMapStr);
    else
        assert(isequal(size(labels), gsz), "Size of Labels should be equal to GridSize.");
        labelMap = labels;
    end
end
end
