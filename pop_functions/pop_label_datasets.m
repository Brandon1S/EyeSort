function [EEG, com] = pop_label_datasets(EEG)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %    LABEL DATASETS GUI      %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Initialize output
    com = '';
    
    % Check if we're in batch mode first
    batch_mode = false;
    batchFilePaths = {};
    batchFilenames = {};
    outputDir = '';
    
    % Track current label number for batch processing
    persistent current_batch_label_count;
    if isempty(current_batch_label_count)
        current_batch_label_count = 0;
    end
    
    try
        batch_mode = evalin('base', 'eyesort_batch_mode');
        if batch_mode
            batchFilePaths = evalin('base', 'eyesort_batch_file_paths');
            batchFilenames = evalin('base', 'eyesort_batch_filenames');
            outputDir = evalin('base', 'eyesort_batch_output_dir');
            fprintf('Batch mode detected: %d datasets ready for labeling\n', length(batchFilePaths));
            
            % Reset label count when starting new batch session
            if current_batch_label_count == 0
                current_batch_label_count = 0;
            end
        end
    catch
        % Not in batch mode, continue with single dataset
        current_batch_label_count = 0;
    end
    
    % If no EEG input, try to get it from base workspace
    if nargin < 1
        try
            if batch_mode
                EEG = pop_loadset('filename', batchFilePaths{1}); % Load first dataset as reference
            
            else
                EEG = evalin('base', 'EEG');
                fprintf('Retrieved EEG from EEGLAB base workspace.\n');
            end
        catch ME
            error('Failed to retrieve EEG dataset from base workspace: %s', ME.message);
        end
    end
    
    % Initialize variables that will be used throughout the function
    regionNames = {};
    
    % Validate input
    if isempty(EEG)
        error('pop_label_datasets requires a non-empty EEG dataset');
    end
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        errordlg('EEG data does not contain any events.', 'Error');
        return;
    end
    if ~isfield(EEG.event(1), 'regionBoundaries')
        errordlg('EEG data is not properly processed with region information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    if ~isfield(EEG, 'eyesort_label_count')
        % Initialize label count to 0, so first label will be 01
        EEG.eyesort_label_count = 0;
    end
    
    % Get event type field names from EEG structure - these must exist
    if ~isfield(EEG, 'eyesort_field_names')
        errordlg('EEG data does not contain field name information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    
    % Note: EEG event validation occurs in the core labeling function
    
    % Extract region names, maintaining user-specified order
    if isfield(EEG, 'region_names') && ~isempty(EEG.region_names)
        % If the dataset has explicitly defined region order, use it
        fprintf('Using region_names field from EEG structure for ordered regions\n');
        regionNames = EEG.region_names;
        if ischar(regionNames)
            regionNames = {regionNames}; % Convert to cell array if it's a string
        end
    else
        % Otherwise extract from events but preserve order of first appearance
        fprintf('No region_names field found, extracting from events and preserving order\n');
        seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        if isfield(EEG.event, 'current_region')
            for kk = 1:length(EEG.event)
                if isfield(EEG.event(kk), 'current_region') && ~isempty(EEG.event(kk).current_region)
                    regionName = EEG.event(kk).current_region;
                    % Only add each region once, preserving order of first appearance
                    if ~isKey(seen, regionName)
                        seen(regionName) = true;
                        regionNames{end+1} = regionName;
                    end
                end
            end
        end
    end
    
    if isempty(regionNames)
        regionNames = {'No regions found'};
    end
    
    % Print regions in order for verification
    fprintf('\nRegions in order (as will be displayed in listbox):\n');
    for m = 1:length(regionNames)
        fprintf('%d. %s\n', m, regionNames{m});
    end
    
    % In batch mode, go directly to GUI - user can load last config if desired
    if batch_mode
        fprintf('Batch mode: %d datasets ready. Use "Load Last Label Config" to reuse previous settings.\n', length(batchFilePaths));
    end

    % Let supergui create and size the figure automatically
    
    % Define the options to be used for checkboxes
    passTypeOptions = {'First pass only', 'Second pass only', 'Third pass and beyond'};
    fixationTypeOptions = {'Single Fixation', 'First of Multiple', 'Second of Multiple', 'All subsequent fixations', 'Last in Region'};
    saccadeInDirectionOptions = {'Forward only', 'Backward only'};
    saccadeOutDirectionOptions = {'Forward only', 'Backward only'};
    
    % Create parts of the layout for non-region sections
    geomhoriz = { ...
        1, ...        % Label Dataset Options title
        1, ...                % Configuration management
        [1 1 1], ... % Save config, Load config, Load last config buttons
        1, ...                % Label Description title
        [0.75 1], ...            % Label Description edit box
        1, ...                % Time-Locked Region title
        1, ...                % Time-Locked Region description
    };
    
    uilist = { ...
        {'Style','text','String','Eye-Tracking Event Labeling Options:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Configuration Management:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','pushbutton','String','Save Label Configuration','callback', @save_label_config_callback}, ...
        {'Style','pushbutton','String','Load Label Configuration','callback', @load_label_config_callback}, ...
        {'Style','pushbutton','String','Load Previous Label Configuration','callback', @load_last_label_config_callback}, ...
        ...
        {'Style','text','String','Label Description:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Description for this label (used in BDF generation):'}, ...
        {'Style','edit','String','','tag','edtLabelDescription','ForegroundColor',[0 0 0]}, ...
        ...
        {'Style','text','String','Time-Locked Region Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates the main region of interest for the rest of the selections to be applied.'}, ...
    };
    
    % Add dynamically generated checkboxes for regions
    numRegions = length(regionNames);
    regionCheckboxTags = cell(1, numRegions);
    
    % Each row will have 5 regions max (or fewer for the last row)
    regionsPerRow = 5;
    numRows = ceil(numRegions / regionsPerRow);
    
    for row = 1:numRows
        % Add geometry for this row
        columnsInRow = min(regionsPerRow, numRegions - (row-1)*regionsPerRow);
        rowGeom = zeros(1, columnsInRow);
        for col = 1:columnsInRow
            rowGeom(col) = 1/columnsInRow;
        end
        geomhoriz{end+1} = rowGeom;
        
        % Add checkboxes for this row
        for col = 1:columnsInRow
            regionIdx = (row-1)*regionsPerRow + col;
            tag = sprintf('chkRegion%d', regionIdx);
            regionCheckboxTags{regionIdx} = tag;
            uilist{end+1} = {'Style','checkbox','String', regionNames{regionIdx}, 'tag', tag};
        end
    end
    
    % Create arrays for previous and next region checkboxes
    prevRegionCheckboxTags = cell(1, numRegions);
    nextRegionCheckboxTags = cell(1, numRegions);
    
    % Continue with the rest of the UI
    additionalGeomHoriz = { ...
        1, ...                 % Pass Type Selection title
        1, ...                % Pass Type Selection Description
        [0.33 0.33 0.34], ...         % Pass type checkboxes
        1, ...                 % Previous Region Navigation title
        1  ...                 % Previous Region Navigation Description
    };
    
    additionalUIList = { ...
        {'Style','text','String','Pass Type Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates what pass the fixation needs to be when fixating on the time-locked region.'}, ...
        ...
        {'Style','checkbox','String', passTypeOptions{1}, 'tag','chkPass1'}, ...
        {'Style','checkbox','String', passTypeOptions{2}, 'tag','chkPass2'}, ...
        {'Style','checkbox','String', passTypeOptions{3}, 'tag','chkPass3'}, ...
        ...
        {'Style','text','String','Previous Region Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates the last region visited prior to entering the time-locking region.'}, ...
    };
    
    % Add Previous Region checkboxes with similar logic
    for row = 1:numRows
        % Add geometry for this row
        columnsInRow = min(regionsPerRow, numRegions - (row-1)*regionsPerRow);
        rowGeom = zeros(1, columnsInRow);
        for col = 1:columnsInRow
            rowGeom(col) = 1/columnsInRow;
        end
        additionalGeomHoriz{end+1} = rowGeom;
        
        % Add checkboxes for this row
        for col = 1:columnsInRow
            regionIdx = (row-1)*regionsPerRow + col;
            tag = sprintf('chkPrevRegion%d', regionIdx);
            prevRegionCheckboxTags{regionIdx} = tag;
            additionalUIList{end+1} = {'Style','checkbox','String', regionNames{regionIdx}, 'tag', tag};
        end
    end
    
    % Add Next Region title and description after Previous Region checkboxes
    additionalGeomHoriz{end+1} = 1;  % Next Region title
    additionalGeomHoriz{end+1} = 1;  % Next Region description
    additionalUIList{end+1} = {'Style','text','String','Next Region Selection:', 'FontWeight', 'bold'};
    additionalUIList{end+1} = {'Style','text','String','Indicates the next region visited after leaving the time-locking region.'};
    
    % Add Next Region checkboxes with similar logic
    for row = 1:numRows
        % Add geometry for this row
        columnsInRow = min(regionsPerRow, numRegions - (row-1)*regionsPerRow);
        rowGeom = zeros(1, columnsInRow);
        for col = 1:columnsInRow
            rowGeom(col) = 1/columnsInRow;
        end
        additionalGeomHoriz{end+1} = rowGeom;
        
        % Add checkboxes for this row
        for col = 1:columnsInRow
            regionIdx = (row-1)*regionsPerRow + col;
            tag = sprintf('chkNextRegion%d', regionIdx);
            nextRegionCheckboxTags{regionIdx} = tag;
            additionalUIList{end+1} = {'Style','checkbox','String', regionNames{regionIdx}, 'tag', tag};
        end
    end
    
    % Add the rest of the UI controls
    additionalGeomHoriz = [additionalGeomHoriz, { ...
        1, ...                       % Fixation Type Selection title
        1, ...                       % Fixation Type Description
        [0.2 0.2 0.2 0.2 0.2], ...   % Fixation type checkboxes
        1, ...                       % Saccade Direction Selection title
        1, ...                       % Saccade Direction Description
        [0.33 0.33 0.33], ...        % Saccade In label and checkboxes
        [0.33 0.33 0.33], ...        % Saccade Out label and checkboxes
        1, ...                       % Spacer
        [1 1 1 1] ...            % Buttons
    }];
    
    additionalUIList = [additionalUIList, { ...
        {'Style','text','String','Fixation Type Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates the exact type of fixation event to be labeled.'}, ...
        ...
        {'Style','checkbox','String', fixationTypeOptions{1}, 'tag','chkFixType1'}, ...
        {'Style','checkbox','String', fixationTypeOptions{2}, 'tag','chkFixType2'}, ...
        {'Style','checkbox','String', fixationTypeOptions{3}, 'tag','chkFixType3'}, ...
        {'Style','checkbox','String', fixationTypeOptions{4}, 'tag','chkFixType4'}, ...
        {'Style','checkbox','String', fixationTypeOptions{5}, 'tag','chkFixType5'}, ...
        ...
        {'Style','text','String','Saccade Direction Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates the direction of the saccade event to be labeled.'}, ...
        ...
        {'Style','text','String','Saccade In:'}, ...
        {'Style','checkbox','String', saccadeInDirectionOptions{1}, 'tag','chkSaccadeIn1'}, ...
        {'Style','checkbox','String', saccadeInDirectionOptions{2}, 'tag','chkSaccadeIn2'}, ...
        ...
        {'Style','text','String','Saccade Out:'}, ...
        {'Style','checkbox','String', saccadeOutDirectionOptions{1}, 'tag','chkSaccadeOut1'}, ...
        {'Style','checkbox','String', saccadeOutDirectionOptions{2}, 'tag','chkSaccadeOut2'}, ...
        ...
        {}, ...
        ...
        {}, ...
        {'Style', 'pushbutton', 'String', 'Cancel', 'callback', @(~,~) cancel_button}, ...
        {'Style', 'pushbutton', 'String', 'Apply Additional Label', 'callback', @(~,~) apply_label}, ...
        {'Style', 'pushbutton', 'String', 'Finish Labeling Process', 'callback', @(~,~) finish_labeling} ...
    }];
    
    % Combine all parts
    geomhoriz = [geomhoriz, additionalGeomHoriz];
    uilist = [uilist, additionalUIList];
    
    % Create the GUI using supergui (let it create and size the figure)
    [~, ~, ~, hFig] = supergui('geomhoriz', geomhoriz, 'uilist', uilist, 'title', 'Label EEG Dataset');
    
    % Bring window to front
    figure(gcf);
    
    % *** Modification: Pause execution until user interaction is complete ***
    uiwait(gcf);  % This will pause the function until uiresume is called

    % Callback for the Cancel button
    function cancel_button(~,~)
        % Set the command to empty to indicate cancellation
        com = '';
        uiresume(gcf);  % Resume execution (release uiwait)
        fprintf('User selected to cancel the labeling process.\n');
        close(gcf);
    end

    % Callback for the Finish button
    function finish_labeling(~,~)
        % Check if we're in batch mode and offer batch processing
        if batch_mode
            % Check if any region is selected for the final label
            regionSelected = false;
            for ii = 1:length(regionCheckboxTags)
                if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                    regionSelected = true;
                    break;
                end
            end
            
            if regionSelected
                % There's a final label to apply - automatically apply to all datasets
                apply_label_internal(true);
                return;
            end
            
            % No final label to apply, just finish
            % Clean up temporary files
            cleanup_temp_files(batchFilePaths);
            
            % Load all processed datasets into ALLEEG for BDF generation
            try
                if ~isempty(outputDir)
                    processedFiles = dir(fullfile(outputDir, '*_processed.set'));
                    if ~isempty(processedFiles)
                        fprintf('Loading %d processed datasets into ALLEEG for BDF generation...\n', length(processedFiles));
                        ALLEEG = [];
                        for i = 1:length(processedFiles)
                            processedPath = fullfile(outputDir, processedFiles(i).name);
                            EEG = pop_loadset('filename', processedPath);
                            [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, i);
                            fprintf('  Loaded: %s\n', processedFiles(i).name);
                        end
                        assignin('base', 'ALLEEG', ALLEEG);
                        assignin('base', 'EEG', EEG); % Last dataset as current
                        assignin('base', 'CURRENTSET', CURRENTSET);
                        fprintf('Successfully loaded %d processed datasets into ALLEEG\n', length(ALLEEG));
                    end
                end
            catch ME
                fprintf('Warning: Could not load processed datasets into ALLEEG: %s\n', ME.message);
            end
            
            % Clear batch mode after processing (keep output dir for BDF generation)
            evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_mode');
            
            com = sprintf('EEG = pop_label_datasets(EEG); %% Batch labeling completed with %d labels applied', current_batch_label_count);
            
            % Show completion message with total events processed and WAIT for user acknowledgment
            total_events_msg = sprintf('Batch labeling complete!\n\n%d labels applied.\n\nAll datasets have been processed and are ready for BDF generation.', current_batch_label_count);
            h_msg = msgbox(total_events_msg, 'Batch Complete');
            waitfor(h_msg); % Wait for user to close the message box
            
            current_batch_label_count = 0; % Reset label count AFTER showing message
            uiresume(gcf);
            close(gcf);
            return;
        end
        
        % Apply the current label if any and then signal completion
        % Check if any region is selected
        regionSelected = false;
        for ii = 1:length(regionCheckboxTags)
            if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                regionSelected = true;
                break;
            end
        end
        
        if ~regionSelected
            % If no regions selected, just finish without applying a label
            com = sprintf('EEG = pop_label_datasets(EEG); %% Labeling completed');
            uiresume(gcf);  % Resume execution (release uiwait)
            close(gcf);
        else
            % Apply the current label and then finish
            apply_label_internal(true);
        end
    end

    % Callback for the Apply Label button
    function apply_label(~,~)
        % Apply the label but keep the GUI open for further labeling
        apply_label_internal(false);
    end

    % Save label configuration callback
    function save_label_config_callback(~,~)
        config = collect_label_gui_settings();
        if isempty(config)
            return; % Error occurred in collection
        end
        
        % Prompt user for filename
        [filename, filepath] = uiputfile('*.mat', 'Save Label Configuration', 'my_label_config.mat');
        figure(gcf); % Bring GUI back to front
        if isequal(filename, 0)
            return; % User cancelled
        end
        
        full_filename = fullfile(filepath, filename);
        
        try
            save_label_config(config, full_filename);
            msgbox(sprintf('Label configuration saved successfully to:\n%s', full_filename), 'Save Complete', 'help');
            figure(gcf); % Bring GUI back to front
        catch ME
            errordlg(['Error saving label configuration: ' ME.message], 'Save Error');
            figure(gcf); % Bring GUI back to front
        end
    end

    % Load label configuration callback
    function load_label_config_callback(~,~)
        try
            config = load_label_config(); % Will show file dialog
            figure(gcf); % Bring GUI back to front
            if isempty(config)
                return; % User cancelled
            end
            
            apply_label_config_to_gui(config);
            msgbox('Label configuration loaded successfully!', 'Load Complete', 'help');
            figure(gcf); % Bring GUI back to front
        catch ME
            errordlg(['Error loading label configuration: ' ME.message], 'Load Error');
            figure(gcf); % Bring GUI back to front
        end
    end

    % Load last label configuration callback
    function load_last_label_config_callback(~,~)
        try
            if ~check_last_label_config()
                msgbox('No previous label configuration found. Use "Save Label Config" first to create a saved configuration.', 'No Previous Config', 'warn');
                figure(gcf); % Bring GUI back to front
                return;
            end
            
            config = load_label_config('last_label_config.mat');
            apply_label_config_to_gui(config);
            msgbox('Last label configuration loaded successfully!', 'Load Complete', 'help');
            figure(gcf); % Bring GUI back to front
        catch ME
            errordlg(['Error loading last label configuration: ' ME.message], 'Load Error');
            figure(gcf); % Bring GUI back to front
        end
    end

    % Collect current label GUI settings
    function config = collect_label_gui_settings()
        config = struct();
        
        try
            % Region selections
            config.selectedRegions = {};
            for ii = 1:length(regionCheckboxTags)
                if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                    config.selectedRegions{end+1} = regionNames{ii};
                end
            end
            
            % Pass type selections
            config.passFirstPass = get(findobj('tag','chkPass1'), 'Value');
            config.passSecondPass = get(findobj('tag','chkPass2'), 'Value');
            config.passThirdBeyond = get(findobj('tag','chkPass3'), 'Value');
            
            % Previous region selections
            config.selectedPrevRegions = {};
            for ii = 1:length(prevRegionCheckboxTags)
                if get(findobj('tag', prevRegionCheckboxTags{ii}), 'Value') == 1
                    config.selectedPrevRegions{end+1} = regionNames{ii};
                end
            end
            
            % Next region selections
            config.selectedNextRegions = {};
            for ii = 1:length(nextRegionCheckboxTags)
                if get(findobj('tag', nextRegionCheckboxTags{ii}), 'Value') == 1
                    config.selectedNextRegions{end+1} = regionNames{ii};
                end
            end
            
            % Fixation type selections
            config.fixSingleFixation = get(findobj('tag','chkFixType1'), 'Value');
            config.fixFirstOfMultiple = get(findobj('tag','chkFixType2'), 'Value');
            config.fixSecondMultiple = get(findobj('tag','chkFixType3'), 'Value');
            config.fixAllSubsequent = get(findobj('tag','chkFixType4'), 'Value');
            config.fixLastInRegion = get(findobj('tag','chkFixType5'), 'Value');
            
            % Saccade direction selections
            config.saccadeInForward = get(findobj('tag','chkSaccadeIn1'), 'Value');
            config.saccadeInBackward = get(findobj('tag','chkSaccadeIn2'), 'Value');
            config.saccadeOutForward = get(findobj('tag','chkSaccadeOut1'), 'Value');
            config.saccadeOutBackward = get(findobj('tag','chkSaccadeOut2'), 'Value');
            
            % Label description
            config.labelDescription = get(findobj('tag','edtLabelDescription'), 'String');
            if iscell(config.labelDescription)
                config.labelDescription = config.labelDescription{1};
            end
            config.labelDescription = strtrim(config.labelDescription); % Trim whitespace from user input
            
            % Store available regions for validation when loading
            config.availableRegions = regionNames;
            
        catch ME
            errordlg(['Error collecting label GUI settings: ' ME.message], 'Collection Error');
            config = [];
        end
    end

    % Apply label configuration to GUI
    function apply_label_config_to_gui(config)
        try
            % Validate that saved regions are compatible with current regions
            if isfield(config, 'availableRegions')
                saved_regions = config.availableRegions;
                if ~isequal(sort(saved_regions), sort(regionNames))
                    warning_msg = sprintf(['Warning: The saved configuration was created with different regions:\n\n'...
                        'Saved regions: %s\n\n'...
                        'Current regions: %s\n\n'...
                        'Region-specific selections may not match exactly.'], ...
                        strjoin(saved_regions, ', '), strjoin(regionNames, ', '));
                    msgbox(warning_msg, 'Region Mismatch Warning', 'warn');
                end
            end
            
            % Clear all current selections first
            % Region selections
            for i = 1:length(regionCheckboxTags)
                set(findobj('tag', regionCheckboxTags{i}), 'Value', 0);
            end
            for i = 1:length(prevRegionCheckboxTags)
                set(findobj('tag', prevRegionCheckboxTags{i}), 'Value', 0);
            end
            for i = 1:length(nextRegionCheckboxTags)
                set(findobj('tag', nextRegionCheckboxTags{i}), 'Value', 0);
            end
            
            % Apply region selections
            if isfield(config, 'selectedRegions')
                for i = 1:length(config.selectedRegions)
                    regionName = config.selectedRegions{i};
                    regionIdx = find(strcmpi(regionNames, regionName));
                    if ~isempty(regionIdx)
                        set(findobj('tag', regionCheckboxTags{regionIdx}), 'Value', 1);
                    end
                end
            end
            
            % Apply pass type selections
            if isfield(config, 'passFirstPass')
                set(findobj('tag','chkPass1'), 'Value', config.passFirstPass);
            end
            if isfield(config, 'passSecondPass')
                set(findobj('tag','chkPass2'), 'Value', config.passSecondPass);
            end
            if isfield(config, 'passThirdBeyond')
                set(findobj('tag','chkPass3'), 'Value', config.passThirdBeyond);
            end
            
            % Apply previous region selections
            if isfield(config, 'selectedPrevRegions')
                for i = 1:length(config.selectedPrevRegions)
                    regionName = config.selectedPrevRegions{i};
                    regionIdx = find(strcmpi(regionNames, regionName));
                    if ~isempty(regionIdx)
                        set(findobj('tag', prevRegionCheckboxTags{regionIdx}), 'Value', 1);
                    end
                end
            end
            
            % Apply next region selections
            if isfield(config, 'selectedNextRegions')
                for i = 1:length(config.selectedNextRegions)
                    regionName = config.selectedNextRegions{i};
                    regionIdx = find(strcmpi(regionNames, regionName));
                    if ~isempty(regionIdx)
                        set(findobj('tag', nextRegionCheckboxTags{regionIdx}), 'Value', 1);
                    end
                end
            end
            
            % Apply fixation options
            if isfield(config, 'fixSingleFixation')
                set(findobj('tag','chkFixType1'), 'Value', config.fixSingleFixation);
            end
            if isfield(config, 'fixFirstOfMultiple')
                set(findobj('tag','chkFixType2'), 'Value', config.fixFirstOfMultiple);
            end
            if isfield(config, 'fixSecondMultiple')
                set(findobj('tag','chkFixType3'), 'Value', config.fixSecondMultiple);
            end
            if isfield(config, 'fixAllSubsequent')
                set(findobj('tag','chkFixType4'), 'Value', config.fixAllSubsequent);
            end
            if isfield(config, 'fixLastInRegion')
                set(findobj('tag','chkFixType5'), 'Value', config.fixLastInRegion);
            end
            
            % Apply saccade direction selections
            if isfield(config, 'saccadeInForward')
                set(findobj('tag','chkSaccadeIn1'), 'Value', config.saccadeInForward);
            end
            if isfield(config, 'saccadeInBackward')
                set(findobj('tag','chkSaccadeIn2'), 'Value', config.saccadeInBackward);
            end
            if isfield(config, 'saccadeOutForward')
                set(findobj('tag','chkSaccadeOut1'), 'Value', config.saccadeOutForward);
            end
            if isfield(config, 'saccadeOutBackward')
                set(findobj('tag','chkSaccadeOut2'), 'Value', config.saccadeOutBackward);
            end
            
            % Apply label description
            if isfield(config, 'labelDescription')
                set(findobj('tag','edtLabelDescription'), 'String', config.labelDescription);
            end
            
        catch ME
            errordlg(['Error applying label configuration to GUI: ' ME.message], 'Apply Error');
        end
    end

    % Actual label implementation - shared by both apply and finish buttons
    function apply_label_internal(finishAfter)
        % Check if any region is selected
        regionSelected = false;
        for ii = 1:length(regionCheckboxTags)
            if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                regionSelected = true;
                break;
            end
        end
        
        if ~regionSelected
            errordlg('Please select at least one time-locked region to label on.', 'Error');
            return;
        end
        
        % Check if label description is provided
        labelDescription = get(findobj('tag','edtLabelDescription'), 'String');
        if iscell(labelDescription)
            labelDescription = labelDescription{1};
        end
        if isempty(strtrim(labelDescription))
            errordlg('Please enter a Label Description before proceeding with labeling.', 'Label Description Required');
            return;
        end
        
        % Collect label configuration
        label_config = collect_label_gui_settings();
        if isempty(label_config)
            return; % Error occurred in collection
        end
        
        try
            % Handle batch mode
            if batch_mode
                % Detect existing labels in first dataset to set proper starting count
                if current_batch_label_count == 0
                    first_dataset = pop_loadset('filename', batchFilePaths{1});
                    if isfield(first_dataset, 'eyesort_label_count') && ~isempty(first_dataset.eyesort_label_count)
                        current_batch_label_count = first_dataset.eyesort_label_count;
                    end
                end
                % Increment label count for batch processing
                current_batch_label_count = current_batch_label_count + 1;
                
                % Apply label to all datasets in batch
                [processed_count, batch_com] = batch_apply_labels_with_count(batchFilePaths, batchFilenames, outputDir, label_config, current_batch_label_count);
                
                if finishAfter
                    % Clean up temporary files
                    cleanup_temp_files(batchFilePaths);
                    
                    % Load all processed datasets into ALLEEG for BDF generation
                    try
                        if ~isempty(outputDir)
                            processedFiles = dir(fullfile(outputDir, '*_processed.set'));
                            if ~isempty(processedFiles)
                                fprintf('Loading %d processed datasets into ALLEEG for BDF generation...\n', length(processedFiles));
                                ALLEEG = [];
                                for i = 1:length(processedFiles)
                                    processedPath = fullfile(outputDir, processedFiles(i).name);
                                    EEG = pop_loadset('filename', processedPath);
                                    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, i);
                                    fprintf('  Loaded: %s\n', processedFiles(i).name);
                                end
                                assignin('base', 'ALLEEG', ALLEEG);
                                assignin('base', 'EEG', EEG); % Last dataset as current
                                assignin('base', 'CURRENTSET', CURRENTSET);
                                fprintf('Successfully loaded %d processed datasets into ALLEEG\n', length(ALLEEG));
                            end
                        end
                    catch ME
                        fprintf('Warning: Could not load processed datasets into ALLEEG: %s\n', ME.message);
                    end
                    
                    % Clear batch mode after processing (keep output dir for BDF generation)
                    evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_mode');
                    
                    com = sprintf('EEG = pop_label_datasets(EEG); %% Batch labeling completed with %d labels applied', current_batch_label_count);
                    
                    % Show completion message with total events processed and WAIT for user acknowledgment
                    total_events_msg = sprintf('Batch labeling complete!\n\n%d datasets processed with %d labels applied.\n\nAll datasets are ready for BDF generation.', length(batchFilePaths), current_batch_label_count);
                    h_msg = msgbox(total_events_msg, 'Batch Complete');
                    waitfor(h_msg); % Wait for user to close the message box
                    
                    current_batch_label_count = 0; % Reset label count AFTER showing message
                    uiresume(gcf);
                    close(gcf);
                    return; % Add missing return to prevent further execution
                    
                else
                    % Show progress message but keep GUI open
                    msgbox(sprintf('Label %02d applied to all %d datasets!\n\nYou can now configure and apply another label.', current_batch_label_count, length(batchFilePaths)), 'Batch Label Applied', 'help');
                    
                    % Reset GUI for next label
                    reset_gui_for_next_label();
                end
                return;
            end
            
            % Single dataset mode - existing logic
            % Convert configuration to parameters for core function
            label_params = convert_config_to_params_gui(label_config);
            
            % Apply the label using the core function
            [labeledEEG, label_com] = label_datasets_core(EEG, label_params{:});
            
            % Update the EEG variable directly
            EEG = labeledEEG;
            
            % Auto-save current label configuration for future use
            try
                    save_label_config(label_config, 'last_label_config.mat');
            catch
                % Don't fail the main process if auto-save fails
                fprintf('Note: Could not auto-save label configuration (this is not critical)\n');
            end
            
            assignin('base', 'EEG', labeledEEG);
            com = label_com;
            
            % Display a message box with label results
            if labeledEEG.eyesort_last_label_matched_count > 0
                msgStr = sprintf(['Label applied successfully!\n\n',...
                                'Identified %d events matching your label criteria.\n\n',...
                                'These events have been labeled with a 6-digit code: CCRRFF\n',...
                                'Where: CC = condition code, RC = region code, LC = label code\n\n',...
                                '%s'],...
                                labeledEEG.eyesort_last_label_matched_count, ...
                                iif(finishAfter, 'Labeling complete!', 'You can now apply another label or click Finish when done.'));
                
                hMsg = msgbox(msgStr, 'Label Applied', 'help');
            else
                % Special message for when no events were found
                msgStr = sprintf(['WARNING: Label applied, but NO EVENTS matched your criteria!\n\n',...
                                'This could be because:\n',...
                                '1. The label criteria are too restrictive\n',...
                                '2. There is a mismatch between expected event fields and actual data\n',...
                                '3. The events that would match already have label codes from a previous label\n\n',...
                                'Consider:\n',...
                                '- Relaxing your criteria\n',...
                                '- Checking for conflicts with existing labels\n',...
                                '- Verifying your dataset contains the expected fields\n\n',...
                                '%s'],...
                                iif(finishAfter, 'Labeling complete!', 'You can modify your label settings and try again.'));
                
                hMsg = msgbox(msgStr, 'No Events Found', 'warn');
            end
            
            hBtn = findobj(hMsg, 'Type', 'UIControl', 'Style', 'pushbutton');
            if ~isempty(hBtn)
                set(hBtn, 'FontWeight', 'bold', 'FontSize', 10);
            end
            
            % Wait for user to click OK instead of auto-closing
            waitfor(hMsg);
            
            if finishAfter
                uiresume(gcf);  % Resume execution to let uiwait finish
                close(gcf);
            else
                % Reset the GUI for next label
                reset_gui_for_next_label();
            end
        catch ME
            errordlg(['Error applying label: ' ME.message], 'Error');
        end
    end

    % Helper function to reset GUI for next label
    function reset_gui_for_next_label()
        % Reset the time-locked region selection for the next label
        for i = 1:length(regionCheckboxTags)
            set(findobj('tag', regionCheckboxTags{i}), 'Value', 0);
        end
        
        % Reset the previous region checkboxes
        for i = 1:length(prevRegionCheckboxTags)
            set(findobj('tag', prevRegionCheckboxTags{i}), 'Value', 0);
        end
        
        % Reset the next region checkboxes
        for i = 1:length(nextRegionCheckboxTags)
            set(findobj('tag', nextRegionCheckboxTags{i}), 'Value', 0);
        end
        
        % Reset the label description
        set(findobj('tag','edtLabelDescription'), 'String', '');
    end

    % Batch apply labels with proper label count tracking
    function [processed_count, com] = batch_apply_labels_with_count(filePaths, fileNames, outputDir, config, labelNum)
        processed_count = 0;
        com = '';
        
        % Create a progress bar
        h = waitbar(0, sprintf('Applying label %02d to batch datasets...', labelNum), 'Name', 'Batch Processing');
        
        try
            for i = 1:length(filePaths)
                waitbar(i/length(filePaths), h, sprintf('Processing %d of %d: %s (Label %02d)', i, length(filePaths), fileNames{i}, labelNum));
                
                try
                    % Generate clean filename once at the start
                    [~, fileName, ~] = fileparts(filePaths{i});
                    % Remove common processing suffixes and temp indicators
                    cleanFileName = regexprep(fileName, '(_temp|_textia|_processed|_labeled)+', '');
                    cleanFileName = regexprep(cleanFileName, '_+', '_'); % Remove multiple underscores  
                    cleanFileName = regexprep(cleanFileName, '^_|_$', ''); % Remove leading/trailing underscores
                    
                    % For first label, load from original path
                    % For subsequent labels, load from output directory (previously labeled version)
                    if labelNum == 1
                        tempEEG = pop_loadset('filename', filePaths{i});
                    else
                        % Load the previously labeled version using the same clean filename
                        previous_file = fullfile(outputDir, [cleanFileName '_processed.set']);
                        if exist(previous_file, 'file')
                            tempEEG = pop_loadset('filename', previous_file);
                        else
                            warning('Previous labeled file not found: %s, using original', previous_file);
                            tempEEG = pop_loadset('filename', filePaths{i});
                        end
                    end
                    
                    % CRITICAL: Preserve existing label count for previously labeled datasets
                    if ~isfield(tempEEG, 'eyesort_label_count')
                        tempEEG.eyesort_label_count = labelNum - 1; % Will be incremented by core function
                    end
                    % For previously labeled datasets, keep existing count (will be incremented by core function)
                    
                    % Verify dataset has required fields for labeling
                    if ~isfield(tempEEG, 'eyesort_field_names') || isempty(tempEEG.eyesort_field_names)
                        warning('Dataset %s missing eyesort_field_names - may not be properly processed', cleanFileName);
                        continue;
                    end
                    
                    % Convert configuration to parameters
                    label_params = convert_config_to_params_gui(config);
                    
                    % Auto-save current label configuration (only once, on first dataset)
                    if i == 1
                        try
                            save_label_config(config, 'last_label_config.mat');
                            fprintf('Auto-saved label configuration to last_label_config.mat\n');
                        catch ME
                            fprintf('Warning: Could not auto-save label configuration: %s\n', ME.message);
                        end
                    end
                    
                    % Apply the label
                    [labeledEEG, ~] = label_datasets_core(tempEEG, label_params{:});
                    
                    % Save with consistent clean name
                    output_path = fullfile(outputDir, [cleanFileName '_processed.set']);
                    pop_saveset(labeledEEG, 'filename', output_path, 'savemode', 'twofiles');
                    
                    % Clear variables to free memory and prevent storage bloat
                    clear tempEEG labeledEEG;
                    % Force MATLAB to clean up memory (if available)
                    try
                        pack;
                    catch
                        % pack not available in this MATLAB version, skip
                    end
                    
                    processed_count = processed_count + 1;
                    fprintf('Successfully processed dataset %d/%d: %s with label %02d\n', processed_count, length(filePaths), cleanFileName, labelNum);
                    
                catch ME
                    warning('Failed to process dataset %s: %s', filePaths{i}, ME.message);
                end
            end
            
            % Close progress bar
            delete(h);
            
            com = sprintf('EEG = pop_label_datasets(EEG); %% Applied label %02d to %d datasets', labelNum, processed_count);
            
        catch ME
            if exist('h', 'var') && ishandle(h)
                delete(h);
            end
            error('Error in batch processing: %s', ME.message);
        end
    end

    % Convert GUI configuration to parameters for core function
    function label_params = convert_config_to_params_gui(config)
        label_params = {};
        
        % Time-locked regions
        if isfield(config, 'selectedRegions') && ~isempty(config.selectedRegions)
            label_params{end+1} = 'timeLockedRegions';
            label_params{end+1} = config.selectedRegions;
        end
        
        % Pass options
        passOptions = [];
        if isfield(config, 'passFirstPass') && config.passFirstPass
            passOptions(end+1) = 2;
        end
        if isfield(config, 'passSecondPass') && config.passSecondPass
            passOptions(end+1) = 3;
        end
        if isfield(config, 'passThirdBeyond') && config.passThirdBeyond
            passOptions(end+1) = 4;
        end
        if isempty(passOptions)
            passOptions = 1;
        end
        label_params{end+1} = 'passOptions';
        label_params{end+1} = passOptions;
        
        % Previous regions
        if isfield(config, 'selectedPrevRegions') && ~isempty(config.selectedPrevRegions)
            label_params{end+1} = 'prevRegions';
            label_params{end+1} = config.selectedPrevRegions;
        end
        
        % Next regions
        if isfield(config, 'selectedNextRegions') && ~isempty(config.selectedNextRegions)
            label_params{end+1} = 'nextRegions';
            label_params{end+1} = config.selectedNextRegions;
        end
        
        % Fixation options
        fixationOptions = [];
        if isfield(config, 'fixSingleFixation') && config.fixSingleFixation
            fixationOptions(end+1) = 1;
        end
        if isfield(config, 'fixFirstOfMultiple') && config.fixFirstOfMultiple
            fixationOptions(end+1) = 2;
        end
        if isfield(config, 'fixSecondMultiple') && config.fixSecondMultiple
            fixationOptions(end+1) = 3;
        end
        if isfield(config, 'fixAllSubsequent') && config.fixAllSubsequent
            fixationOptions(end+1) = 4;
        end
        if isfield(config, 'fixLastInRegion') && config.fixLastInRegion
            fixationOptions(end+1) = 5;
        end
        if isempty(fixationOptions)
            fixationOptions = 0; % Default to "any fixation"
        end
        label_params{end+1} = 'fixationOptions';
        label_params{end+1} = fixationOptions;
        
        % Saccade in options
        saccadeInOptions = [];
        if isfield(config, 'saccadeInForward') && config.saccadeInForward
            saccadeInOptions(end+1) = 2;
        end
        if isfield(config, 'saccadeInBackward') && config.saccadeInBackward
            saccadeInOptions(end+1) = 3;
        end
        if isempty(saccadeInOptions)
            saccadeInOptions = 1;
        end
        label_params{end+1} = 'saccadeInOptions';
        label_params{end+1} = saccadeInOptions;
        
        % Saccade out options
        saccadeOutOptions = [];
        if isfield(config, 'saccadeOutForward') && config.saccadeOutForward
            saccadeOutOptions(end+1) = 2;
        end
        if isfield(config, 'saccadeOutBackward') && config.saccadeOutBackward
            saccadeOutOptions(end+1) = 3;
        end
        if isempty(saccadeOutOptions)
            saccadeOutOptions = 1;
        end
        label_params{end+1} = 'saccadeOutOptions';
        label_params{end+1} = saccadeOutOptions;
        
        % Add conditions and items - these should be empty for batch processing
        % to allow each dataset to determine its own conditions/items
        label_params{end+1} = 'conditions';
        label_params{end+1} = [];
        label_params{end+1} = 'items';
        label_params{end+1} = [];
        
        % Add label description
        if isfield(config, 'labelDescription') && ~isempty(config.labelDescription)
            label_params{end+1} = 'labelDescription';
            label_params{end+1} = config.labelDescription;
        end
    end

    % Helper function to create an inline if statement (ternary operator)
    function result = iif(condition, trueVal, falseVal)
        if condition
            result = trueVal;
        else
            result = falseVal;
        end
    end
end