function varargout = plotTopoICA(topo, topoSize, plotSize, ICs2Plot)
    narginchk(1, 4);

    if nargin < 2
        topoSize = [8, 8]; % [nx, ny]
    end

    if nargin < 3
        plotSize = autoPlotSize(size(topo, 2)); % topo is nCh-by-nIC
    end

    if nargin < 4
        ICs2Plot = reshape(1:(plotSize(1) * plotSize(2)), plotSize(2), plotSize(1))';
    end

    if size(ICs2Plot, 1) ~= plotSize(1) || size(ICs2Plot, 2) ~= plotSize(2)
        disp("chs option not matched with plotSize. Resize chs...");
        ICs2Plot = reshape(ICs2Plot(1):(ICs2Plot(1) + plotSize(1) * plotSize(2) - 1), plotSize(2), plotSize(1))';
    end

    Fig = figure("WindowState", "maximized");
    
    for rIndex = 1:plotSize(1)
    
        for cIndex = 1:plotSize(2)
            ICNum = ICs2Plot(rIndex, cIndex);

            if ICs2Plot(rIndex, cIndex) > size(topo, 2)
                continue;
            end

            mAxe = mSubplot(Fig, plotSize(1), plotSize(2), (rIndex - 1) * plotSize(2) + cIndex, "shape", "square-min");
            plotTopo(mAxe, topo(:, ICNum), topoSize);
            [~, idx] = max(abs(topo(:, ICNum)));
            title(['IC ', num2str(ICNum), ' | max - ', num2str(idx)]);
            scaleAxes(mAxe, "c", "on", "symOpts", "max");
            mColorbar("Width", 0.005);
        end
    
    end

    if nargout == 1
        varargout{1} = Fig;
    elseif nargout > 1
        error("plotTopoICA(): output number should be <= 1");
    end

    return;
end