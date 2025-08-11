function varargout = mu_ica_topoplotEEG(topo, EEGPos)

pltsz = mu.autoplotsize(size(topo, 2)); % topo is chan-by-IC

Fig = figure("WindowState", "maximized");
margins = [0.05, 0.05, 0.1, 0.1];
paddings = [0.01, 0.03, 0.01, 0.01];
for rIndex = 1:pltsz(1)

    for cIndex = 1:pltsz(2)
        ICNum = sub2ind(flip(pltsz), cIndex, rIndex);

        if ICNum > size(topo, 2)
            continue;
        end

        ax = mu.subplot(Fig, pltsz(1), pltsz(2), ICNum, "shape", "square-min", "margins", margins, "paddings", paddings);
        topoplot(topo(:, ICNum), EEGPos.locs);
        title(ax, ['IC ', num2str(ICNum)]);
        colorbar;
    end

end

if nargout == 1
    varargout{1} = Fig;
end

return;
end