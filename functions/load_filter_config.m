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
    config = filter_config_utils('load');
else
    config = filter_config_utils('load', filename);
end
end 