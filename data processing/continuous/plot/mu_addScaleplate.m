function sp = mu_addScaleplate(varargin)
% MU_ADDSCALEPLATE Create scaleplate axes in a figure
% Example:
%   sp = mu_addScaleplate(gcf, 'Position', [0.05 0.05 0.05 0.05])

if isscalar(varargin{1}) && isa(varargin{1}, "matlab.ui.Figure")
    Fig = varargin{1};
    varargin = varargin(2:end);
else
    Fig = gcf;
end

sp = mu_scaleplate(Fig, varargin{:});
return;
end
