function currvers = eegplugin_eyesort(fig, ~, ~)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %    EyeSort Plugin for EEGLAB:       %
    %        Main setup function          %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Call the default values script to intialize global variables
    eyesort_default_values;
    
    % Outlines current version of plugin
    currvers = ['EyeSort v' eyesortver];
    
    % Ensure minimum arguments are met
    if nargin < 3
        error('eegplugin_eyesort requires 3 arguments');
    end

    % Add the to the MATLAB path
    p = which('eegplugin_eyesort', '-all');
    
    % Ensures no duplicates
    if length(p) > 1
        warning('EyeSort:MultiplePaths', ...
                'Multiple EyeSort folders found. Using the first one: %s', p{1});
    end
    
    p = p{1};
    idx = strfind(p, 'eegplugin_eyesort.m');
    
    if ~isempty(idx)
        p = p(1:idx - 1); % Extract the folder path
        addpath(genpath(p)); % Add the path to MATLAB
    
    else
        error('Failed to locate the EyeSort plugin path.');
    end

   % Check if the BinMaster menu already exists
    menuEEGLAB = findobj(fig, 'tag', 'EEGLAB'); % Find EEGLAB main menu
    
    existingMenu = findobj(menuEEGLAB, 'tag', 'EyeSort'); % Check for existing BinMaster menu

    %% Initializes EyeSort to the EEGLAB menu
    if isempty(existingMenu)
        % Create main menu with try-catch for better error handling
        try
            submenu = uimenu(menuEEGLAB, 'Label', 'EyeSort', 'tag', 'EyeSort', ...
                             'separator', 'on', ...
                             'userdata', 'startup:on;continuous:on;epoch:on;study:on;erpset:on');
            
            % Store version number in a more accessible way
            setappdata(submenu, 'EyeSortVersion', eyesortver);
            
            % Add version as first item in the dropdown menu
            uimenu(submenu, 'label', ['*** EyeSort v' eyesortver ' ***'], 'enable', 'off', ...
                   'separator', 'on');
            
            % Add error checking for callbacks
            uimenu(submenu, 'label', '1. Load EEG Dataset(s)', 'separator', 'on', ...
                   'callback', @(src,event) try_callback(@pop_load_datasets, src, event));
            
            % Improve menu structure with error handling
            loadInterestAreasMenu = uimenu(submenu, 'Label', '2. Load Interest Areas', ...
                'separator', 'off', ...
                'userdata', 'startup:on;continuous:on;epoch:on;study:on;erpset:on');
            
            uimenu(loadInterestAreasMenu, 'Label', 'Load file with text-based sentence contents', ...
                'callback', @(src,event) try_callback(@pop_load_text_ia, src, event));
            
            uimenu(loadInterestAreasMenu, 'Label', 'Load file with IA pixel locations', 'separator', 'on', ...
                'callback', @(src,event) try_callback(@pop_load_pixel_ia, src, event));

            % Add the new filter datasets menu item
            uimenu(submenu, 'label', '3. Filter Dataset(s)', 'separator', 'off', ...
                'callback', @(src,event) try_callback(@pop_filter_datasets, src, event));
            
            % Add the new BDF generator menu item
            uimenu(submenu, 'label', 'Generate BINLISTER BDF File', 'separator', 'on', ...
                'callback', @(src,event) try_callback(@pop_generate_bdf, src, event));
            
            % Add menu item to save filtered datasets
            uimenu(submenu, 'label', 'Save Filtered Datasets', 'separator', 'on', ...
                'callback', @(src,event) try_callback(@save_all_filtered_datasets, src, event));
            
            uimenu(submenu, 'label', 'Help', 'separator', 'on', ...
                   'callback', @(src,event) try_callback(@help_button, src, event));

        catch ME
            error('EyeSort:MenuCreation', 'Failed to create EyeSort menu: %s', ME.message);
        end
    else
        warning('EyeSort:ExistingMenu', 'EyeSort menu already exists. Skipping creation.');
    end
end

% Helper function for safer callback execution
function try_callback(callback_fn, ~, ~)
    try
        callback_fn();
    catch ME
        errordlg(sprintf('Error in EyeSort operation: %s', ME.message), 'EyeSort Error');
        rethrow(ME);
    end
end

%{
% Callback for loading EEG datasets
function launch_dataset_loader()
    EEGDatasets = load_datasetsGUI(); % Launch the dataset loader GUI
    if ~isempty(EEGDatasets)
        setappdata(0, 'LoadedEEGDatasets', EEGDatasets); % Store datasets globally
        fprintf('Datasets loaded successfully.\n');
    end
end
%}
