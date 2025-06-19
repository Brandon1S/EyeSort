function config = load_filter_config(filename)
% LOAD_FILTER_CONFIG - Load filter configuration from file
%
% Usage:
%   config = load_filter_config(filename)
%
% Inputs:
%   filename - Input filename (optional, will show file dialog if not provided)
%
% Outputs:
%   config - Filter configuration structure

if nargin < 1
    [filename, filepath] = uigetfile('*.mat', 'Load Filter Configuration');
    if isequal(filename, 0)
        config = [];
        return;
    end
    filename = fullfile(filepath, filename);
elseif strcmp(filename, 'last_filter_config.mat')
    % For last config, look in plugin root directory
    plugin_dir = fileparts(fileparts(mfilename('fullpath')));
    filename = fullfile(plugin_dir, filename);
end

try
    loaded = load(filename);
    if isfield(loaded, 'config')
        config = loaded.config;
        fprintf('Filter configuration loaded from: %s\n', filename);
    else
        error('Invalid configuration file format');
    end
catch ME
    error('Failed to load filter configuration: %s', ME.message);
end
end 