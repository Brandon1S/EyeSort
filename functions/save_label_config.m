function save_label_config(config, filename)
% SAVE_LABEL_CONFIG - Save label configuration to file
%
% Usage:
%   save_label_config(config, filename)
%
% Inputs:
%   config   - Label configuration structure
%   filename - Output filename (optional, defaults to 'last_label_config.mat')

if nargin < 2
    filename = 'last_label_config.mat';
end

% For last_label_config.mat, save to plugin root directory
plugin_dir = fileparts(fileparts(mfilename('fullpath')));
is_last_config = strcmp(filename, 'last_label_config.mat');
if is_last_config
    filename = fullfile(plugin_dir, filename);
end

try
    save(filename, 'config');
    if ~is_last_config
        fprintf('Label configuration saved to: %s\n', filename);
    end
catch ME
    error('Failed to save label configuration: %s', ME.message);
end
end 