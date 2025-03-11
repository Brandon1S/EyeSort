function EEG = combined_compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, ...
                                              conditionColName, itemColName, startCode, endCode, conditionTriggers, itemTriggers)
    % Validate inputs
    if nargin < 12
        error('compute_text_based_ia_word_level: Not enough input arguments.');
    end
    if isempty(EEG)
        error('EEG is empty. Cannot proceed.');
    end
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        error('EEG.event is missing or empty. Cannot proceed without event data.');
    end
    
    % Check file existence
    if ~exist(txtFilePath, 'file')
        error('The file "%s" does not exist.', txtFilePath);
    end
    
    % Check region name counts
    if length(regionNames) ~= numRegions
        error('Number of regionNames (%d) does not match numRegions (%d).', ...
               length(regionNames), numRegions);
    end

    % Debug print for input parameters
    fprintf('Input Parameters:\n');
    fprintf('Offset: %d, Pixels per char: %d\n', offset, pxPerChar);
    fprintf('Number of regions: %d\n', numRegions);
    fprintf('Region names: %s\n', strjoin(regionNames, ', '));
    fprintf('Condition column: %s, Item column: %s\n', conditionColName, itemColName);

    % Read and validate data first
    opts = detectImportOptions(txtFilePath, 'Delimiter', '\t');
    opts.VariableNamingRule = 'preserve'; % Retain the original column names, including '$'
    % For each region column, preserve the whitespace so that leading/trailing spaces remain
    for i = 1:length(regionNames)
        opts = setvaropts(opts, regionNames{i}, 'WhitespaceRule', 'preserve');
    end
    data = readtable(txtFilePath, opts);
    
    % Enhanced check for column existence - this is critical to fix the error
    columnNames = data.Properties.VariableNames;
    fprintf('Data file contains columns: %s\n', strjoin(columnNames, ', '));
    
    % Make sure conditionColName exists in the data
    if ~ismember(conditionColName, columnNames)
        % If the column name doesn't match directly, try to find a similar one
        if ismember(['$' conditionColName], columnNames)
            conditionColName = ['$' conditionColName];
            fprintf('Using column name with $ prefix: %s\n', conditionColName);
        elseif ismember(strrep(conditionColName, '$', ''), columnNames)
            conditionColName = strrep(conditionColName, '$', '');
            fprintf('Using column name without $ prefix: %s\n', conditionColName);
        else
            % Try case-insensitive matching as a last resort
            for i = 1:length(columnNames)
                if strcmpi(columnNames{i}, conditionColName) || ...
                   strcmpi(columnNames{i}, ['$' conditionColName]) || ...
                   strcmpi(columnNames{i}, strrep(conditionColName, '$', ''))
                    conditionColName = columnNames{i};
                    fprintf('Using case-insensitive match for condition column: %s\n', conditionColName);
                    break;
                end
            end
            
            % If we still don't have a match, raise an error
            if ~ismember(conditionColName, columnNames)
                error('Condition column "%s" not found in the data. Available columns: %s', ...
                      conditionColName, strjoin(columnNames, ', '));
            end
        end
    end
    
    % Same check for itemColName
    if ~ismember(itemColName, columnNames)
        % If the column name doesn't match directly, try to find a similar one
        if ismember(['$' itemColName], columnNames)
            itemColName = ['$' itemColName];
            fprintf('Using column name with $ prefix: %s\n', itemColName);
        elseif ismember(strrep(itemColName, '$', ''), columnNames)
            itemColName = strrep(itemColName, '$', '');
            fprintf('Using column name without $ prefix: %s\n', itemColName);
        else
            % Try case-insensitive matching as a last resort
            for i = 1:length(columnNames)
                if strcmpi(columnNames{i}, itemColName) || ...
                   strcmpi(columnNames{i}, ['$' itemColName]) || ...
                   strcmpi(columnNames{i}, strrep(itemColName, '$', ''))
                    itemColName = columnNames{i};
                    fprintf('Using case-insensitive match for item column: %s\n', itemColName);
                    break;
                end
            end
            
            % If we still don't have a match, raise an error
            if ~ismember(itemColName, columnNames)
                error('Item column "%s" not found in the data. Available columns: %s', ...
                      itemColName, strjoin(columnNames, ', '));
            end
        end
    end
    
    % Now safely display the first few rows with the confirmed column names
    try
        fprintf('\nFirst few rows of condition and item data:\n');
        head_data = head(data);
        condValues = head_data.(conditionColName);
        itemValues = head_data.(itemColName);
        for i = 1:length(condValues)
            fprintf('Row %d: Condition = %d, Item = %d\n', i, condValues(i), itemValues(i));
        end
    catch ME
        fprintf('Warning: Error displaying data preview: %s\n', ME.message);
        fprintf('Continuing with processing anyway...\n');
    end
    
    % Initialize mapping containers for storing boundaries
    % boundaryMap: Stores region boundaries for each item/condition combination
    % wordBoundaryMap: Stores word boundaries for each region
    boundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    wordBoundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    % NEW: regionWordsMap: Stores the words for each region for each item/condition combination.
    regionWordsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    % Process each row in the data
    fprintf('Processing %d rows of data...\n', height(data));
    for iRow = 1:height(data)
        try
            key = sprintf('%d_%d', data.(conditionColName)(iRow), data.(itemColName)(iRow));
            
            % Initialize position tracking
            currentPosition = offset;
            regionBoundaries = zeros(numRegions, 2);
            wordBoundaries = containers.Map('KeyType', 'char', 'ValueType', 'any');
            
            % NEW: Initialize a structure to store words in each region
            regionWords = struct();
            
            % Process each region
            for r = 1:numRegions
                regionStart = currentPosition;
                regionText = data.(regionNames{r}){iRow};
                if iscell(regionText)
                    regionText = char(regionText);
                end
                
                % IMPORTANT: Do NOT trim the regionText!
                % This keeps any preceding whitespace intact.
                regionWidth = pxPerChar * length(regionText);
                currentPosition = regionStart + regionWidth;
                
                % Store region boundaries
                regionBoundaries(r,:) = [regionStart, currentPosition];
                
                % Use regexp with a pattern that preserves preceding whitespace.
                % The pattern '(\s*\S+)' returns tokens such that the optional
                % preceding whitespace (if any) is kept together with the word.
                [wordStarts, wordEnds] = regexp(regionText, '(\s*\S+)', 'start', 'end');
                
                % NEW: Extract matching words (with preceding whitespace preserved)
                wordsInRegion = regexp(regionText, '(\s*\S+)', 'match');
                regionWords.(sprintf('region%d_words', r)) = wordsInRegion;

                for idx = 1:length(wordStarts)
                    wordKey = sprintf('%d.%d', r, idx);
                    wordPixelStart = regionStart + (wordStarts(idx) - 1) * pxPerChar;
                    wordPixelEnd   = regionStart + wordEnds(idx) * pxPerChar;
                    wordBoundaries(wordKey) = [wordPixelStart, wordPixelEnd];
                end
                
                % Removed the extra space addition between regions:
                % if r < numRegions
                %     currentPosition = currentPosition + pxPerChar;
                % end
            end
            
            % Store calculated boundaries, word boundaries, and region words in mapping containers
            boundaryMap(key) = regionBoundaries;
            wordBoundaryMap(key) = wordBoundaries;
            regionWordsMap(key) = regionWords;
            
        catch ME
            warning('Error processing row %d: %s', iRow, ME.message);
        end
    end

    fprintf('Processed %d rows\n', height(data));
    
    % Initialize fields
    [EEG.event.regionBoundaries] = deal([]);
    [EEG.event.word_boundaries] = deal([]);
    for r = 1:numRegions
        [EEG.event.(sprintf('region%d_start', r))] = deal(0);
        [EEG.event.(sprintf('region%d_end', r))] = deal(0);
        [EEG.event.(sprintf('region%d_name', r))] = deal('');
        [EEG.event.(sprintf('region%d_words', r))] = deal([]);
    end
    
    % Process EEG events to assign boundaries and determine fixation regions
    fprintf('Processing events...\n');
    numAssigned = 0;

    % Initialize trial tracking variables
    currentItem = [];
    currentCond = [];
    trialRunning = false;
    lastValidKey = '';  % Track the last valid item/condition combination

    % Remove spaces from trigger strings for comparison
    conditionTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), conditionTriggers, 'UniformOutput', false);
    itemTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), itemTriggers, 'UniformOutput', false);

    % First assign boundaries and determine regions
    for iEvt = 1:length(EEG.event)
        eventType = EEG.event(iEvt).type;
        eventTypeNoSpace = strrep(eventType, ' ', '');
        
        if strcmp(eventTypeNoSpace, strrep(startCode, ' ', ''))
            trialRunning = true;
            currentItem = [];
            currentCond = [];
            lastValidKey = '';
        elseif strcmp(eventTypeNoSpace, strrep(endCode, ' ', ''))
            trialRunning = false;
        elseif trialRunning && startsWith(eventType, 'S')
            % Extract condition and item numbers from triggers
            if any(strcmp(eventTypeNoSpace, itemTriggersNoSpace))
                currentItem = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            elseif any(strcmp(eventTypeNoSpace, conditionTriggersNoSpace))
                currentCond = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            end
            
            % Update lastValidKey when we have both item and condition
            if ~isempty(currentItem) && ~isempty(currentCond)
                lastValidKey = sprintf('%d_%d', currentCond, currentItem);
            end
        end
        
        % Use lastValidKey for boundary assignment
        if trialRunning && ~isempty(lastValidKey)
            if isKey(boundaryMap, lastValidKey)
                regionBoundaries = boundaryMap(lastValidKey);
                EEG.event(iEvt).regionBoundaries = regionBoundaries;
                
                % Add individual fields for each region
                for r = 1:numRegions
                    EEG.event(iEvt).(sprintf('region%d_start', r)) = regionBoundaries(r, 1);
                    EEG.event(iEvt).(sprintf('region%d_end', r)) = regionBoundaries(r, 2);
                    EEG.event(iEvt).(sprintf('region%d_name', r)) = regionNames{r};
                end
                
                % If this is a fixation event, determine its region
                if startsWith(EEG.event(iEvt).type, 'R_fixation')
                    
                    % Get fixation coordinates from the appropriate fields
                    if isfield(EEG.event(iEvt), 'fix_avgpos_x')
                        fix_pos_x = EEG.event(iEvt).fix_avgpos_x;
                    elseif isfield(EEG.event(iEvt), 'px')
                        fix_pos_x = EEG.event(iEvt).px;
                    else
                        warning('No x position field found for event %d. Skipping region assignment.', iEvt);
                        continue;
                    end
                    
                    % Ensure fix_pos_x is numeric
                    if iscell(fix_pos_x)
                        fix_pos_x = fix_pos_x{1};
                    end
                    if ischar(fix_pos_x)
                        fix_pos_x = str2double(fix_pos_x);
                    end
                    if ~isnumeric(fix_pos_x) || isnan(fix_pos_x)
                        warning('Invalid fix_avgpos_x at event %d. Skipping event.', iEvt);
                        continue;
                    end
                    
                    % Determine region based on position
                    for r = 1:numRegions
                        region_start = regionBoundaries(r, 1);
                        region_end = regionBoundaries(r, 2);
                        
                        if fix_pos_x >= region_start && fix_pos_x <= region_end
                            EEG.event(iEvt).current_region = r;
                            break;
                        end
                    end
                end
                
                numAssigned = numAssigned + 1;
            end
            
            % NEW: Assign region words for the trial if available.
            if isKey(regionWordsMap, lastValidKey)
                regionWords = regionWordsMap(lastValidKey);
                for r = 1:numRegions
                    EEG.event(iEvt).(sprintf('region%d_words', r)) = regionWords.(sprintf('region%d_words', r));
                end
            end
            
            % Store word boundaries
            if isKey(wordBoundaryMap, lastValidKey)
                wordBounds = struct();
                wordKeys = wordBoundaryMap(lastValidKey).keys;
                
                % Convert keys to valid field names and store boundaries
                for j = 1:length(wordKeys)
                    currentKey = wordKeys{j};
                    validField = matlab.lang.makeValidName(currentKey);
                    currentMap = wordBoundaryMap(lastValidKey);
                    currentBounds = currentMap(currentKey);
                    wordBounds.(validField) = currentBounds;
                end
                EEG.event(iEvt).word_boundaries = wordBounds;
            end
        end
    end

    fprintf('Finished processing events. Boundaries assigned to %d events\n', numAssigned);
end

%{
% Determines which word region contains a given fixation
function word_region = determine_word_region(event)
    if ~isfield(event, 'word_boundaries') || isempty(event.word_boundaries)
        word_region = '';
        return;
    end
    
    % Get x position from event
    if ~isfield(event, 'fix_avgpos_x') || isempty(event.fix_avgpos_x)
        word_region = '';
        return;
    end
    
    fix_pos_x = event.fix_avgpos_x;
    % Add validation for fix_pos_x
    if iscell(fix_pos_x)
        fix_pos_x = fix_pos_x{1};
    end
    if ischar(fix_pos_x)
        fix_pos_x = str2double(fix_pos_x);
    end
    if ~isnumeric(fix_pos_x) || isnan(fix_pos_x)
        word_region = '';
        return;
    end
    
    % Check each word's boundaries
    word_bounds = event.word_boundaries;
    field_names = fieldnames(word_bounds);
    
    for i = 1:length(field_names)
        currentField = field_names{i};
        bounds = word_bounds.(currentField);
        % Access the start and end fields of the boundary structure
        if fix_pos_x >= bounds.start && fix_pos_x <= bounds.end
            word_region = currentField;
            return;
        end
    end
    
    word_region = '';
end 
%}
