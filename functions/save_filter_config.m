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
filter_config_utils('save', config, filename);
end 