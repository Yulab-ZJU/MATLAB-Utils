function varargout = plotRaster(trialAll, window, clus)
narginchk(2, 3);

if nargin < 3
    clus = [];
end

spikes = {trialAll.spike}';
if ~isempty(clus)
    spikes = cellfun(@(x) x(x(:, 2) == clus, 1), spikes, "UniformOutput", false);
else
    spikes = cellfun(@(x) x(:, 1), spikes, "UniformOutput", false);
end

Fig = figure("WindowState", "normal");
ax1 = mu.subplot(Fig, 1, 1, 1, [1/2, 2/3], "alignment", "center-top");
rasterData.X = spikes;
mu.rasterplot(ax1, rasterData, 20);
ylim([0, length(rasterData.X) + 1]);
xticklabels(ax1, '');
yticklabels(ax1, '');

ax2 = mu.subplot(Fig, 1, 1, 1, [1/2, 1/3], "alignment", "center-bottom");
[psth, edges] = mu_calPSTH(spikes, window, 10, 5);
plot(ax2, edges, psth, "Color", "k", "LineWidth", 2);
xlabel(ax2, "Time from trial onset (ms)");
ylabel(ax2, "Firing rate (Hz)");

mu.scaleAxes(Fig, "x", window);
mu.addLines(Fig, struct("X", 0));
mu.scaleAxes(Fig, "x", window);
mu.addLines(Fig, struct("X", 0));

if nargout == 1
    varargout{1} = Fig;
end
if nargout == 1
    varargout{1} = Fig;
end

return;
end