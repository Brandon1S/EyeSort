function exists = check_last_label_config()
% CHECK_LAST_LABEL_CONFIG - Check if last label configuration exists
%
% Usage:
%   exists = check_last_filter_config()
%
% Outputs:
%   exists - True if 'last_filter_config.mat' exists, false otherwise

plugin_dir = fileparts(fileparts(mfilename('fullpath')));
exists = exist(fullfile(plugin_dir, 'last_label_config.mat'), 'file') == 2;
end 