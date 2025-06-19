function save_text_ia_config(config, filename)
    % SAVE_TEXT_IA_CONFIG - Save Text IA configuration to file
    % 
    % Input:
    %   config - struct containing all Text IA parameters
    %   filename - optional filename (if not provided, uses default)
    
    if nargin < 2 || isempty(filename)
        % Use default filename with timestamp
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        filename = sprintf('eyesort_text_ia_config_%s.mat', timestamp);
    end
    
    % Ensure .mat extension
    if ~endsWith(filename, '.mat')
        filename = [filename '.mat'];
    end
    
    % Add metadata
    config.saved_date = datestr(now);
    config.eyesort_version = 'EyeSort 2025.0.0';
    config.config_type = 'text_ia';
    
    try
        % For last config, save only to plugin root directory
        plugin_dir = fileparts(fileparts(mfilename('fullpath')));
        if strcmp(filename, 'last_text_ia_config.mat')
            save(fullfile(plugin_dir, filename), 'config');
        else
            save(filename, 'config');
            fprintf('Text IA configuration saved to: %s\n', filename);
            
            % Also save as "last_text_ia_config.mat" for quick access in plugin root
            save(fullfile(plugin_dir, 'last_text_ia_config.mat'), 'config');
        end
        
        % Return success (filename is already displayed in fprintf)
        return;
    catch ME
        error('Failed to save Text IA configuration: %s', ME.message);
    end
end 