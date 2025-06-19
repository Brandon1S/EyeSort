function config = load_text_ia_config(filename)
    % LOAD_TEXT_IA_CONFIG - Load Text IA configuration from file
    %
    % Input:
    %   filename - optional filename (if not provided, uses file dialog)
    % Output:
    %   config - struct containing Text IA parameters
    
    if nargin < 1 || isempty(filename)
        % Show file dialog
        [fname, fpath] = uigetfile('*.mat', 'Select Text IA Configuration File');
        if isequal(fname, 0)
            config = [];
            return; % User cancelled
        end
        filename = fullfile(fpath, fname);
    elseif strcmp(filename, 'last_text_ia_config.mat')
        % For last config, look in plugin root directory
        plugin_dir = fileparts(fileparts(mfilename('fullpath')));
        filename = fullfile(plugin_dir, filename);
    end
    
    try
        loaded = load(filename);
        if isfield(loaded, 'config') && isfield(loaded.config, 'config_type') && ...
           strcmp(loaded.config.config_type, 'text_ia')
            config = loaded.config;
            fprintf('Text IA configuration loaded from: %s\n', filename);
        else
            error('Invalid Text IA configuration file format');
        end
    catch ME
        error('Failed to load Text IA configuration: %s', ME.message);
    end
end 