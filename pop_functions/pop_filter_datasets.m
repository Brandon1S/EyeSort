function [EEG, com] = pop_filter_datasets(EEG)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % FILTER DATASETS GUI         %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Initialize output
    com = '';
    
    % Check if we're in batch mode first
    batch_mode = false;
    batchFilePaths = {};
    batchFilenames = {};
    outputDir = '';
    
    try
        batch_mode = evalin('base', 'eyesort_batch_mode');
        if batch_mode
            batchFilePaths = evalin('base', 'eyesort_batch_file_paths');
            batchFilenames = evalin('base', 'eyesort_batch_filenames');
            outputDir = evalin('base', 'eyesort_batch_output_dir');
            fprintf('Batch mode detected: %d datasets ready for filtering\n', length(batchFilePaths));
        end
    catch
        % Not in batch mode, continue with single dataset
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
        error('pop_filter_datasets requires a non-empty EEG dataset');
    end
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        errordlg('EEG data does not contain any events.', 'Error');
        return;
    end
    if ~isfield(EEG.event(1), 'regionBoundaries')
        errordlg('EEG data is not properly processed with region information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    if ~isfield(EEG, 'eyesort_filter_count')
        % Initialize filter count to 0, so first filter will be 01
        EEG.eyesort_filter_count = 0;
    end
    
    % Get event type field names from EEG structure - these must exist
    if ~isfield(EEG, 'eyesort_field_names')
        errordlg('EEG data does not contain field name information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    
    fixationType = EEG.eyesort_field_names.fixationType;
    fixationXField = EEG.eyesort_field_names.fixationXField;
    saccadeType = EEG.eyesort_field_names.saccadeType;
    saccadeStartXField = EEG.eyesort_field_names.saccadeStartXField;
    saccadeEndXField = EEG.eyesort_field_names.saccadeEndXField;
    
    % Extract available filtering options from EEG events
    conditionSet = [];
    itemSet = [];
    
    if isfield(EEG.event, 'condition_number')
        condVals = zeros(1, length(EEG.event));
        for kk = 1:length(EEG.event)
            if isfield(EEG.event(kk), 'condition_number') && ~isempty(EEG.event(kk).condition_number)
                condVals(kk) = EEG.event(kk).condition_number;
            else
                condVals(kk) = NaN;
            end
        end
        conditionSet = unique(condVals(~isnan(condVals) & condVals > 0));
    end
    if isfield(EEG.event, 'item_number')
        itemVals = zeros(1, length(EEG.event));
        for kk = 1:length(EEG.event)
            if isfield(EEG.event(kk), 'item_number') && ~isempty(EEG.event(kk).item_number)
                itemVals(kk) = EEG.event(kk).item_number;
            else
                itemVals(kk) = NaN;
            end
        end
        itemSet = unique(itemVals(~isnan(itemVals) & itemVals > 0));
    end
    
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
    
    % If in batch mode, offer batch processing option first
    if batch_mode
        choice = questdlg(sprintf(['Batch mode detected: %d datasets ready for filtering.\n\n'...
                                  'How would you like to proceed?'], length(batchFilePaths)), ...
                         'Batch Processing Available', ...
                         'Process All Datasets', 'Configure Filters First', 'Cancel', 'Process All Datasets');
        
        if strcmp(choice, 'Cancel')
            com = '';
            return;
        elseif strcmp(choice, 'Process All Datasets')
            % Apply last saved filter configuration to all datasets
            try
                if check_last_filter_config()
                    config = load_filter_config('last_filter_config.mat');
                    [processed_count, com] = batch_apply_filters(batchFilePaths, batchFilenames, outputDir, config);
                    
                                                                    % Clean up temporary files
                        cleanup_temp_files(batchFilePaths);
                        
                        % Clear batch mode after processing
                        evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_output_dir eyesort_batch_mode');
                        
                        msgbox(sprintf('Batch filtering complete!\n\n%d datasets processed and saved.', processed_count), 'Batch Complete');
                    return;
                else
                    msgbox('No previous filter configuration found. Please configure filters first.', 'No Config Found', 'warn');
                end
            catch ME
                errordlg(['Error in batch processing: ' ME.message], 'Batch Error');
            end
        end
        % If "Configure Filters First" was selected, continue with normal GUI
    end

    % Create the figure for the GUI
    hFig = figure('Name','Filter EEG Dataset',...
                  'NumberTitle','off',...
                  'MenuBar','none',...
                  'ToolBar','none',...
                  'Color',[0.94 0.94 0.94], ...
                  'Position', [100 100 680 700]);
    
    % Define the options to be used for checkboxes
    passTypeOptions = {'First pass only', 'Second pass only', 'Third pass and beyond'};
    fixationTypeOptions = {'First in region', 'Single fixation', 'Second of multiple', 'All subsequent fixations', 'Last in region'};
    saccadeInDirectionOptions = {'Forward only', 'Backward only'};
    saccadeOutDirectionOptions = {'Forward only', 'Backward only'};
    
    % Create parts of the layout for non-region sections
    geomhoriz = { ...
        [1 1 1 1], ...        % Filter Dataset Options title
        1, ...                % Configuration management
        [0.33 0.33 0.34], ... % Save config, Load config, Load last config buttons
        1, ...                % Time-Locked Region title
        1, ...                % Time-Locked Region description
    };
    
    uilist = { ...
        {'Style','text','String','Filter Dataset Options:', 'FontWeight', 'bold'}, ...
        {}, ...
        {}, ...
        {}, ...
        ...
        {'Style','text','String','Configuration Management:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','pushbutton','String','Save Filter Config','callback', @save_filter_config_callback}, ...
        {'Style','pushbutton','String','Load Filter Config','callback', @load_filter_config_callback}, ...
        {'Style','pushbutton','String','Load Last Filter Config','callback', @load_last_filter_config_callback}, ...
        ...
        {'Style','text','String','Time-Locked Region Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates the main region of interest for the rest of the filters to be applied.'}, ...
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
        {'Style','text','String','Indicates whether the first-pass fixation on the time-locked region needs to be filtered or all fixations but the first-pass fixation.'}, ...
        ...
        {'Style','checkbox','String', passTypeOptions{1}, 'tag','chkPass1'}, ...
        {'Style','checkbox','String', passTypeOptions{2}, 'tag','chkPass2'}, ...
        {'Style','checkbox','String', passTypeOptions{3}, 'tag','chkPass3'}, ...
        ...
        {'Style','text','String','Previous Region Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates the last different region visited before entering the current region.'}, ...
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
    additionalUIList{end+1} = {'Style','text','String','Indicates the next different region visited after leaving the current region.'};
    
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
        [2 1 1.5 1.5] ...            % Buttons
    }];
    
    additionalUIList = [additionalUIList, { ...
        {'Style','text','String','Fixation Type Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates the exact type of fixation event to be filtered.'}, ...
        ...
        {'Style','checkbox','String', fixationTypeOptions{1}, 'tag','chkFixType1'}, ...
        {'Style','checkbox','String', fixationTypeOptions{2}, 'tag','chkFixType2'}, ...
        {'Style','checkbox','String', fixationTypeOptions{3}, 'tag','chkFixType3'}, ...
        {'Style','checkbox','String', fixationTypeOptions{4}, 'tag','chkFixType4'}, ...
        {'Style','checkbox','String', fixationTypeOptions{5}, 'tag','chkFixType5'}, ...
        ...
        {'Style','text','String','Saccade Direction Selection:', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Indicates the direction of the saccade event to be filtered.'}, ...
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
        {'Style', 'pushbutton', 'String', 'Apply Additional Filter', 'callback', @(~,~) apply_filter}, ...
        {'Style', 'pushbutton', 'String', 'Finish Filtering Process', 'callback', @(~,~) finish_filtering} ...
    }];
    
    % Combine all parts
    geomhoriz = [geomhoriz, additionalGeomHoriz];
    uilist = [uilist, additionalUIList];
    
    % Create the GUI using supergui
    [~, ~, ~, ~] = supergui('fig', hFig, 'geomhoriz', geomhoriz, 'uilist', uilist);
    
    % Center the window
    movegui(hFig, 'center');
    
    % *** Modification: Pause execution until user interaction is complete ***
    uiwait(hFig);  % This will pause the function until uiresume is called

    % Callback for the Cancel button
    function cancel_button(~,~)
        % Set the command to empty to indicate cancellation
        com = '';
        uiresume(gcf);  % Resume execution (release uiwait)
        fprintf('User selected to cancel the filtering process.\n');
        close(gcf);
    end

    % Callback for the Finish button
    function finish_filtering(~,~)
        % Check if we're in batch mode and offer batch processing
        if batch_mode
            choice = questdlg(sprintf(['Apply current filter configuration to all %d datasets?'], length(batchFilePaths)), ...
                             'Batch Processing', 'Yes', 'No', 'Yes');
            
            if strcmp(choice, 'Yes')
                % Collect current filter configuration
                filter_config = collect_filter_gui_settings();
                if ~isempty(filter_config)
                    try
                        [processed_count, batch_com] = batch_apply_filters(batchFilePaths, batchFilenames, outputDir, filter_config);
                        
                        % Clean up temporary files
                        cleanup_temp_files(batchFilePaths);
                        
                        % Clear batch mode after processing
                        evalin('base', 'clear eyesort_batch_file_paths eyesort_batch_filenames eyesort_batch_output_dir eyesort_batch_mode');
                        
                        com = batch_com;
                        uiresume(gcf);
                        close(gcf);
                        
                        msgbox(sprintf('Batch filtering complete!\n\n%d datasets processed and saved.', processed_count), 'Batch Complete');
                        return;
                    catch ME
                        errordlg(['Error in batch processing: ' ME.message], 'Batch Error');
                        return;
                    end
                end
            end
        end
        
        % Apply the current filter if any and then signal completion
        % Check if any region is selected
        regionSelected = false;
        for ii = 1:length(regionCheckboxTags)
            if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                regionSelected = true;
                break;
            end
        end
        
        if ~regionSelected
            % If no regions selected, just finish without applying a filter
            com = sprintf('EEG = pop_filter_datasets(EEG); %% Filtering completed');
            uiresume(gcf);  % Resume execution (release uiwait)
            close(gcf);
        else
            % Apply the current filter and then finish
            apply_filter_internal(true);
        end
    end

    % Callback for the Apply Filter button
    function apply_filter(~,~)
        % Apply the filter but keep the GUI open for further filtering
        apply_filter_internal(false);
    end

    % Save filter configuration callback
    function save_filter_config_callback(~,~)
        config = collect_filter_gui_settings();
        if isempty(config)
            return; % Error occurred in collection
        end
        
        % Prompt user for filename
        [filename, filepath] = uiputfile('*.mat', 'Save Filter Configuration', 'my_filter_config.mat');
        if isequal(filename, 0)
            return; % User cancelled
        end
        
        full_filename = fullfile(filepath, filename);
        
        try
            save_filter_config(config, full_filename);
            msgbox(sprintf('Filter configuration saved successfully to:\n%s', full_filename), 'Save Complete', 'help');
        catch ME
            errordlg(['Error saving filter configuration: ' ME.message], 'Save Error');
        end
    end

    % Load filter configuration callback
    function load_filter_config_callback(~,~)
        try
            config = load_filter_config(); % Will show file dialog
            if isempty(config)
                return; % User cancelled
            end
            
            apply_filter_config_to_gui(config);
            msgbox('Filter configuration loaded successfully!', 'Load Complete', 'help');
        catch ME
            errordlg(['Error loading filter configuration: ' ME.message], 'Load Error');
        end
    end

    % Load last filter configuration callback
    function load_last_filter_config_callback(~,~)
        try
            if ~check_last_filter_config()
                msgbox('No previous filter configuration found. Use "Save Filter Config" first to create a saved configuration.', 'No Previous Config', 'warn');
                return;
            end
            
            config = load_filter_config('last_filter_config.mat');
            apply_filter_config_to_gui(config);
            msgbox('Last filter configuration loaded successfully!', 'Load Complete', 'help');
        catch ME
            errordlg(['Error loading last filter configuration: ' ME.message], 'Load Error');
        end
    end

    % Collect current filter GUI settings
    function config = collect_filter_gui_settings()
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
            config.fixFirstInRegion = get(findobj('tag','chkFixType1'), 'Value');
            config.fixSingleFixation = get(findobj('tag','chkFixType2'), 'Value');
            config.fixSecondMultiple = get(findobj('tag','chkFixType3'), 'Value');
            config.fixAllSubsequent = get(findobj('tag','chkFixType4'), 'Value');
            config.fixLastInRegion = get(findobj('tag','chkFixType5'), 'Value');
            
            % Saccade direction selections
            config.saccadeInForward = get(findobj('tag','chkSaccadeIn1'), 'Value');
            config.saccadeInBackward = get(findobj('tag','chkSaccadeIn2'), 'Value');
            config.saccadeOutForward = get(findobj('tag','chkSaccadeOut1'), 'Value');
            config.saccadeOutBackward = get(findobj('tag','chkSaccadeOut2'), 'Value');
            
            % Store available regions for validation when loading
            config.availableRegions = regionNames;
            
        catch ME
            errordlg(['Error collecting filter GUI settings: ' ME.message], 'Collection Error');
            config = [];
        end
    end

    % Apply filter configuration to GUI
    function apply_filter_config_to_gui(config)
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
                    regionIdx = find(strcmp(regionNames, regionName));
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
                    regionIdx = find(strcmp(regionNames, regionName));
                    if ~isempty(regionIdx)
                        set(findobj('tag', prevRegionCheckboxTags{regionIdx}), 'Value', 1);
                    end
                end
            end
            
            % Apply next region selections
            if isfield(config, 'selectedNextRegions')
                for i = 1:length(config.selectedNextRegions)
                    regionName = config.selectedNextRegions{i};
                    regionIdx = find(strcmp(regionNames, regionName));
                    if ~isempty(regionIdx)
                        set(findobj('tag', nextRegionCheckboxTags{regionIdx}), 'Value', 1);
                    end
                end
            end
            
            % Apply fixation type selections
            if isfield(config, 'fixFirstInRegion')
                set(findobj('tag','chkFixType1'), 'Value', config.fixFirstInRegion);
            end
            if isfield(config, 'fixSingleFixation')
                set(findobj('tag','chkFixType2'), 'Value', config.fixSingleFixation);
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
            
        catch ME
            errordlg(['Error applying filter configuration to GUI: ' ME.message], 'Apply Error');
        end
    end

    % Actual filter implementation - shared by both apply and finish buttons
    function apply_filter_internal(finishAfter)
        % Check if any region is selected
        regionSelected = false;
        for ii = 1:length(regionCheckboxTags)
            if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                regionSelected = true;
                break;
            end
        end
        
        if ~regionSelected
            errordlg('Please select at least one time-locked region to filter on.', 'Error');
            return;
        end
        
        % Collect filter configuration
        filter_config = collect_filter_gui_settings();
        if isempty(filter_config)
            return; % Error occurred in collection
        end
        
        try
            % Convert configuration to parameters for core function
            filter_params = convert_config_to_params_gui(filter_config);
            
            % Apply the filter using the core function
            [filteredEEG, filter_com] = filter_datasets_core(EEG, filter_params{:});
            
            % Update the EEG variable directly
            EEG = filteredEEG;
            
            % Auto-save current filter configuration for future use
            try
                    save_filter_config(filter_config, 'last_filter_config.mat');
            catch
                % Don't fail the main process if auto-save fails
                fprintf('Note: Could not auto-save filter configuration (this is not critical)\n');
            end
            
            assignin('base', 'EEG', filteredEEG);
            com = filter_com;
            
            % Display a message box with filter results
            if filteredEEG.eyesort_last_filter_matched_count > 0
                msgStr = sprintf(['Filter applied successfully!\n\n',...
                                'Identified %d events matching your filter criteria.\n\n',...
                                'These events have been labeled with a 6-digit code: CCRRFF\n',...
                                'Where: CC = condition code, RR = region code, FF = filter code\n\n',...
                                '%s'],...
                                filteredEEG.eyesort_last_filter_matched_count, ...
                                iif(finishAfter, 'Filtering complete!', 'You can now apply another filter or click Finish when done.'));
                
                hMsg = msgbox(msgStr, 'Filter Applied', 'help');
            else
                % Special message for when no events were found
                msgStr = sprintf(['WARNING: Filter applied, but NO EVENTS matched your criteria!\n\n',...
                                'This could be because:\n',...
                                '1. The filter criteria are too restrictive\n',...
                                '2. There is a mismatch between expected event fields and actual data\n',...
                                '3. The events that would match already have filter codes from a previous filter\n\n',...
                                'Consider:\n',...
                                '- Relaxing your criteria\n',...
                                '- Checking for conflicts with existing filters\n',...
                                '- Verifying your dataset contains the expected fields\n\n',...
                                '%s'],...
                                iif(finishAfter, 'Filtering complete!', 'You can modify your filter settings and try again.'));
                
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
                % Reset the time-locked region selection for the next filter
                % but keep other settings
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
            end
        catch ME
            errordlg(['Error applying filter: ' ME.message], 'Error');
        end
    end

    % Convert GUI configuration to parameters for core function
    function filter_params = convert_config_to_params_gui(config)
        filter_params = {};
        
        % Time-locked regions
        if isfield(config, 'selectedRegions') && ~isempty(config.selectedRegions)
            filter_params{end+1} = 'timeLockedRegions';
            filter_params{end+1} = config.selectedRegions;
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
        filter_params{end+1} = 'passOptions';
        filter_params{end+1} = passOptions;
        
        % Previous regions
        if isfield(config, 'selectedPrevRegions') && ~isempty(config.selectedPrevRegions)
            filter_params{end+1} = 'prevRegions';
            filter_params{end+1} = config.selectedPrevRegions;
        end
        
        % Next regions
        if isfield(config, 'selectedNextRegions') && ~isempty(config.selectedNextRegions)
            filter_params{end+1} = 'nextRegions';
            filter_params{end+1} = config.selectedNextRegions;
        end
        
        % Fixation options
        fixationOptions = [];
        if isfield(config, 'fixFirstInRegion') && config.fixFirstInRegion
            fixationOptions(end+1) = 2;
        end
        if isfield(config, 'fixSingleFixation') && config.fixSingleFixation
            fixationOptions(end+1) = 3;
        end
        if isfield(config, 'fixSecondMultiple') && config.fixSecondMultiple
            fixationOptions(end+1) = 4;
        end
        if isfield(config, 'fixAllSubsequent') && config.fixAllSubsequent
            fixationOptions(end+1) = 5;
        end
        if isfield(config, 'fixLastInRegion') && config.fixLastInRegion
            fixationOptions(end+1) = 6;
        end
        if isempty(fixationOptions)
            fixationOptions = 1;
        end
        filter_params{end+1} = 'fixationOptions';
        filter_params{end+1} = fixationOptions;
        
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
        filter_params{end+1} = 'saccadeInOptions';
        filter_params{end+1} = saccadeInOptions;
        
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
        filter_params{end+1} = 'saccadeOutOptions';
        filter_params{end+1} = saccadeOutOptions;
        
        % Add conditions and items
        filter_params{end+1} = 'conditions';
        filter_params{end+1} = conditionSet;
        filter_params{end+1} = 'items';
        filter_params{end+1} = itemSet;
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