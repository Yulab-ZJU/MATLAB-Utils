function varargout = mu_ica_topoplotEEG(topo, EEGPos)

pltsz = mu.autoplotsize(size(topo, 2)); % topo is chan-by-IC

Fig = figure("WindowState", "maximized");
fontSize = get(Fig, "DefaultAxesFontSize");
titleFontSize = get(Fig, "DefaultAxesTitleFontSize");

for rIndex = 1:pltsz(1)

    for cIndex = 1:pltsz(2)
        ICNum = sub2ind(flip(pltsz), cIndex, rIndex);

        if ICNum > size(topo, 2)
            break;
        end

        ax = mu.subplot(Fig, pltsz(1), pltsz(2), ICNum);
        mu_topoplotEEG(ax, topo(:, ICNum), EEGPos, "MarkerSize0", 1);
        title(ax, ['IC ', num2str(ICNum)], "FontSize", fontSize * titleFontSize, "FontWeight", "bold");
        colorbar;
    end

end

if nargout == 1
    varargout{1} = Fig;
end

% reset fontsize
set(0, "DefaultAxesFontSize", fontSize);
set(0, "DefaultAxesTitleFontSize", titleFontSize);

return;
end