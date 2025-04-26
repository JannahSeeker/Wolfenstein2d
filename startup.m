function startup
% STARTUP  Add project folders to the MATLAB path automatically

% Base folder of your project (adjust to your workspace path)
projectRoot = fullfile(getenv('HOME'), 'Wolf_v2');
% Add main folder
addpath(projectRoot);

% Recursively add all subfolders (but skip hidden “.git” or “node_modules” if you like)
addpath(genpath(fullfile(projectRoot, 'Objects')));

% If you want to make these changes permanent
savepath;

fprintf('Added Wolf_v2 project folders to path.\n');
end