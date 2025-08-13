function varargout = mu_topoplotArray(varargin)
% Description: remap [data] according to [topoSize] and plot color map to axes
% Input:
%     ax: target axes
%     data: double vector, make sure that numel(data)==prod(topoSize).
%     topoSize: [x,y], [data] will be remapped as a [x,y] matrix.
%               [x,y] -> [ncol,nrow], indices start from left-top.
%     contourOpt: contour option "on" or "off" (default="on")
%     resolution: apply 2-D interpolation to the remapped [data], which is an
%                 N-point insertion. Thus, resolution = N.
%     contourVal: contour levels, specified as a numeric vector or a
%                 logical vector. If specified as a logical vector
%                 (mask), it should be the same size as [data].
%     contourTh: contour threshold (default=0.6)
%     marker: add markers (e.g., 'x') to significant points (default='none')
%     markerSize: marker size (default=36)
% Output:
%     ax: output axes
% Example:
%     % plot significant levels
%     plotTopo(1-log(p), [8, 8], ...
%              "contourOpt", "on", ...
%              "contourVal", p < 0.01);

if isgraphics(varargin{1}(1), "axes")
    ax = varargin{1}(1);
    varargin = varargin(2:end);
else
    ax = gca;
end

mIp = inputParser;
mIp.addRequired("ax", @(x) isgraphics(x, "axes"));
mIp.addRequired("data", @(x) isnumeric(x) && isvector(x));
mIp.addRequired("topoSize", @(x) validateattributes(x, 'numeric', {'numel', 2, 'positive', 'integer'}));
mIp.addParameter("ContourOpt", "on");
mIp.addParameter("Resolution", 5, @(x) validateattributes(x, 'numeric', {'scalar', 'positive', 'integer'}));
mIp.addParameter("ContourVal", [], @(x) validateattributes(x, {'numeric', 'logical'}, {'vector'}));
mIp.addParameter("ContourTh", 0.6, @(x) validateattributes(x, {'numeric'}, {'scalar', 'real'}));
mIp.addParameter("Marker", "none");
mIp.addParameter("MarkerSize", 36, @(x) validateattributes(x, {'numeric'}, {'positive', 'scalar', 'real'}));
mIp.parse(ax, varargin{:})

data = mIp.Results.data;
topoSize = mIp.Results.topoSize;
ContourOpt = validatestring(mIp.Results.ContourOpt, {'on', 'off'});
N = mIp.Results.Resolution;
ContourVal = mIp.Results.ContourVal;
ContourTh = mIp.Results.ContourTh;
Marker = mIp.Results.Marker;
MarkerSize = mIp.Results.MarkerSize;

if numel(data) ~= prod(topoSize)
    error("numel(data) ~= prod(topoSize)");
end

if any(isnan(data))
    warning("NAN found in your data. NAN will be replaced by zero");
    data(isnan(data)) = 0;
end

C = flipud(reshape(data, topoSize)');
C = padarray(C, [1, 1], "replicate");
C = interp2(C, N);
C = imgaussfilt(C, 8);
X = linspace(0, topoSize(1) + 1, size(C, 1));
Y = linspace(0, topoSize(2) + 1, size(C, 2));
imagesc(ax, "XData", X, "YData", Y, "CData", C);
cRange = get(ax, "CLim");

if strcmpi(ContourOpt, "on")
    hold on;

    if isempty(ContourVal)
        % contour option may not work with linear array
        try
            contour(ax, X, Y, C, "LineColor", [0, 0, 0]);
        end

    else

        if isnumeric(ContourVal)
            % for each contour level
            for index = 1:numel(ContourVal)
                contour(ax, X, Y, C, [ContourVal(index), ContourVal(index)], "LineColor", [0, 0, 0], "LineWidth", 1);
            end

        elseif islogical(ContourVal)

            if all(ContourVal)
                disp('Contour mask all true');
            elseif all(~ContourVal)
                disp('Contour mask all false');
            else
                C = flipud(reshape(double(ContourVal), topoSize)');
                C = padarray(C, [1, 1], "replicate");
                C = interp2(C, N);
                C = imgaussfilt(C, 8);
                contour(ax, X, Y, C, [ContourTh, ContourTh], "LineColor", "k", "LineWidth", 1);
            end

            if ~strcmpi(Marker, "none")
                [ytemp, xtemp] = find(flipud(reshape(ContourVal, topoSize)'));
                scatter(ax, xtemp, ytemp, MarkerSize, "black", "Marker", Marker, "LineWidth", 2);
            end

        end

    end

end

set(ax, "XLimitMethod", "tight");
set(ax, "YLimitMethod", "tight");
set(ax, "Box", "on");
set(ax, "BoxStyle", "full");
set(ax, "LineWidth", 3);
set(ax, "XTickLabels", '');
set(ax, "YTickLabels", '');
set(ax, "CLim", cRange); % reset c limit

if nargout == 1
    varargout{1} = ax;
end

return;
end