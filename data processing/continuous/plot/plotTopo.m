function varargout = plotTopo(varargin)
    % Description: remap [Data] according to [topoSize] and plot color map to axes
    % Input:
    %     mAxe: target axes
    %     Data: double vector, make sure that numel(Data) equals prod(topoSize).
    %     topoSize: [x,y], [Data] will be remapped as a [x,y] matrix.
    %               [x,y] -> [nCol,nRow], indices start from left-top.
    %     contourOpt: contour option "on" or "off" (default="on")
    %     resolution: apply 2-D interpolation to the remapped [Data], which is an
    %                 N-point insertion. Thus, resolution = N.
    %     contourVal: contour levels, specified as a numeric vector or a
    %                 logical vector. If specified as a logical vector
    %                 (mask), it should be the same size as [Data].
    %     contourTh: contour threshold (default=0.6)
    %     marker: add markers (e.g., 'x') to significant points (default='none')
    %     markerSize: marker size (default=36)
    % Output:
    %     mAxe: output axes
    % Example:
    %     % plot significant levels
    %     plotTopo(gca, 1-log(p), [8, 8], ...
    %              "contourOpt", "on", ...
    %              "contourVal", p < 0.01);

    if isgraphics(varargin{1}(1), "axes")
        mAxe = varargin{1}(1);
        varargin = varargin(2:end);
    else
        mAxe = gca;
    end

    mIp = inputParser;
    mIp.addRequired("mAxe", @(x) isgraphics(x, "axes"));
    mIp.addRequired("Data", @(x) isnumeric(x) && isvector(x));
    mIp.addOptional("topoSize", [8, 8], @(x) validateattributes(x, 'numeric', {'numel', 2, 'positive', 'integer'}));
    mIp.addParameter("contourOpt", "on", @(x) any(validatestring(x, {'on', 'off'})));
    mIp.addParameter("resolution", 5, @(x) validateattributes(x, 'numeric', {'scalar', 'positive', 'integer'}));
    mIp.addParameter("contourVal", [], @(x) validateattributes(x, {'numeric', 'logical'}, {'vector'}));
    mIp.addParameter("contourTh", 0.6, @(x) validateattributes(x, {'numeric'}, {'scalar', 'real'}));
    mIp.addParameter("marker", "none", @(x) true);
    mIp.addParameter("markerSize", 36, @(x) validateattributes(x, {'numeric'}, {'positive', 'scalar', 'real'}));
    mIp.parse(mAxe, varargin{:})

    Data = mIp.Results.Data;
    topoSize = mIp.Results.topoSize;
    contourOpt = mIp.Results.contourOpt;
    N = mIp.Results.resolution;
    contourVal = mIp.Results.contourVal;
    contourTh = mIp.Results.contourTh;
    marker = mIp.Results.marker;
    markerSize = mIp.Results.markerSize;

    if numel(Data) ~= prod(topoSize)
        error("Numel of input data should be topoSize(1)*topoSize(2)");
    end

    if any(isnan(Data))
        warning("NaN found in your data. NaN will be replaced by zero");
        Data(isnan(Data)) = 0;
    end
    
    C = flipud(reshape(Data, topoSize)');
    C = padarray(C, [1, 1], "replicate");
    C = interp2(C, N);
    C = imgaussfilt(C, 8);
    X = linspace(0, topoSize(1) + 1, size(C, 1));
    Y = linspace(0, topoSize(2) + 1, size(C, 2));
    imagesc(mAxe, "XData", X, "YData", Y, "CData", C);
    cRange = get(mAxe, "CLim");

    if strcmpi(contourOpt, "on")
        hold on;
        
        if isempty(contourVal)
            % contour option may not work with linear array
            try
                contour(mAxe, X, Y, C, "LineColor", "k");
            end

        else
            
            if isnumeric(contourVal)
                % for each contour level
                for index = 1:numel(contourVal)
                    contour(mAxe, X, Y, C, [contourVal(index), contourVal(index)], "LineColor", "k", "LineWidth", 1);
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
                    contour(mAxe, X, Y, C, [contourTh, contourTh], "LineColor", "k", "LineWidth", 1);
                end

                if ~strcmpi(marker, "none")
                    [ytemp, xtemp] = find(flipud(reshape(contourVal, topoSize)'));
                    scatter(mAxe, xtemp, ytemp, markerSize, "black", "Marker", marker, "LineWidth", 2);
                end

            end

        end

    end

    set(mAxe, "XLimitMethod", "tight");
    set(mAxe, "YLimitMethod", "tight");
    set(mAxe, "Box", "on");
    set(mAxe, "BoxStyle", "full");
    set(mAxe, "LineWidth", 3);
    set(mAxe, "XTickLabels", '');
    set(mAxe, "YTickLabels", '');
    set(mAxe, "CLim", cRange); % reset c limit
    % colormap(mAxe, 'jet');
    % colormap(mAxe, mColormap('b', 'r'));
    colormap(mAxe, flipud(slanCM('RdYlBu')));

    if nargout == 1
        varargout{1} = mAxe;
    elseif nargout > 1
        error("plotTopo(): output number should be <= 1");
    end

    return;
end