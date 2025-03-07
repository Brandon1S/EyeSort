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
    hFig = figure('Name','Load EEG Datasets',...
                  'NumberTitle','off',...
                  'MenuBar','none',...
                  'ToolBar','none',...
                  'Color',[0.94 0.94 0.94], ...
                  'Resize', 'off');
    
    % Create filter GUI
    geomhoriz = { ...
        1 ...
        [2 1] ...
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
        {'Style','listbox','String',regionNames, 'Max', length(regionNames), 'Min', 0, 'tag','lstTimeLocked'}, ...
        ...
        {'Style','text','String','Time Window:'}, ...
        {'Style','popupmenu','String',{'Any time', 'Custom range...'}, 'tag','popTimeWindow', 'callback', @time_window_callback}, ...
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
    
    % GUI callback functions
    function time_window_callback(src, ~)
        if get(src, 'Value') == 2 % Custom range selected
            % Prompt for time range
            prompt = {'Start time (ms):', 'End time (ms):'};
            dlgtitle = 'Enter Time Window';
            dims = [1 35];
            definput = {'0', '1000'};
            answer = inputdlg(prompt, dlgtitle, dims, definput);
            
            if ~isempty(answer)
                % Store the values in a hidden field or tag for later use
                setappdata(gcf, 'timeWindowStart', str2double(answer{1}));
                setappdata(gcf, 'timeWindowEnd', str2double(answer{2}));
            else
                % Reset to "Any time" if canceled
                set(src, 'Value', 1);
            end
        end
    end
    
    function cancel_button(~,~)
        close(gcf);
    end
    
    function apply_filter(~,~)
        % Get selected filter options
        selectedTimeLockedRegions = get(findobj('tag','lstTimeLocked'), 'Value');
        
        timeWindowOption = get(findobj('tag','popTimeWindow'), 'Value');
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
        timeLockedRegionValues = regionNames(selectedTimeLockedRegions);
        
        % Get time window values if custom range was selected
        timeWindowStart = [];
        timeWindowEnd = [];
        if timeWindowOption == 2
            timeWindowStart = getappdata(gcf, 'timeWindowStart');
            timeWindowEnd = getappdata(gcf, 'timeWindowEnd');
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
        
        % Apply the filter
        try
            filteredEEG = filter_dataset(EEG, conditionSet, itemSet, timeLockedRegionValues, ...
                                        timeWindowOption, timeWindowStart, timeWindowEnd, ...
                                        passIndexOption, prevRegion, nextRegion, ...
                                        fixationTypeOption, saccadeDirectionOption);
            
            % Update the EEG in base workspace
            assignin('base', 'EEG', filteredEEG);
            
            % Update command string for history
            com = sprintf('EEG = pop_filter_datasets(EEG); %% Applied advanced filtering');
            
            % Close GUI, redraw EEGLAB
            close(gcf);
            eeglab('redraw');
        catch ME
            errordlg(['Error applying filter: ' ME.message], 'Error');
        end
    end
end

function filteredEEG = filter_dataset(EEG, conditions, items, timeLockedRegions, ...
                                     timeWindowOption, timeWindowStart, timeWindowEnd, ...
                                     passIndexOption, prevRegion, nextRegion, ...
                                     fixationTypeOption, saccadeDirectionOption)
    % Create a copy of the EEG structure
    filteredEEG = EEG;
    
    % Initialize logical mask for which events to keep
    keepEvent = false(size(EEG.event));
    
    % Apply filtering criteria
    for i = 1:length(EEG.event)
        evt = EEG.event(i);
        
        % Skip non-fixation events
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
        
        % Skip events that don't match previously selected conditions/items
        if ~passesCondition || ~passesItem
            continue;
        end
        
        % Time-locked region filter (primary filter)
        passesTimeLockedRegion = true;
        if ~isempty(timeLockedRegions) && isfield(evt, 'current_region')
            passesTimeLockedRegion = any(strcmp(evt.current_region, timeLockedRegions));
        end
        
        % Skip events that don't match the time-locked region
        if ~passesTimeLockedRegion
            continue;
        end
        
        % Time window filtering
        passesTimeWindow = true;
        if timeWindowOption == 2 && isfield(evt, 'latency')
            eventTime = evt.latency / EEG.srate * 1000; % Convert to ms
            passesTimeWindow = (eventTime >= timeWindowStart && eventTime <= timeWindowEnd);
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
        if ~isempty(nextRegion) && i < length(EEG.event) && isfield(EEG.event(i+1), 'current_region')
            passesNextRegion = strcmp(EEG.event(i+1).current_region, nextRegion);
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
        
        % Keep event if it passes all filters
        keepEvent(i) = passesTimeWindow && passesPassIndex && ...
                       passesPrevRegion && passesNextRegion && ...
                       passesFixationType && passesSaccadeDirection;
    end
    
    % Filter events
    filteredEEG.event = EEG.event(keepEvent);
    
    % Update event count if that field exists
    if isfield(filteredEEG, 'eventcounter')
        filteredEEG.eventcounter = length(filteredEEG.event);
    end
    
    % Return the filtered dataset
    return;
end 