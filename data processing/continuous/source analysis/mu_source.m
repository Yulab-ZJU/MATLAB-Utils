function source = mu_source(data, elec, vol, grid, method, source0)
narginchk(4, 6);

if nargin < 5
    method = 'eloreta';
end

cfg = [];
cfg.grid = grid;
cfg.headmodel = vol;
cfg.elec = elec;
cfg.senstype = 'eeg';

switch method
    case 'eloreta'
        cfg.method = 'eloreta';
        cfg.eloreta.lambda = 0.05; % 加入正则化防止过拟合
        cfg.eloreta.keepmom = 'yes'; % 保留每个源点的时间序列
    case 'lcmv'
        cfg.method = 'lcmv';
        if nargin < 6
            cfg.lcmv.keepfilter = 'yes';
        else
            cfg.sourcemodel.filter = source0.avg.filter;
        end
end

source = ft_sourceanalysis(cfg, data);

return;
end