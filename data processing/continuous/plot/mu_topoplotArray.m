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
mIp.addParameter("contourOpt", "on", @(x) any(validatestring(x, {'on', 'off'})));
mIp.addParameter("resolution", 5, @(x) validateattributes(x, 'numeric', {'scalar', 'positive', 'integer'}));
mIp.addParameter("contourVal", [], @(x) validateattributes(x, {'numeric', 'logical'}, {'vector'}));
mIp.addParameter("contourTh", 0.6, @(x) validateattributes(x, {'numeric'}, {'scalar', 'real'}));
mIp.addParameter("marker", "none", @(x) true);
mIp.addParameter("markerSize", 36, @(x) validateattributes(x, {'numeric'}, {'positive', 'scalar', 'real'}));
mIp.parse(ax, varargin{:})

data = mIp.Results.data;
topoSize = mIp.Results.topoSize;
contourOpt = mIp.Results.contourOpt;
N = mIp.Results.resolution;
contourVal = mIp.Results.contourVal;
contourTh = mIp.Results.contourTh;
marker = mIp.Results.marker;
markerSize = mIp.Results.markerSize;

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

if strcmpi(contourOpt, "on")
    hold on;

    if isempty(contourVal)
        % contour option may not work with linear array
        try
            contour(ax, X, Y, C, "LineColor", "k");
        end

    else

        if isnumeric(contourVal)
            % for each contour level
            for index = 1:numel(contourVal)
                contour(ax, X, Y, C, [contourVal(index), contourVal(index)], "LineColor", "k", "LineWidth", 1);
            end

        elseif islogical(contourVal)

            if all(contourVal)
                disp('Contour mask all true');
            elseif all(~contourVal)
                disp('Contour mask all false');
            else
                C = flipud(reshape(double(contourVal), topoSize)');
                C = padarray(C, [1, 1], "replicate");
                C = interp2(C, N);
                C = imgaussfilt(C, 8);
                contour(ax, X, Y, C, [contourTh, contourTh], "LineColor", "k", "LineWidth", 1);
            end

            if ~strcmpi(marker, "none")
                [ytemp, xtemp] = find(flipud(reshape(contourVal, topoSize)'));
                scatter(ax, xtemp, ytemp, markerSize, "black", "Marker", marker, "LineWidth", 2);
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