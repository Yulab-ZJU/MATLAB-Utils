function varargout = mu_source_plot(source, mri, method2D, cm, th)
narginchk(2, 5)

if nargin < 3
    method2D = 'slice'; % or 'ortho'
end

if nargin < 4
    cm = 'jet';
end

if nargin < 5
    th = [];
end

source_interp = mu_source_interp(source, mri);

% 3-D plot
cfg = [];
cfg.method        = 'surface';
cfg.funparameter  = 'pow';
cfg.maskparameter = cfg.funparameter; % only show value~=0
cfg.funcolormap   = cm;
cfg.projmethod    = 'nearest';
cfg.camlight      = 'no';
cfg.surfinflated  = 'surface_inflated_both_caret.mat';
cfg.surffile      = 'surface_white_both.mat';
if ~isempty(th)
    cfg.projthresh = th;
end
Fig3D = figure("WindowState", "maximized");
ft_sourceplot(cfg, source_interp);
tar = get(Fig3D, "Children");
tar = tar(end); % Axes
sz_ratio = tar.Position(4) / tar.Position(3);
L = 0.4;
% left
ax(1) = copyobj(tar, Fig3D);
view(ax(1), -110, 15);
ax(1).Position = [0.05, 0.3, L, L * sz_ratio];
% top
ax(2) = copyobj(tar, Fig3D);
ax(2).Position = [0.3, 0.3, L, L * sz_ratio];
% right
ax(3) = copyobj(tar, Fig3D);
ax(3).Position = [0.55, 0.3, L, L * sz_ratio];
view(ax(3), 110, 15);
mu.scaleAxes(ax, "c", "ignoreInvisible", false);
mu.colorbar(ax(3), "eastoutside");
delete(tar);

% 2-D plot
cfg = [];
cfg.method = method2D;
cfg.funparameter = 'pow';
cfg.funcolormap = cm;
Fig2D = figure("WindowState", "maximized");
ft_sourceplot(cfg, source_interp);

if nargout >= 1
    varargout{1} = Fig2D;
end

if nargout >= 2
    varargout{2} = Fig3D;
end

return;
end