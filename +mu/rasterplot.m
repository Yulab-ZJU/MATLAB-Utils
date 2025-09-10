function ax = rasterplot(varargin)
%RASTERPLOT  Plot spike rasters
%
% INPUTS:
%   REQUIRED:
%     rasterData  - raster dataset, struct vector wiith fields:
%                   [X]     : x data, cell vector
%                   [Y]     : y data (If not specified, plot trial by trial)
%                   [color] : scatter color (default="k")
%                   [marker]: marker shape (default="o")
%                   [lines] : lines to add to scatterplot (see mu.addLines.m)
%   OPTIONAL:
%     ax  - axes target (If ignored, default=gca)
%     sz  - scatter size (default=40)
%   NAME-VALUE:
%     border  - show borders between groups (default=false)
%
% EXAMPLES:
%     data(1).X = {[1, 2, 3, 4, 5]; []; [1.5, 2.5]}; % three trials
%     data(1).color = [1 0 0];
%     data(2).X = {[2, 4, 6]}; % one trial
%     data(2).color = [0 0 1];
%     mu.rasterplot(data, 20);

if isgraphics(varargin{1}(1), "axes")
    ax = varargin{1}(1);
    varargin = varargin(2:end);
else
    ax = gca;
end

mIp = inputParser;
mIp.addRequired("ax", @(x) isgraphics(x, "axes"));
mIp.addRequired("rasterData", @isstruct);
mIp.addOptional("sz", 40, @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive', 'integer'}));
mIp.addParameter("border", mu.OptionState.Off, @mu.OptionState.validate);
mIp.parse(ax, varargin{:})

rasterData = mIp.Results.rasterData;
sz = mIp.Results.sz;
border = mu.OptionState.create(mIp.Results.border);

nTrials = 0;
hold(ax, "on");

for index = 1:numel(rasterData)
    X = rasterData(index).X(:);

    if ~isfield(rasterData(index), "Y")
        Y = mat2cell((nTrials + 1:nTrials + numel(rasterData(index).X))', ones(numel(rasterData(index).X), 1));
        nTrials = nTrials + numel(X);
        Y = cell2mat(cellfun(@(x, y) repmat(y, [numel(x), 1]), X, Y, "UniformOutput", false));
        X = cellfun(@(x) x(:), X, "UniformOutput", false);
        X = cat(1, X{:});
    end

    if isempty(X) || isempty(Y)
        continue;
    end

    color = mu.getor(rasterData(index), "color", "k");
    marker = mu.getor(rasterData(index), "marker", "o");
    scatter(ax, X, Y, sz, "filled", ...
            "Marker", marker, ...
            "MarkerEdgeColor", "none", ...
            "MarkerFaceColor", color);

    Lines = mu.getor(rasterData(index), "lines");
    if ~isempty(Lines)
        Lines = mu.addfield(Lines, "X", arrayfun(@(x) repmat(x.X, 2, 1), Lines, "UniformOutput", false));
        Lines = mu.addfield(Lines, "Y", repmat([min(Y), max(Y)], numel(Lines), 1));
        mu.addLines(ax, Lines, "ConstantLine", false);
    end

    if border.toLogical
        mu.addLines(ax, struct("Y", max(Y) + 0.5, ...
                                   "width", 0.5, ...
                                   "style", "-", ...
                                   "color", [0, 0, 0]));
    end

end

set(ax, "XLimitMethod", "tight");
set(ax, "YLimitMethod", "tight");

return;
end
