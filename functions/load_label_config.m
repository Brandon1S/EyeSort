function config = load_label_config(filename)
% LOAD_LABEL_CONFIG - Load label configuration from file
%
% Usage:
%   config = load_label_config(filename)
%
% Inputs:
%   filename - Input filename (optional, will show file dialog if not provided)
%
% Outputs:
%   config - Label configuration structure

if nargin < 1
    [filename, filepath] = uigetfile('*.mat', 'Load Label Configuration');
    if isequal(filename, 0)
        config = [];
        return;
    end
    filename = fullfile(filepath, filename);
elseif strcmp(filename, 'last_label_config.mat')
    % For last config, look in plugin root directory
    plugin_dir = fileparts(fileparts(mfilename('fullpath')));
    filename = fullfile(plugin_dir, filename);
end

try
    loaded = load(filename);
    if isfield(loaded, 'config')
        config = loaded.config;
        fprintf('Label configuration loaded from: %s\n', filename);
    else
        error('Invalid configuration file format');
    end
catch ME
    error('Failed to load label configuration: %s', ME.message);
end
end 