function currvers = eegplugin_eyesort(fig, ~, ~)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %    EyeSort Plugin for EEGLAB:       %
    %        Main setup function          %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Call the default values script to intialize global variables
    eyesort_default_values;
    
    % Clear any lingering batch processing variables from previous sessions
    try
        evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_output_dir eyesort_batch_mode');
    catch
        % Variables might not exist, which is fine
    end
    
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
                             'separator', 'on', 'Callback', @(~,~) update_eyesort_menu_state(), ...
                             'userdata', 'startup:on;continuous:on;epoch:on;study:on;erpset:on');
            
            % Store version number in a more accessible way
            setappdata(submenu, 'EyeSortVersion', eyesortver);
            
            % Add version as first item in the dropdown menu
            uimenu(submenu, 'label', ['*** EyeSort v' eyesortver ' ***'], 'enable', 'off', ...
                   'separator', 'on');
            
            % Store main submenu handle for menu state updates
            setappdata(0, 'EyeSort_MainMenu', submenu);
            
            % Add error checking for callbacks
            uimenu(submenu, 'label', '1. Load EEG Dataset(s)', 'separator', 'on', ...
                   'callback', @(src,event) try_callback(@pop_load_datasets, src, event));
            
            % Improve menu structure with error handling
            loadInterestAreasMenu = uimenu(submenu, 'Label', '2. Setup Interest Areas', ...
                'separator', 'off', 'Tag', 'EyeSort_LoadIA', 'enable', 'off', ...
                'userdata', 'startup:on;continuous:on;epoch:on;study:on;erpset:on');
            
            uimenu(loadInterestAreasMenu, 'Label', 'Text-Based Sentence Contents and Interest Areas', ...
                'Tag', 'EyeSort_TextIA', 'enable', 'off', ...
                'callback', @(src,event) try_callback(@pop_load_text_ia, src, event));
            
            uimenu(loadInterestAreasMenu, 'Label', 'Pixel-Based Interest Areas', 'separator', 'on', ...
                'Tag', 'EyeSort_PixelIA', 'enable', 'off', ...
                'callback', @(src,event) try_callback(@pop_load_pixel_ia, src, event));

            % Add the new label datasets menu item
uimenu(submenu, 'label', '3. Eye-Event Labeling', 'separator', 'off', ...
'callback', @(src,event) try_callback(@pop_label_datasets, src, event));
            
            % Add the new BDF generator menu item
            uimenu(submenu, 'label', 'Generate BINLISTER BDF File', 'separator', 'on', ...
                'callback', @(src,event) try_callback(@pop_generate_bdf, src, event));
            
            % Add menu item to save labeled datasets
uimenu(submenu, 'label', 'Save Labeled Dataset', 'separator', 'on', ...
'callback', @(src,event) try_callback(@save_all_labeled_datasets, src, event));
            
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
        % Update menu state after successful operations (especially dataset loading)
        update_eyesort_menu_state();
    catch ME
        errordlg(sprintf('Error in EyeSort operation: %s', ME.message), 'EyeSort Error');
        rethrow(ME);
    end
end

% Function to update EyeSort menu state based on loaded datasets
function update_eyesort_menu_state()
    try
        % Get the main menu handle
        mainMenu = getappdata(0, 'EyeSort_MainMenu');
        if isempty(mainMenu) || ~ishandle(mainMenu)
            return;
        end
        
        % Find the Load Interest Areas menu
        loadIAMenu = findobj(mainMenu, 'Tag', 'EyeSort_LoadIA');
        if isempty(loadIAMenu)
            return;
        end
        
        % Check if datasets are loaded (either in ALLEEG or batch mode)
        hasDatasets = false;
        
        % First check for batch mode
        try
            batchMode = evalin('base', 'eyesort_batch_mode');
            batchFilePaths = evalin('base', 'eyesort_batch_file_paths');
            if ~isempty(batchMode) && batchMode && ~isempty(batchFilePaths) && length(batchFilePaths) >= 1
                hasDatasets = true;
            end
        catch
            % Batch mode variables don't exist, continue to check ALLEEG
        end
        
        % If not in batch mode, check ALLEEG for individual datasets
        if ~hasDatasets
            try
                ALLEEG = evalin('base', 'ALLEEG');
                if ~isempty(ALLEEG) && length(ALLEEG) >= 1
                    % Check if at least one dataset has actual data AND filename
                    for i = 1:length(ALLEEG)
                        if ~isempty(ALLEEG(i)) && isstruct(ALLEEG(i)) && ...
                           isfield(ALLEEG(i), 'data') && ~isempty(ALLEEG(i).data) && ...
                           isfield(ALLEEG(i), 'nbchan') && ALLEEG(i).nbchan > 0 && ...
                           isfield(ALLEEG(i), 'filename') && ~isempty(ALLEEG(i).filename) && ...
                           ~strcmp(ALLEEG(i).filename, '')
                            hasDatasets = true;
                            break;
                        end
                    end
                end
            catch
                % ALLEEG doesn't exist or can't be accessed
                hasDatasets = false;
            end
        end
        
        % Enable/disable Load Interest Areas menu based on dataset state
        if hasDatasets
            set(loadIAMenu, 'enable', 'on');
            % Enable text IA submenu
            textIAMenu = findobj(mainMenu, 'Tag', 'EyeSort_TextIA');
            if ~isempty(textIAMenu), set(textIAMenu, 'enable', 'on'); end
        else
            set(loadIAMenu, 'enable', 'off');
            % Disable text IA submenu
            textIAMenu = findobj(mainMenu, 'Tag', 'EyeSort_TextIA');
            if ~isempty(textIAMenu), set(textIAMenu, 'enable', 'off'); end
        end
        
        % Always keep pixel IA disabled (not implemented)
        pixelIAMenu = findobj(mainMenu, 'Tag', 'EyeSort_PixelIA');
        if ~isempty(pixelIAMenu), set(pixelIAMenu, 'enable', 'off'); end
        
    catch ME
        % Silently handle errors to avoid disrupting the plugin
        warning('EyeSort:MenuUpdate', 'Failed to update menu state: %s', ME.message);
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
