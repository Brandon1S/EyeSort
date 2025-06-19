function save_filter_config(config, filename)
% SAVE_FILTER_CONFIG - Save filter configuration to file
%
% Usage:
%   save_filter_config(config, filename)
%
% Inputs:
%   config   - Filter configuration structure
%   filename - Output filename (optional, defaults to 'last_filter_config.mat')

if nargin < 2
    filename = 'last_filter_config.mat';
end

% For last_filter_config.mat, save to plugin root directory
plugin_dir = fileparts(fileparts(mfilename('fullpath')));
is_last_config = strcmp(filename, 'last_filter_config.mat');
if is_last_config
    filename = fullfile(plugin_dir, filename);
end

try
    save(filename, 'config');
    if ~is_last_config
        fprintf('Filter configuration saved to: %s\n', filename);
    end
catch ME
    error('Failed to save filter configuration: %s', ME.message);
end
end 