function source_interp = mu_source_interp(source, mri, downsample)
narginchk(2, 3);

if nargin < 3
    downsample = 2;
end

cfg = [];
cfg.parameter = 'pow';
cfg.interpmethod = 'linear';
% cfg.interpmethod = 'nearest';
cfg.downsample = downsample;
cfg.coordsys = 'mni';
source_interp = ft_sourceinterpolate(cfg, source, mri);

return;
end