function openPhyGUI(path)

% Validate params
narginchk(0, 1);
if nargin < 1
    path = uigetdir();
end
mustBeTextScalar(path);
assert(exist(path, "dir"), "Input path should be a folder");

% Check conda envs, which should include env 'phy2'
[status, envList] = system('conda env list');
if status ~= 0
    error('Failed to list Conda environments. Is conda installed and on PATH?');
end
temp = regexp(envList, '\n', 'split');
envExists = any(contains(temp, 'phy2'));

% Create env 'phy2' and install pkgs
if ~envExists
    disp('Conda environment "phy2" not found. Creating...');

    % Create a new conda environment with the conda dependencies:
    cmd = ['conda create -n phy2 -y python=3.11 ' ...
           'cython dask h5py joblib matplotlib numpy pillow pip ' ...
           'pyopengl pyqt pyqtwebengine pytest python qtconsole ' ...
           'requests responses scikit-learn scipy traitlets'];
    status1 = system(cmd);

    % Install the development version of phy
    status2 = system('pip install git+https://github.com/cortex-lab/phy.git');

    if status1 ~= 0 || status2 ~= 0
        error('Failed to create Conda environment "phy2".');
    end

end

currentPath = pwd;
cd(path);
[status, cmdout] = system('conda run -n phy2 phy template-gui params.py');
if status ~= 0
    error(['Unexpected error occurred: ', newline, cmdout]);
end
cd(currentPath);

return;
end