function [EEG, com] = pop_filter_datasets(EEG)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % FILTER DATASETS SUPERGUI    %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Initialize output
    com = '';
    
    % If no EEG input, try to get it from base workspace
    if nargin < 1
        try
            EEG = evalin('base', 'EEG');
            fprintf('Retrieved EEG from EEGLAB base workspace.\n');
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
        1, ...                % Time-Locked Region title
        1, ...                % Time-Locked Region description
    };
    
    uilist = { ...
        {'Style','text','String','Filter Dataset Options:', 'FontWeight', 'bold'}, ...
        {}, ...
        {}, ...
        {}, ...
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
        
        % Get selected time-locked regions from checkboxes
        selectedRegions = {};
        for ii = 1:length(regionCheckboxTags)
            if get(findobj('tag', regionCheckboxTags{ii}), 'Value') == 1
                selectedRegions{end+1} = regionNames{ii};
            end
        end
        
        % Get checkbox states for pass type options
        passFirstPass = get(findobj('tag','chkPass1'), 'Value');
        passSecondPass = get(findobj('tag','chkPass2'), 'Value');
        passThirdBeyond = get(findobj('tag','chkPass3'), 'Value');
        
        % Get selected previous regions from checkboxes
        selectedPrevRegions = {};
        for ii = 1:length(prevRegionCheckboxTags)
            if get(findobj('tag', prevRegionCheckboxTags{ii}), 'Value') == 1
                selectedPrevRegions{end+1} = regionNames{ii};
            end
        end
        
        % Get selected next regions from checkboxes
        selectedNextRegions = {};
        for ii = 1:length(nextRegionCheckboxTags)
            if get(findobj('tag', nextRegionCheckboxTags{ii}), 'Value') == 1
                selectedNextRegions{end+1} = regionNames{ii};
            end
        end
        
        % Get checkbox states for fixation type options
        fixFirstInRegion = get(findobj('tag','chkFixType1'), 'Value');
        fixSingleFixation = get(findobj('tag','chkFixType2'), 'Value');
        fixSecondMultiple = get(findobj('tag','chkFixType3'), 'Value');
        fixAllSubsequent = get(findobj('tag','chkFixType4'), 'Value');
        fixLastInRegion = get(findobj('tag','chkFixType5'), 'Value');
        
        % Get checkbox states for saccade in direction options
        saccadeInForward = get(findobj('tag','chkSaccadeIn1'), 'Value');
        saccadeInBackward = get(findobj('tag','chkSaccadeIn2'), 'Value');
        
        % Get checkbox states for saccade out direction options
        saccadeOutForward = get(findobj('tag','chkSaccadeOut1'), 'Value');
        saccadeOutBackward = get(findobj('tag','chkSaccadeOut2'), 'Value');
        
        % Create arrays to hold selected options - preallocate maximum size
        passOptions = zeros(1, 3);  % Max 3 options
        passCount = 0;
        if passFirstPass
            passCount = passCount + 1;
            passOptions(passCount) = 2; % First pass only
        end
        if passSecondPass
            passCount = passCount + 1;
            passOptions(passCount) = 3; % Second pass only
        end
        if passThirdBeyond
            passCount = passCount + 1;
            passOptions(passCount) = 4; % Third pass and beyond
        end
        if passCount == 0
            passOptions = 1; % Any pass (default if none selected)
        else
            passOptions = passOptions(1:passCount); % Trim to actual size
        end
        
        fixationOptions = zeros(1, 5);  % Max 5 options
        fixCount = 0;
        if fixFirstInRegion
            fixCount = fixCount + 1;
            fixationOptions(fixCount) = 2; % First in region
        end
        if fixSingleFixation
            fixCount = fixCount + 1;
            fixationOptions(fixCount) = 3; % Single fixation
        end
        if fixSecondMultiple
            fixCount = fixCount + 1;
            fixationOptions(fixCount) = 4; % Second of multiple
        end
        if fixAllSubsequent
            fixCount = fixCount + 1;
            fixationOptions(fixCount) = 5; % All subsequent fixations
        end
        if fixLastInRegion
            fixCount = fixCount + 1;
            fixationOptions(fixCount) = 6; % Last in region
        end
        if fixCount == 0
            fixationOptions = 1; % Any fixation (default if none selected)
        else
            fixationOptions = fixationOptions(1:fixCount); % Trim to actual size
        end
        
        saccadeInOptions = zeros(1, 2);  % Max 2 options
        saccInCount = 0;
        if saccadeInForward
            saccInCount = saccInCount + 1;
            saccadeInOptions(saccInCount) = 2; % Forward only
        end
        if saccadeInBackward
            saccInCount = saccInCount + 1;
            saccadeInOptions(saccInCount) = 3; % Backward only
        end
        if saccInCount == 0
            saccadeInOptions = 1; % Any direction (default if none selected)
        else
            saccadeInOptions = saccadeInOptions(1:saccInCount);
        end
        
        saccadeOutOptions = zeros(1, 2);  % Max 2 options
        saccOutCount = 0;
        if saccadeOutForward
            saccOutCount = saccOutCount + 1;
            saccadeOutOptions(saccOutCount) = 2; % Forward only
        end
        if saccadeOutBackward
            saccOutCount = saccOutCount + 1;
            saccadeOutOptions(saccOutCount) = 3; % Backward only
        end
        if saccOutCount == 0
            saccadeOutOptions = 1; % Any direction (default if none selected)
        else
            saccadeOutOptions = saccadeOutOptions(1:saccOutCount);
        end
        
        % Increment filter count and update EEG
        EEG.eyesort_filter_count = EEG.eyesort_filter_count + 1;
        currentFilterCount = EEG.eyesort_filter_count;
        
        try
            filteredEEG = filter_dataset(EEG, conditionSet, itemSet, selectedRegions, ...
                                         passOptions, selectedPrevRegions, selectedNextRegions, ...
                                         fixationOptions, saccadeInOptions, saccadeOutOptions, currentFilterCount, ...
                                         fixationType, fixationXField, saccadeType, ...
                                         saccadeStartXField, saccadeEndXField);
            filteredEEG.eyesort_filter_count = currentFilterCount;
            if ~isfield(filteredEEG, 'eyesort_filter_descriptions')
                filteredEEG.eyesort_filter_descriptions = {};
            end
            % Build filter description structure
            filterDesc = struct();
            filterDesc.filter_number = currentFilterCount;
            filterDesc.filter_code = sprintf('%02d', currentFilterCount);
            filterDesc.regions = selectedRegions;
            filterDesc.pass_options = passOptions;
            filterDesc.prev_regions = selectedPrevRegions;
            filterDesc.next_regions = selectedNextRegions;
            filterDesc.fixation_options = fixationOptions;
            filterDesc.saccade_in_options = saccadeInOptions;
            filterDesc.saccade_out_options = saccadeOutOptions;
            filterDesc.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            
            filteredEEG.eyesort_filter_descriptions{end+1} = filterDesc;
            EEG = filteredEEG;  % Update the EEG variable directly
            
            % Ensure we're not causing structure mismatches
            % (This is just a check, though the actual fix is in the batch script)
            if ~isequal(fieldnames(EEG), fieldnames(filteredEEG))
                fprintf('Warning: Field structure mismatch detected in filtered EEG. The batch script will handle this.\n');
            end
            
            assignin('base', 'EEG', filteredEEG);
            com = sprintf('EEG = pop_filter_datasets(EEG); %% Applied filter #%d', currentFilterCount);
            
            % Display a message box with filter results
            if filteredEEG.eyesort_last_filter_matched_count > 0
                msgStr = sprintf(['Filter #%d applied successfully!\n\n',...
                                'Identified %d events matching your filter criteria.\n\n',...
                                'These events have been labeled with a 6-digit code: CCRRFF\n',...
                                'Where: CC = condition code, RR = region code, FF = filter code (%02d)\n\n',...
                                '%s'],...
                                currentFilterCount, filteredEEG.eyesort_last_filter_matched_count, currentFilterCount, ...
                                iif(finishAfter, 'Filtering complete!', 'You can now apply another filter or click Finish when done.'));
                
                hMsg = msgbox(msgStr, sprintf('Filter #%d Applied', currentFilterCount), 'help');
            else
                % Special message for when no events were found
                msgStr = sprintf(['WARNING: Filter #%d applied, but NO EVENTS matched your criteria!\n\n',...
                                'This could be because:\n',...
                                '1. The filter criteria are too restrictive\n',...
                                '2. There is a mismatch between expected event fields and actual data\n',...
                                '3. The events that would match already have filter codes from a previous filter\n\n',...
                                'Consider:\n',...
                                '- Relaxing your criteria\n',...
                                '- Checking for conflicts with existing filters\n',...
                                '- Verifying your dataset contains the expected fields\n\n',...
                                '%s'],...
                                currentFilterCount, ...
                                iif(finishAfter, 'Filtering complete!', 'You can modify your filter settings and try again.'));
                
                hMsg = msgbox(msgStr, sprintf('No Events Found - Filter #%d', currentFilterCount), 'warn');
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

    % Helper function to create an inline if statement (ternary operator)
    function result = iif(condition, trueVal, falseVal)
        if condition
            result = trueVal;
        else
            result = falseVal;
        end
    end
end

function filteredEEG = filter_dataset(EEG, conditions, items, timeLockedRegions, ...
                                     passOptions, prevRegions, nextRegions, ...
                                     fixationOptions, saccadeInOptions, ...
                                     saccadeOutOptions, filterCount, ...
                                     fixationType, fixationXField, saccadeType, ...
                                     saccadeStartXField, saccadeEndXField)
    % Create a copy of the EEG structure
    filteredEEG = EEG;
    
    % Create a tracking count for matched events (not for filtering, just for reporting)
    matchedEventCount = 0;
    
    % Ensure filter count is at least 1 for 1-indexed filter codes
    if filterCount < 1
        filterCount = 1;
    end
    
    % Pre-compute the filter code (always 2 digits, 01-99)
    filterCode = sprintf('%02d', filterCount);
    fprintf('Filter code for this batch: %s\n', filterCode);
    
    % Create region code mapping - map region names to 2-digit codes
    regionCodeMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    
    % Get the unique region names from the EEG events
    if isfield(EEG, 'region_names') && ~isempty(EEG.region_names)
        % Use the regions stored in the EEG structure
        regionList = EEG.region_names;
        if ischar(regionList)
            regionList = {regionList}; % Convert to cell array if it's a string
        end
    else
        % Extract from events
        regionList = unique({EEG.event.current_region});
    end
    
    % Map each region to a 2-digit code
    for kk = 1:length(regionList)
        if ~isempty(regionList{kk}) && ischar(regionList{kk})
            regionCodeMap(regionList{kk}) = sprintf('%02d', kk);
        end
    end
    
    % Print the region code mapping for verification
    fprintf('\n============ REGION CODE MAPPING ============\n');
    if ~isempty(regionCodeMap) && regionCodeMap.Count > 0
        % Print in the original order the regions were added, not in the order keys() returns them
        for kk = 1:length(regionList)
            if ~isempty(regionList{kk}) && ischar(regionList{kk}) && isKey(regionCodeMap, regionList{kk})
                fprintf('  Region "%s" = Code %s\n', regionList{kk}, regionCodeMap(regionList{kk}));
            end
        end
    else
        fprintf('  No regions found to map\n');
    end
    fprintf('=============================================\n\n');
    
    % Track events with conflicting codes
    conflictingEvents = {};
    
    % Apply filtering criteria
    for mm = 1:length(EEG.event)
        evt = EEG.event(mm);
        
        % Check if this is a fixation event or a previously coded fixation event
        % (for previously coded fixation events, the type will be a 6-digit code)
        isFixation = false;
        
        % Check if this event is a fixation or was a fixation (now has a 6-digit code)
        if ischar(evt.type) && startsWith(evt.type, fixationType)
            isFixation = true;
        elseif isfield(evt, 'original_type') && ischar(evt.original_type) && startsWith(evt.original_type, fixationType)
            isFixation = true;
        elseif ischar(evt.type) && length(evt.type) == 6 && isfield(evt, 'eyesort_full_code')
            % This is likely a previously coded fixation event
            isFixation = true;
        end
        
        if ~isFixation
            continue;
        end
        
        % Check if event passes all filtering conditions
        
        % Check for condition and item - these are pre-defined filters from previous GUI
        % We only include events that match the previously selected conditions and items
        passesCondition = true;
        if ~isempty(conditions) && isfield(evt, 'condition_number')
            passesCondition = any(evt.condition_number == conditions);
        end
                          
        passesItem = true;
        if ~isempty(items) && isfield(evt, 'item_number')
            passesItem = any(evt.item_number == items);
        end
        
        % Skip to next event if it doesn't match condition/item criteria
        if ~passesCondition || ~passesItem
            continue;
        end
        
        % Time-locked region filter (primary filter)
        passesTimeLockedRegion = true;
        if ~isempty(timeLockedRegions) && isfield(evt, 'current_region')
            passesTimeLockedRegion = any(strcmp(evt.current_region, timeLockedRegions));
        end
        
        % Skip to next event if it doesn't match time-locked region
        if ~passesTimeLockedRegion
            continue;
        end
        
        % Pass index filtering - modified to handle multiple selection options
        passesPassIndex = false;
        
        % Handle the case where passOptions is a single value (backward compatibility)
        if isscalar(passOptions)
            if passOptions == 1 % Any pass
                passesPassIndex = true;
            elseif passOptions == 2 && isfield(evt, 'is_first_pass_region') % First pass only
                passesPassIndex = evt.is_first_pass_region;
            elseif passOptions == 3 && isfield(evt, 'is_first_pass_region') % Not first pass
                passesPassIndex = ~evt.is_first_pass_region;
            else
                passesPassIndex = true; % Default to true if no valid option or field
            end
        else
            % Handle the case where passOptions is an array of multiple options
            if isempty(passOptions) || any(passOptions == 1) % Any pass included
                passesPassIndex = true;
            else
                % Check each option
                for opt = passOptions
                    if opt == 2 && isfield(evt, 'is_first_pass_region') && evt.is_first_pass_region
                        passesPassIndex = true;
                        break;
                    elseif opt == 3 && isfield(evt, 'is_first_pass_region') && ~evt.is_first_pass_region
                        passesPassIndex = true;
                        break;
                    end
                end
            end
        end
        
        % Previous region filtering
        passesPrevRegion = true;
        if ~isempty(prevRegions)
            passesPrevRegion = any(strcmp(evt.last_region_visited, prevRegions));
        end
        
        % Next region filtering (requires looking ahead)
        passesNextRegion = true;
        if ~isempty(nextRegions)
            % Look ahead to find the next fixation event in a different region
            nextDifferentRegionFound = false;
            currentRegion = evt.current_region;
            
            for jj = mm+1:length(EEG.event)
                % Need to check both original fixation types and coded events
                nextEvt = EEG.event(jj);
                isNextFixation = false;
                
                if ischar(nextEvt.type) && startsWith(nextEvt.type, fixationType)
                    isNextFixation = true;
                elseif isfield(nextEvt, 'original_type') && ischar(nextEvt.original_type) && startsWith(nextEvt.original_type, fixationType)
                    isNextFixation = true;
                elseif ischar(nextEvt.type) && length(nextEvt.type) == 6 && isfield(nextEvt, 'eyesort_full_code')
                    isNextFixation = true;
                end
                
                if isNextFixation && isfield(nextEvt, 'current_region')
                    % Only consider fixations in a different region than the current one
                    if ~strcmp(nextEvt.current_region, currentRegion)
                        nextDifferentRegionFound = true;
                        passesNextRegion = any(strcmp(nextEvt.current_region, nextRegions));
                        break; % Stop after finding the next fixation in a different region
                    end
                end
            end
            % If no next fixation in a different region was found, this can't pass the next region filter
            if ~nextDifferentRegionFound
                passesNextRegion = false;
            end
        end
        
        % Fixation type filtering - modified to handle multiple selection options
        passesFixationType = false;
        
        % Handle the case where fixationOptions is a single value (backward compatibility)
        if isscalar(fixationOptions)
            if fixationOptions == 1 % Any fixation
                passesFixationType = true;
            elseif fixationOptions == 2 && isfield(evt, 'total_fixations_in_region') % First in region
                passesFixationType = evt.total_fixations_in_region == 1;
            elseif fixationOptions == 3 && isfield(evt, 'total_fixations_in_region') % Single fixation
                passesFixationType = evt.total_fixations_in_region == 1 && ...
                                    (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1);
            elseif fixationOptions == 4 && isfield(evt, 'total_fixations_in_region') % Multiple fixations
                passesFixationType = evt.total_fixations_in_region > 1;
            elseif fixationOptions == 5 && isfield(evt, 'total_fixations_in_region') % Last in region
                passesFixationType = evt.total_fixations_in_region == 1 && ...
                                    (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1);
            else
                passesFixationType = true; % Default to true if no valid option or field
            end
        else
            % Handle the case where fixationOptions is an array of multiple options
            if isempty(fixationOptions) || any(fixationOptions == 1) % Any fixation included
                passesFixationType = true;
            else
                % Check each option
                for opt = fixationOptions
                    if opt == 2 && isfield(evt, 'total_fixations_in_region') && evt.total_fixations_in_region == 1
                        passesFixationType = true;
                        break;
                    elseif opt == 3 && isfield(evt, 'total_fixations_in_region') && evt.total_fixations_in_region == 1 && ...
                            (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1)
                        passesFixationType = true;
                        break;
                    elseif opt == 4 && isfield(evt, 'total_fixations_in_region') && evt.total_fixations_in_region > 1
                        passesFixationType = true;
                        break;
                    elseif opt == 5 && isfield(evt, 'total_fixations_in_region') && evt.total_fixations_in_region == 1 && ...
                            (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1)
                        passesFixationType = true;
                        break;
                    end
                end
            end
        end
        
        % Saccade in direction filtering - modified to handle multiple selection options
        passesSaccadeInDirection = false;
        
        % Handle the case where saccadeInOptions is a single value (backward compatibility)
        if isscalar(saccadeInOptions)
            if saccadeInOptions == 1 % Any direction
                passesSaccadeInDirection = true;
            else
                % Find the saccade that led to this fixation
                inSaccadeFound = false;
                for jj = mm-1:-1:1
                    if strcmp(EEG.event(jj).type, saccadeType)
                        inSaccadeFound = true;
                        % Calculate X-direction movement using saccade position data
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        
                        % Check against filter options
                        if saccadeInOptions == 2 % Forward only
                            passesSaccadeInDirection = isForward && abs(xChange) > 10; % Threshold to ignore tiny movements
                        elseif saccadeInOptions == 3 % Backward only
                            passesSaccadeInDirection = ~isForward && abs(xChange) > 10;
                        elseif saccadeInOptions == 4 % Both
                            passesSaccadeInDirection = abs(xChange) > 10;
                        end
                        break;
                    end
                end
                if ~inSaccadeFound && saccadeInOptions < 4
                    passesSaccadeInDirection = false;
                end
            end
        else
            % Handle the case where saccadeInOptions is an array of multiple options
            if isempty(saccadeInOptions) || any(saccadeInOptions == 1) % Any direction included
                passesSaccadeInDirection = true;
            else
                % Find the saccade that led to this fixation
                inSaccadeFound = false;
                xChange = 0;
                isForward = false;
                
                for jj = mm-1:-1:1
                    if strcmp(EEG.event(jj).type, saccadeType)
                        inSaccadeFound = true;
                        % Calculate X-direction movement using saccade position data
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        break;
                    end
                end
                
                if inSaccadeFound && abs(xChange) > 10
                    % Check each option
                    for opt = saccadeInOptions
                        if opt == 2 && isForward % Forward only
                            passesSaccadeInDirection = true;
                            break;
                        elseif opt == 3 && ~isForward % Backward only
                            passesSaccadeInDirection = true;
                            break;
                        elseif opt == 4 % Both
                            passesSaccadeInDirection = true;
                            break;
                        end
                    end
                end
            end
        end
        
        % Saccade out direction filtering - modified to handle multiple selection options
        passesSaccadeOutDirection = false;
        
        % Handle the case where saccadeOutOptions is a single value (backward compatibility)
        if isscalar(saccadeOutOptions)
            if saccadeOutOptions == 1 % Any direction
                passesSaccadeOutDirection = true;
            else
                % Look ahead to find the next saccade event
                outSaccadeFound = false;
                for jj = mm+1:length(EEG.event)
                    if strcmp(EEG.event(jj).type, saccadeType)
                        outSaccadeFound = true;
                        % Calculate X-direction movement using saccade position data
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        
                        % Check against filter options
                        if saccadeOutOptions == 2 % Forward only
                            passesSaccadeOutDirection = isForward && abs(xChange) > 10;
                        elseif saccadeOutOptions == 3 % Backward only
                            passesSaccadeOutDirection = ~isForward && abs(xChange) > 10;
                        elseif saccadeOutOptions == 4 % Both
                            passesSaccadeOutDirection = abs(xChange) > 10;
                        end
                        break;
                    end
                end
                % If no next saccade was found and we're filtering for specific direction
                if ~outSaccadeFound && saccadeOutOptions > 1 && saccadeOutOptions < 4
                    passesSaccadeOutDirection = false;
                end
            end
        else
            % Handle the case where saccadeOutOptions is an array of multiple options
            if isempty(saccadeOutOptions) || any(saccadeOutOptions == 1) % Any direction included
                passesSaccadeOutDirection = true;
            else
                % Look ahead to find the next saccade event
                outSaccadeFound = false;
                xChange = 0;
                isForward = false;
                
                for jj = mm+1:length(EEG.event)
                    if strcmp(EEG.event(jj).type, saccadeType)
                        outSaccadeFound = true;
                        % Calculate X-direction movement using saccade position data
                        xChange = EEG.event(jj).(saccadeEndXField) - EEG.event(jj).(saccadeStartXField);
                        isForward = xChange > 0;
                        break;
                    end
                end
                
                if outSaccadeFound && abs(xChange) > 10
                    % Check each option
                    for opt = saccadeOutOptions
                        if opt == 2 && isForward % Forward only
                            passesSaccadeOutDirection = true;
                            break;
                        elseif opt == 3 && ~isForward % Backward only
                            passesSaccadeOutDirection = true;
                            break;
                        elseif opt == 4 % Both
                            passesSaccadeOutDirection = true;
                            break;
                        end
                    end
                end
            end
        end
        
        % Check if the event passes all filters
        passes = passesPassIndex && passesPrevRegion && passesNextRegion && ...
                 passesFixationType && passesSaccadeInDirection && passesSaccadeOutDirection;
        
        % If the event passes all filters, update its type code
        if passes
            matchedEventCount = matchedEventCount + 1;
            
            % Generate the 6-digit event code:
            
            % 1. First 2 digits: Last two digits of the condition number
            condStr = '';
            if isfield(evt, 'condition_number') && ~isempty(evt.condition_number)
                condNum = evt.condition_number;
                % Extract last two digits (or pad with zeros if needed)
                condStr = sprintf('%02d', mod(condNum, 100));
            else
                condStr = '00'; % Default if no condition number
            end
            
            % 2. Middle 2 digits: Region code
            regionStr = '';
            if isfield(evt, 'current_region') && ~isempty(evt.current_region) && isKey(regionCodeMap, evt.current_region)
                regionStr = regionCodeMap(evt.current_region);
            else
                regionStr = '00'; % Default if no region
            end
            
            % 3. Last 2 digits: Filter code (using the current filter count)
            filterStr = filterCode;
            
            % Combine to create the 6-digit code
            newType = sprintf('%s%s%s', condStr, regionStr, filterStr);
            
            % Store the original type if this is the first time we're coding this event
            if ~isfield(evt, 'original_type')
                filteredEEG.event(mm).original_type = evt.type;
            end
            
            % Check for existing code in the event
            if isfield(evt, 'eyesort_full_code') && ~isempty(evt.eyesort_full_code)
                % If there's an existing code, add to conflicting events
                conflictingEvents{end+1} = struct(...
                    'event_index', mm, ...
                    'existing_code', evt.eyesort_full_code, ...
                    'new_code', newType, ...
                    'condition', evt.condition_number, ...
                    'region', evt.current_region);
            end
            
            % Update the event type and related fields
            filteredEEG.event(mm).type = newType;
            filteredEEG.event(mm).eyesort_condition_code = condStr;
            filteredEEG.event(mm).eyesort_region_code = regionStr;
            filteredEEG.event(mm).eyesort_filter_code = filterStr;
            filteredEEG.event(mm).eyesort_full_code = newType;
        end
    end
    
    % Handle conflicting events if any were found
    if ~isempty(conflictingEvents)
        % Calculate percentage of conflicting events
        conflictPercentage = (length(conflictingEvents) / matchedEventCount) * 100;
        
        % Create a detailed message about the conflicts
        msgStr = sprintf(['Warning: Found %d events with conflicting codes (%.1f%% of matched events).\n\n', ...
                         'This means these events match multiple filter criteria.\n', ...
                         'You have two options:\n\n', ...
                         '1. Keep the new codes (recommended if you want to apply\n', ...
                         '   these filters separately)\n', ...
                         '2. Keep the existing codes\n\n', ...
                         'Recommendation: Consider using a copy of the same EEG dataset and apply these filters separately in case you need to isolate these events and\n', ...
                         'avoid conflicts. You can do this by:\n', ...
                         '1. Clicking "Cancel" now\n', ...
                         '2. Applying one filter to each of the respecting datasets\n', ...
                         '3. Using the "Finish filtering" button after applying the filters separately on two identical datasets\n\n', ...
                         'Would you like to keep the new codes?'], ...
                         length(conflictingEvents), conflictPercentage);
        
        % Show the warning dialog
        choice = questdlg(msgStr, 'Conflicting Event Codes', ...
                         'Keep New Codes', 'Keep Existing Codes', 'Keep New Codes');
        
        if strcmp(choice, 'Keep Existing Codes')
            % Restore the original codes for conflicting events
            for i = 1:length(conflictingEvents)
                idx = conflictingEvents{i}.event_index;
                origCode = conflictingEvents{i}.existing_code;
                filteredEEG.event(idx).type = origCode;
                filteredEEG.event(idx).eyesort_full_code = origCode;
                % Restore the individual components
                filteredEEG.event(idx).eyesort_condition_code = origCode(1:2);
                filteredEEG.event(idx).eyesort_region_code = origCode(3:4);
                filteredEEG.event(idx).eyesort_filter_code = origCode(5:6);
            end
            % Update matched count to exclude restored events
            matchedEventCount = matchedEventCount - length(conflictingEvents);
        end
    end
    
    % Store the number of matched events for reference
    filteredEEG.eyesort_last_filter_matched_count = matchedEventCount;
    
    % Check if no events were found and show a warning
    if matchedEventCount == 0
        warndlg(['No events matched your filter criteria!\n\n'...
                'This could be because:\n'...
                '1. The filter criteria are too restrictive\n'...
                '2. There is a mismatch between expected data structure and actual data\n'...
                '3. The events that would match are already coded with a different filter\n\n'...
                'Consider relaxing your criteria or checking for conflicts with existing filters.'], ...
                'No Matching Events Found!', 'modal');
    end
    
    % Return the filtered dataset with all events intact
    return;
end 