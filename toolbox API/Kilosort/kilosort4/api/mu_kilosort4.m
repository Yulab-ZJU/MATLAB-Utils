function mu_kilosort4(settings, opts)
% MU_KILOSORT4 runs kilosort-4 in MATLAB via python API.
%
% NOTES:
%   Run mu_ks4_config.m first for [settings] and [opts].
%
%   *Conda env kilosort is a MUST:
%   1. Create env kilosort with python=3.x (e.g., 3.10 or 3.11)
%     conda create --name kilosort python=3.10
%   2. Activate conda environment:
%     conda activate kilosort
%   3. Install kilosort dependencies:
%     python -m pip install kilosort[gui]
%   4. (OPTIONAL) To run kilosort with GPU
%      (please install the compatible CUDA version for your computer):
%     pip uninstall torch
%     pip3 install torch --index-url https://download.pytorch.org/whl/cu118
%
%   To visualize the sorting result, Phy2 is recommended:
%   1. Create a new conda environment with the conda dependencies:
%     conda create -n phy2 -y python=3.11 cython dask h5py joblib matplotlib numpy pillow pip pyopengl pyqt pyqtwebengine pytest python qtconsole requests responses scikit-learn scipy traitlets
%   2. Activate conda environment:
%     conda activate phy2
%   3. Install the development version of phy:
%     pip install git+https://github.com/cortex-lab/phy.git
%   To open phy GUI via MATLAB, see openPhyGUI.m
%

% python interpreter
pythonExe = opts.pythonExe;
opts = rmfield(opts, "pythonExe");

% json convertion
settings_json = jsonencode(settings);
opts_json = jsonencode(opts);

% export json to temp files
settings_file = [tempname, '_settings.json'];
opts_file = [tempname, '_opts.json'];
fid = fopen(settings_file, 'w'); fwrite(fid, settings_json); fclose(fid);
fid = fopen(opts_file, 'w'); fwrite(fid, opts_json); fclose(fid);

% python API
pyScript = fullfile(fileparts(mfilename("fullpath")), 'kilosort4_wrapper.py');

% construct command line script
cmd = sprintf('"%s" "%s" "%s" "%s"', pythonExe, pyScript, settings_file, opts_file);

% run python script via command line
[status, cmdout] = system(cmd);

% clear temp files
delete(settings_file);
delete(opts_file);

if status ~= 0
    error('Python script execution failed:\n%s', cmdout);
end

end
