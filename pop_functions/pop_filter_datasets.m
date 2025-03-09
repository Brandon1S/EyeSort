function [EEG, com] = pop_filter_datasets(EEG)


% pop_filter_datasets() - A "pop" function to filter datasets based on user-defined criteria
%                        via a GUI dialog.
%
% Usage:
%    >> [EEG, com] = pop_filter_datasets(EEG);
%
% Inputs:
%    EEG  - an EEGLAB EEG structure.
%
% Outputs:
%    EEG  - Updated EEG structure after filtering.
%    com  - Command string for the EEGLAB history.
%

    % ---------------------------------------------------------------------
    % 1) Initialize outputs
    % ---------------------------------------------------------------------
    
    com = '';
    
    % If no EEG input, try to get it from base workspace (EEGLAB convention)
    if nargin < 1
        try
            EEG = evalin('base', 'EEG');
            fprintf('Retrieved EEG from EEGLAB base workspace.\n');
        catch ME
            error('Failed to retrieve EEG dataset from base workspace: %s', ME.message);
        end
    end
    
    % Validate input
    if isempty(EEG)
        error('pop_filter_datasets requires a non-empty EEG dataset');
    end
    
    % Verify that EEG contains processed regions and tracking data
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        errordlg('EEG data does not contain any events.', 'Error');
        return;
    end
    
    % Check if the first event has regionBoundaries field
    if ~isfield(EEG.event(1), 'regionBoundaries')
        errordlg('EEG data is not properly processed with region information. Please process with the Text Interest Areas function first.', 'Error');
        return;
    end
    
    % Initialize or increment the filter count
    if ~isfield(EEG, 'eyesort_filter_count')
        EEG.eyesort_filter_count = 0;
    end
    
    % Extract available filtering options from the data
    % We'll still use condition and item information from the events but won't display them in the GUI
    conditionSet = [];
    itemSet = [];
    regionNames = {};
    
    % Safely extract condition numbers (will be used in filtering but not shown in GUI)
    if isfield(EEG.event, 'condition_number')
        condVals = zeros(1, length(EEG.event));
        for i = 1:length(EEG.event)
            if isfield(EEG.event(i), 'condition_number') && ~isempty(EEG.event(i).condition_number)
                condVals(i) = EEG.event(i).condition_number;
            else
                condVals(i) = NaN;
            end
        end
        conditionSet = unique(condVals(~isnan(condVals) & condVals > 0));
    end
    
    % Safely extract item numbers (will be used in filtering but not shown in GUI)
    if isfield(EEG.event, 'item_number')
        itemVals = zeros(1, length(EEG.event));
        for i = 1:length(EEG.event)
            if isfield(EEG.event(i), 'item_number') && ~isempty(EEG.event(i).item_number)
                itemVals(i) = EEG.event(i).item_number;
            else
                itemVals(i) = NaN;
            end
        end
        itemSet = unique(itemVals(~isnan(itemVals) & itemVals > 0));
    end
    
    % Safely extract region names
    if isfield(EEG.event, 'current_region')
        for i = 1:length(EEG.event)
            if isfield(EEG.event(i), 'current_region') && ~isempty(EEG.event(i).current_region)
                regionNames{end+1} = EEG.event(i).current_region;
            end
        end
        regionNames = unique(regionNames);
    end
    
    % Create empty lists if no values found
    if isempty(conditionSet)
        conditionSet = [];
    end
    
    if isempty(itemSet)
        itemSet = [];
    end
    
    if isempty(regionNames)
        regionNames = {'No regions found'};
    end

    % Create the figure
    hFig = figure('Name','Filter EEG Dataset',...
                  'NumberTitle','off',...
                  'MenuBar','none',...
                  'ToolBar','none',...
                  'Color',[0.94 0.94 0.94], ...
                  'Resize', 'off');
    
    % Create filter GUI with time window option removed
    geomhoriz = { ...
        1 ...
        [2 1] ...
        [2 1] ...
        [2 1] ...
        [2 1] ...
        [2 1] ...
        [2 1] ...
        1 ...
        [0.5 0.2 0.2] ...
    };

    uilist = { ...
        {'Style','text','String','Filter Dataset Options', 'FontWeight', 'bold'}, ...
        ...
        {'Style','text','String','Time-Locked Region (Select Primary Region):'}, ...
        {'Style','listbox','String', regionNames, 'Max', length(regionNames), 'Min', 0, 'tag','lstTimeLocked'}, ...
        ...
        {'Style','text','String','Pass Index:'}, ...
        {'Style','popupmenu','String',{'Any pass', 'First pass only', 'Not first pass'}, 'tag','popPassIndex'}, ...
        ...
        {'Style','text','String','Previous Region:'}, ...
        {'Style','popupmenu','String',['Any region', regionNames], 'tag','popPrevRegion'}, ...
        ...
        {'Style','text','String','Next Region:'}, ...
        {'Style','popupmenu','String',['Any region', regionNames], 'tag','popNextRegion'}, ...
        ...
        {'Style','text','String','Fixation Type:'}, ...
        {'Style','popupmenu','String',{'Any fixation', 'First in region', 'Single fixation', 'Multiple fixations'}, 'tag','popFixationType'}, ...
        ...
        {'Style','text','String','Saccade Direction:'}, ...
        {'Style','popupmenu','String',{'Any direction', 'Forward only', 'Backward only'}, 'tag','popSaccadeDirection'}, ...
        ...
        {}, ...
        ...
        {}, ...
        {'Style', 'pushbutton', 'String', 'Cancel', 'callback', @(~,~) cancel_button}, ...
        {'Style', 'pushbutton', 'String', 'Apply Filter', 'callback', @(~,~) apply_filter}, ...
    };

    % Create the GUI
    [~, ~, ~, ~] = supergui('fig', hFig,'geomhoriz', geomhoriz, 'uilist', uilist, 'title', 'Filter Dataset');
    
    % GUI callback functions - time_window_callback removed
    function cancel_button(~,~)
        close(gcf);
    end
    
    function apply_filter(~,~)
        % Get selected filter options
        selectedTimeLockedRegions = get(findobj('tag','lstTimeLocked'), 'Value');
        
        passIndexOption = get(findobj('tag','popPassIndex'), 'Value');
        prevRegionOption = get(findobj('tag','popPrevRegion'), 'Value');
        nextRegionOption = get(findobj('tag','popNextRegion'), 'Value');
        fixationTypeOption = get(findobj('tag','popFixationType'), 'Value');
        saccadeDirectionOption = get(findobj('tag','popSaccadeDirection'), 'Value');
        
        % Check if valid selections were made
        if strcmp(regionNames{1}, 'No regions found')
            errordlg('Cannot apply filter: Missing region data in current EEG structure.', 'Error');
            return;
        end
        
        % Convert selections to actual values
        timeLockedRegionValues = cell(1, length(selectedTimeLockedRegions));
        for i = 1:length(selectedTimeLockedRegions)
            timeLockedRegionValues{i} = regionNames{selectedTimeLockedRegions(i)};
        end
        
        % Get previous/next region values
        prevRegion = '';
        if prevRegionOption > 1
            prevRegion = regionNames{prevRegionOption-1};
        end
        
        nextRegion = '';
        if nextRegionOption > 1
            nextRegion = regionNames{nextRegionOption-1};
        end
        
        % Increment the filter count for this dataset
        EEG.eyesort_filter_count = EEG.eyesort_filter_count + 1;
        currentFilterCount = EEG.eyesort_filter_count;
        
        % Apply the filter
        try
            filteredEEG = filter_dataset(EEG, conditionSet, itemSet, timeLockedRegionValues, ...
                                        passIndexOption, prevRegion, nextRegion, ...
                                        fixationTypeOption, saccadeDirectionOption, currentFilterCount);
            
            % Store the filter count back to the filtered dataset
            filteredEEG.eyesort_filter_count = currentFilterCount;
            
            % Store descriptive info about this filter for future BDF generation
            if ~isfield(filteredEEG, 'eyesort_filter_descriptions')
                filteredEEG.eyesort_filter_descriptions = {};
            end
            
            % Build a description of this filter
            filterDesc = struct();
            filterDesc.filter_number = currentFilterCount;
            filterDesc.filter_code = sprintf('%02d', currentFilterCount);
            filterDesc.regions = timeLockedRegionValues;
            filterDesc.pass_type = get(findobj('tag','popPassIndex'), 'String');
            filterDesc.pass_value = passIndexOption;
            filterDesc.prev_region = prevRegion;
            filterDesc.next_region = nextRegion;
            filterDesc.fixation_type = get(findobj('tag','popFixationType'), 'String');
            filterDesc.fixation_value = fixationTypeOption;
            filterDesc.saccade_dir = get(findobj('tag','popSaccadeDirection'), 'String');
            filterDesc.saccade_value = saccadeDirectionOption;
            
            % Add timestamp
            filterDesc.timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
            
            % Append to the filter descriptions
            filteredEEG.eyesort_filter_descriptions{end+1} = filterDesc;
            
            % Update the EEG in base workspace
            assignin('base', 'EEG', filteredEEG);
            
            % Update command string for history
            com = sprintf('EEG = pop_filter_datasets(EEG); %% Applied filter #%d', currentFilterCount);
            
            % Notify user of successful filtering
            % Create a more descriptive message
            msgStr = sprintf(['Filter #%d applied successfully!\n\n', ...
                             'Identified %d events matching your filter criteria.\n\n', ...
                             'These events have been labeled with a 6-digit code format: CCRRFF\n', ...
                             'Where: CC = condition code, RR = region code, FF = filter code (%02d)\n\n', ...
                             'These codes will be used for BDF generation.\n\n', ...
                             'Note: This message will remain visible for 5 seconds.\n', ...
                             'See the MATLAB command window for more details.'], ...
                             currentFilterCount, filteredEEG.eyesort_last_filter_matched_count, currentFilterCount);
            
            % Create a message box that won't close automatically
            hMsg = msgbox(msgStr, 'Filter Coding Complete', 'help');
            
            % Get the handle to the OK button in the message box
            hBtn = findobj(hMsg, 'Type', 'UIControl', 'Style', 'pushbutton');
            if ~isempty(hBtn)
                % Make it bigger and more noticeable
                set(hBtn, 'FontWeight', 'bold', 'FontSize', 10);
            end
            
            % Print detailed information about the filtered codes
            fprintf('\n============== FILTER RESULTS ==============\n');
            fprintf('Filter #%d applied successfully!\n', currentFilterCount);
            fprintf('Identified %d events matching the filter criteria.\n', filteredEEG.eyesort_last_filter_matched_count);
            fprintf('These events have been labeled with 6-digit codes.\n');
            
            % Display some sample codes if any events were matched
            if filteredEEG.eyesort_last_filter_matched_count > 0
                % Find the first few events with the filter code
                sampleCount = 0;
                for i = 1:length(filteredEEG.event)
                    if isfield(filteredEEG.event(i), 'eyesort_filter_code') && ...
                       strcmp(filteredEEG.event(i).eyesort_filter_code, sprintf('%02d', currentFilterCount))
                        fprintf('Event %d: Code = %s (Condition %s, Region %s, Filter %s)\n', ...
                               i, ...
                               filteredEEG.event(i).eyesort_full_code, ...
                               filteredEEG.event(i).eyesort_condition_code, ...
                               filteredEEG.event(i).eyesort_region_code, ...
                               filteredEEG.event(i).eyesort_filter_code);
                        
                        sampleCount = sampleCount + 1;
                        if sampleCount >= 5  % Show up to 5 examples
                            break;
                        end
                    end
                end
                if sampleCount == 0
                    fprintf('No events with filter code %02d found.\n', currentFilterCount);
                end
            end
            fprintf('===========================================\n\n');
            
            % Give the user time to see the message box before closing GUI
            pause(5);
            
            % Close GUI, redraw EEGLAB
            close(gcf);
            
            % Don't automatically close the message box
            % Instead, let the user close it when ready
            % eeglab('redraw');
        catch ME
            errordlg(['Error applying filter: ' ME.message], 'Error');
        end
    end
end

function filteredEEG = filter_dataset(EEG, conditions, items, timeLockedRegions, ...
                                     passIndexOption, prevRegion, nextRegion, ...
                                     fixationTypeOption, saccadeDirectionOption, filterCount)
    % Create a copy of the EEG structure
    filteredEEG = EEG;
    
    % Create a tracking count for matched events (not for filtering, just for reporting)
    matchedEventCount = 0;
    
    % Create region code mapping - map region names to 2-digit codes
    regionCodeMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    uniqueRegions = unique({EEG.event.current_region});
    
    % Define standard region order with fixed numbering
    standardRegions = {'Beginning', 'PreTarget', 'Target_word', 'Ending'};
    for i = 1:length(standardRegions)
        regionCodeMap(standardRegions{i}) = sprintf('%02d', i);
    end
    
    % Add any additional regions that weren't in the standard list
    nextCode = length(standardRegions) + 1;
    for i = 1:length(uniqueRegions)
        regionName = uniqueRegions{i};
        if ~isempty(regionName) && ~isKey(regionCodeMap, regionName)
            regionCodeMap(regionName) = sprintf('%02d', nextCode);
            nextCode = nextCode + 1;
        end
    end
    
    % Print the region code mapping for verification
    fprintf('\n============ REGION CODE MAPPING ============\n');
    allRegions = keys(regionCodeMap);
    for i = 1:length(allRegions)
        fprintf('  Region "%s" = Code %s\n', allRegions{i}, regionCodeMap(allRegions{i}));
    end
    fprintf('=============================================\n\n');
    
    % Apply filtering criteria
    for i = 1:length(EEG.event)
        evt = EEG.event(i);
        
        % Only process fixation events for potential code updates
        % Non-fixation events remain unchanged
        if ~startsWith(evt.type, 'R_fixation')
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
        
        % Pass index filtering
        passesPassIndex = true;
        if passIndexOption > 1 && isfield(evt, 'is_first_pass_region')
            if passIndexOption == 2 % First pass only
                passesPassIndex = evt.is_first_pass_region;
            elseif passIndexOption == 3 % Not first pass
                passesPassIndex = ~evt.is_first_pass_region;
            end
        end
        
        % Previous region filtering
        passesPrevRegion = true;
        if ~isempty(prevRegion) && isfield(evt, 'previous_region')
            passesPrevRegion = strcmp(evt.previous_region, prevRegion);
        end
        
        % Next region filtering (requires looking ahead)
        passesNextRegion = true;
        if ~isempty(nextRegion)
            % Look ahead to find the next fixation event, not just the next event
            nextFixationFound = false;
            for j = i+1:length(EEG.event)
                if startsWith(EEG.event(j).type, 'R_fixation') && isfield(EEG.event(j), 'current_region')
                    nextFixationFound = true;
                    passesNextRegion = strcmp(EEG.event(j).current_region, nextRegion);
                    break; % Stop after finding the next fixation
                end
            end
            % If no next fixation was found, this can't pass the next region filter
            if ~nextFixationFound
                passesNextRegion = false;
            end
        end
        
        % Fixation type filtering
        passesFixationType = true;
        if fixationTypeOption > 1 && isfield(evt, 'total_fixations_in_region')
            if fixationTypeOption == 2 % First in region
                passesFixationType = evt.total_fixations_in_region == 1;
            elseif fixationTypeOption == 3 % Single fixation
                passesFixationType = evt.total_fixations_in_region == 1 && ...
                                    (~isfield(evt, 'total_fixations_in_word') || evt.total_fixations_in_word == 1);
            elseif fixationTypeOption == 4 % Multiple fixations
                passesFixationType = evt.total_fixations_in_region > 1;
            end
        end
        
        % Saccade direction filtering
        passesSaccadeDirection = true;
        if saccadeDirectionOption > 1 && isfield(evt, 'is_word_regression')
            if saccadeDirectionOption == 2 % Forward only
                passesSaccadeDirection = ~evt.is_word_regression;
            elseif saccadeDirectionOption == 3 % Backward only
                passesSaccadeDirection = evt.is_word_regression;
            end
        end
        
        % Check if the event passes all filters
        passes = passesPassIndex && passesPrevRegion && passesNextRegion && ...
                 passesFixationType && passesSaccadeDirection;
        
        % Add debug information for important events
        if isfield(evt, 'current_region') && any(strcmp(evt.current_region, timeLockedRegions))
            fprintf('\nDebug Info for Event %d (type: %s):\n', i, evt.type);
            fprintf('  Region: %s\n', evt.current_region);
            if isfield(evt, 'is_first_pass_region')
                fprintf('  First Pass: %s\n', mat2str(evt.is_first_pass_region));
            end
            if isfield(evt, 'total_fixations_in_region')
                fprintf('  Total Fixations in Region: %d\n', evt.total_fixations_in_region);
            end
            if isfield(evt, 'previous_region')
                fprintf('  Previous Region: %s\n', evt.previous_region);
            end
            
            % Find the next fixation and report it
            nextFixRegion = 'None';
            for j = i+1:length(EEG.event)
                if startsWith(EEG.event(j).type, 'R_fixation') && isfield(EEG.event(j), 'current_region')
                    nextFixRegion = EEG.event(j).current_region;
                    fprintf('  Next Fixation: Event %d in region %s\n', j, nextFixRegion);
                    break;
                end
            end
            
            % Report filter status
            fprintf('  Filter Results:\n');
            fprintf('    Passes Time-Locked Region: %s\n', mat2str(passesTimeLockedRegion));
            fprintf('    Passes Pass Index: %s\n', mat2str(passesPassIndex));
            fprintf('    Passes Previous Region: %s\n', mat2str(passesPrevRegion));
            fprintf('    Passes Next Region: %s\n', mat2str(passesNextRegion));
            fprintf('    Passes Fixation Type: %s\n', mat2str(passesFixationType));
            fprintf('    Passes Saccade Direction: %s\n', mat2str(passesSaccadeDirection));
            fprintf('    Overall Result: %s\n', mat2str(passes));
        end
        
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
            filterStr = sprintf('%02d', filterCount);
            
            % Combine to create the 6-digit code
            newType = sprintf('%s%s%s', condStr, regionStr, filterStr);
            
            % Update the event type
            filteredEEG.event(i).type = newType;
            
            % Also store the filter information in a more accessible format
            filteredEEG.event(i).eyesort_condition_code = condStr;
            filteredEEG.event(i).eyesort_region_code = regionStr;
            filteredEEG.event(i).eyesort_filter_code = filterStr;
            filteredEEG.event(i).eyesort_full_code = newType;
        end
    end
    
    % Store the number of matched events for reference
    filteredEEG.eyesort_last_filter_matched_count = matchedEventCount;
    
    % Return the filtered dataset with all events intact
    return;
end 