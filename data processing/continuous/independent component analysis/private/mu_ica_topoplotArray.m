function varargout = mu_ica_topoplotArray(topo, topoSize)
% Plot independent component distribution in electrode array.
% [topoSize]: [nX, nY]
% [topo]: comp.topo with each column for one IC (nch x nIC)

pltsz = mu.autoplotsize(size(topo, 2));

Fig = figure("WindowState", "maximized");
margins = [0.05, 0.05, 0.1, 0.1];
paddings = [0.01, 0.03, 0.01, 0.01];
for rIndex = 1:pltsz(1)

    for cIndex = 1:pltsz(2)
        ICNum = sub2ind(pltsz, cIndex, rIndex);
        ax = mu.subplot(Fig, pltsz(1), pltsz(2), ICNum, "shape", "square-min", "margins", margins, "paddings", paddings);
        mu_topoplotArray(ax, topo(:, ICNum), topoSize);
        [~, idx] = max(abs(topo(:, ICNum)));
        title(ax, ['IC ', num2str(ICNum), ' | max - ', num2str(idx)]);
        mu.scaleAxes(ax, "c", "on", "symOpts", "max");
        mu.colorbar("Width", 0.005);
    end

end

if nargout == 1
    varargout{1} = Fig;
end

return;
end