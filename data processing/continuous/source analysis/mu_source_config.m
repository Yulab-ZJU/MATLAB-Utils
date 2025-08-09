function [elec, vol, mri, grid, atlas] = mu_source_config(labelsIncluded)
% This function loads standard head model, MRI model, and standard 10-20 
% electrode position and computes leadfield for source analysis.

%% Read standard files
% search for root path of fieldtrip
ftRootPath = fileparts(which("ft_defaults"));

% load
load(fullfile(ftRootPath, 'template\headmodel\standard_bem.mat'), 'vol'); % head model
mri   = ft_read_mri(fullfile(ftRootPath, 'template\anatomy\single_subj_T1_1mm.nii'));
elec  = ft_read_sens(fullfile(ftRootPath, 'template\electrode\standard_1020.elc'));
atlas = ft_read_atlas(fullfile(ftRootPath, 'template\atlas\aal\ROI_MNI_V4.nii'));

%% Unit conversion - mm
elec  = ft_convert_units(elec,  'mm');
vol   = ft_convert_units(vol,   'mm');
mri   = ft_convert_units(mri,   'mm');
atlas = ft_convert_units(atlas, 'mm');

%% MRI
mri.coordsys = 'mni';

cfg = [];
cfg.resolution = 1;
cfg.xrange = [-100 100];
cfg.yrange = [-110 140];
cfg.zrange = [-80 120];
mri = ft_volumereslice(cfg, mri);
mri = ft_convert_units(mri, 'mm');

%% Electrode
% only include electrodes in standard 10-20 system
idx = ismember(upper(elec.label), upper(labelsIncluded));
elec.chanpos  = elec.chanpos (idx, :);
elec.chantype = elec.chantype(idx);
elec.chanunit = elec.chanunit(idx);
elec.elecpos  = elec.elecpos (idx, :);
elec.label    = elec.label   (idx);

%% Grid
cfg = [];
cfg.xgrid = -200:10:200;
cfg.ygrid = -200:10:200;
cfg.zgrid = -200:10:200;
cfg.unit  = 'mm';
cfg.tight = 'yes';
cfg.inwardshift = -1.5;
cfg.headmodel = vol;
template_grid = ft_prepare_sourcemodel(cfg);
template_grid.coordsys = 'mni';

%% ROI
cfg = [];
cfg.atlas      = atlas;
cfg.roi        = atlas.tissuelabel(1:90);  % here you can also specify a single label, i.e. single ROI
cfg.inputcoord = 'mni';
mask = ft_volumelookup(cfg, template_grid);
template_grid.inside = false(template_grid.dim);
template_grid.inside(mask == 1) = true;
template_grid.inside = template_grid.inside(:);

%% Source model
cfg           = [];
cfg.warpmni   = 'yes';
cfg.template  = template_grid;
cfg.nonlinear = 'yes';
cfg.mri       = mri;
sourcemodel   = ft_prepare_sourcemodel(cfg);

%% Leadfield
cfg                 = [];
cfg.elec            = elec;
cfg.headmodel       = vol;
cfg.reducerank      = 3; % 3 for EEG, 2 for MEG
cfg.resolution      = 10;   % use a 3-D grid with a 10 mm resolution
cfg.unit            = 'mm';
cfg.tight           = 'yes';
cfg.grid            = sourcemodel;
cfg.lcmv.reducerank = 3; % for MEG is 2, for EEG is 3
cfg.normalize       = 'yes';
grid = ft_prepare_leadfield(cfg);

figure;
hold on;
ft_plot_headmodel(vol, 'facecolor', 'cortex', 'edgecolor', 'none');
ft_plot_axes(vol);
alpha 0.4  % make the surface transparent
ft_plot_mesh(grid.pos(grid.inside, :));
hs = ft_plot_sens(elec, 'style', 'r.');
hs.DataTipTemplate.DataTipRows(end + 1) = dataTipTextRow("P", elec.label);

return;
end