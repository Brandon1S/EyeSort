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
        save(filename, 'config');
        fprintf('Text IA configuration saved to: %s\n', filename);
        
        % Also save as "last_text_ia_config.mat" for quick access
        save('last_text_ia_config.mat', 'config');
        
        % Return success (filename is already displayed in fprintf)
        return;
    catch ME
        error('Failed to save Text IA configuration: %s', ME.message);
    end
end 