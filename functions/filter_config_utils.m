function varargout = filter_config_utils(action, varargin)
% FILTER_CONFIG_UTILS - Utility functions for filter configuration management
%
% Usage:
%   save_filter_config(config, filename)
%   config = load_filter_config(filename)
%   exists = check_last_filter_config()

switch action
    case 'save'
        save_filter_config_internal(varargin{:});
    case 'load'
        varargout{1} = load_filter_config_internal(varargin{:});
    case 'check_last'
        varargout{1} = check_last_filter_config_internal();
    otherwise
        error('Unknown action: %s', action);
end

end

function save_filter_config_internal(config, filename)
% Save filter configuration to file
if nargin < 2
    filename = 'last_filter_config.mat';
end

try
    save(filename, 'config');
    if ~strcmp(filename, 'last_filter_config.mat')
        fprintf('Filter configuration saved to: %s\n', filename);
    end
catch ME
    error('Failed to save filter configuration: %s', ME.message);
end
end

function config = load_filter_config_internal(filename)
% Load filter configuration from file
if nargin < 1
    [filename, filepath] = uigetfile('*.mat', 'Load Filter Configuration');
    if isequal(filename, 0)
        config = [];
        return;
    end
    filename = fullfile(filepath, filename);
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

function exists = check_last_filter_config_internal()
% Check if last filter configuration exists
exists = exist('last_filter_config.mat', 'file') == 2;
end

