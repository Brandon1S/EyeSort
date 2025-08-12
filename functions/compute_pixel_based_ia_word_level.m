function EEG = compute_pixel_based_ia_word_level(EEG, txtFilePath, ...
                                      numRegions, regionNames, ...
                                      regionStartNames, regionWidthNames, ...
                                      regionYTopNames, regionYBottomNames, ...
                                      conditionColName, itemColName)
    % Validate inputs (similar to compute_pixel_based_ia.m)
    if nargin < 8
        error('compute_pixel_based_ia_word_level: Not enough input arguments.');
    end
    
    % Read the data file
    try
        data = readtable(txtFilePath, 'Delimiter', '\t');
    catch
        error('Failed to read file: %s', txtFilePath);
    end
    
    % Validate and correct condition and item column names with case-insensitive matching
    fprintf('\nValidating condition and item columns:\n');
    [conditionColName, foundCondCol] = findBestColumnMatch(data.Properties.VariableNames, conditionColName);
    [itemColName, foundItemCol] = findBestColumnMatch(data.Properties.VariableNames, itemColName);
    
    if ~foundCondCol
        error('Condition column "%s" not found in data file.\nAvailable columns: %s', conditionColName, strjoin(data.Properties.VariableNames, ', '));
    end
    if ~foundItemCol
        error('Item column "%s" not found in data file.\nAvailable columns: %s', itemColName, strjoin(data.Properties.VariableNames, ', '));
    end
    
    fprintf('✓ Using condition column: %s\n', conditionColName);
    fprintf('✓ Using item column: %s\n', itemColName);

    % Validate and correct region names with case-insensitive matching
    fprintf('\nValidating region columns:\n');
    for i = 1:length(regionNames)
        [correctedName, found] = findBestColumnMatch(data.Properties.VariableNames, regionNames{i});
        if found
            if ~strcmp(regionNames{i}, correctedName)
                fprintf('✓ Found region "%s" as "%s"\n', regionNames{i}, correctedName);
                regionNames{i} = correctedName;
            else
                fprintf('✓ Found region: %s\n', regionNames{i});
            end
        else
            fprintf('✗ Missing region column: %s\n', regionNames{i});
            error('Region column "%s" not found in data file.\nAvailable columns: %s', regionNames{i}, strjoin(data.Properties.VariableNames, ', '));
        end
    end

    % Create maps to store boundaries
    boundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    wordBoundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    % Constants at top of file
    PPC = 14;  % Pixels per character
    
    % Process each row in the data
    for iRow = 1:height(data)
        try
            key = sprintf('%d_%d', data.(conditionColName)(iRow), data.(itemColName)(iRow));
            regionBoundaries = zeros(numRegions, 4);  % [xStart xEnd yTop yBottom]
            wordBoundaries = containers.Map('KeyType', 'char', 'ValueType', 'any');
            
            % Process each region
            for r = 1:numRegions
                % Extract X coordinate from location string like "(281.00, 514.00)"
                locStr = data.(regionStartNames{r})(iRow);
                xStart = extractXCoordinate(locStr);
                width = convertToNumeric(data.(regionWidthNames{r})(iRow));
                yTop = convertToNumeric(data.(regionYTopNames{r})(iRow));
                yBottom = convertToNumeric(data.(regionYBottomNames{r})(iRow));
                
                % Check for valid numeric values
                if any(isnan([xStart, width, yTop, yBottom]))
                    warning('Invalid numeric data in row %d, region %d', iRow, r);
                    continue;
                end
                
                % Store region boundaries
                regionBoundaries(r,:) = [xStart, xStart + width, yTop, yBottom];
                
                % Get region text and ensure it's a character array
                regionText = data.(regionNames{r}){iRow};
                regionText = char(regionText);
                words = strsplit(strtrim(regionText));
                totalLength = length(regionText);
                
                % Calculate word boundaries within this region
                wordStart = xStart;
                for w = 1:length(words)
                    wordKey = sprintf('%d.%d', r, w);
                    currentWord = char(words{w});
                    
                    % Calculate word width using pixels-per-character
                    wordWidth = PPC * (length(currentWord) + (w > 1));  % Add space after first word
                    wordBoundaries(wordKey) = [wordStart, wordStart + wordWidth, yTop, yBottom];
                    wordStart = wordStart + wordWidth;
                end
            end
            
            % Store boundaries for this condition/item
            boundaryMap(key) = regionBoundaries;
            wordBoundaryMap(key) = wordBoundaries;
            
        catch ME
            warning('Error processing row %d: %s', iRow, ME.message);
            continue;
        end
    end
    
    % Prompt user for trial and trigger information
    fprintf('Step 2: Prompting user for trial and trigger information...\n');
    
    userInput = inputdlg({'Start Trial Trigger:', ...
                          'End Trial Trigger:', ...
                          'Condition Triggers (comma-separated):', ...
                          'Item Triggers (comma-separated):'}, ...
                         'Input Trial/Trigger Information', ...
                         [1 50; 1 50; 1 50; 1 50], ...
                         {'S254', 'S255', 'S224, S213, S221', 'S39, S8, S152'});
    
    if isempty(userInput)
        error('compute_pixel_based_ia_word_level: User cancelled input. Exiting function.');
    end
    
    startCode = userInput{1};
    endCode = userInput{2};
    conditionTriggers = strsplit(userInput{3}, ',');
    itemTriggers = strsplit(userInput{4}, ',');
    
    % Process events and assign boundaries
    nEvents = length(EEG.event);
    trialRunning = false;
    currentItem = [];
    currentCond = [];
    numAssigned = 0;
    
    for iEvt = 1:nEvents
        eventType = EEG.event(iEvt).type;
        if isnumeric(eventType)
            eventType = num2str(eventType);
        end
        
        % Handle trial start/end
        if strcmp(eventType, startCode)
            trialRunning = true;
            currentItem = [];
            currentCond = [];
            continue;
        elseif strcmp(eventType, endCode)
            trialRunning = false;
            continue;
        end
        
        % Process events within trial
        if trialRunning
            % Remove all spaces for comparison
            eventTypeNoSpace = regexprep(eventType, '\s+', '');
            itemTriggersNoSpace = cellfun(@(x) regexprep(x, '\s+', ''), itemTriggers, 'UniformOutput', false);
            conditionTriggersNoSpace = cellfun(@(x) regexprep(x, '\s+', ''), conditionTriggers, 'UniformOutput', false);
            
            % Compare without spaces
            if any(strcmp(eventTypeNoSpace, itemTriggersNoSpace))
                % Extract just the number
                currentItem = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            
            elseif any(strcmp(eventTypeNoSpace, conditionTriggersNoSpace))
                % Extract just the number
                currentCond = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            
            elseif startsWith(eventType, 'R_fixation') || startsWith(eventType, 'R_saccade')
                if ~isempty(currentItem) && ~isempty(currentCond)
                    key = sprintf('%d_%d', currentCond, currentItem);
                    
                    if isKey(boundaryMap, key)
                        % Store region boundaries
                        EEG.event(iEvt).regionBoundaries = boundaryMap(key);
                        
                        % Store word boundaries
                        EEG.event(iEvt).word_boundaries = wordBoundaryMap(key);
                        
                        numAssigned = numAssigned + 1;
                    end
                end
            end
        end
    end
    
    fprintf('Assigned boundaries to %d events.\n', numAssigned);
    
    % Label trials with word-level information
    try
        EEG = trial_labeling_word_level(EEG, startCode, endCode, conditionTriggers, itemTriggers);
    catch ME
        warning('Error in trial labeling: %s', ME.message);
    end
end

function val = convertToNumeric(input)
    if iscell(input)
        input = input{1};
    end
    if isnumeric(input)
        val = input;
    else
        val = str2double(input);
    end
    if isempty(val) || isnan(val)
        val = NaN;
    end
end

function xCoord = extractXCoordinate(locString)
    if iscell(locString)
        locString = locString{1};
    end
    
    % Handle string format "(X.XX, Y.YY)"
    try
        % Extract first number from the string
        numbers = regexp(locString, '[-\d.]+', 'match');
        if ~isempty(numbers)
            xCoord = str2double(numbers{1});
        else
            xCoord = NaN;
        end
    catch
        xCoord = NaN;
    end
end

function wordRegion = determine_word_region(event)
    % Get fixation coordinates
    if isfield(event, 'px') && isfield(event, 'py')
        x = event.px;
        y = event.py;
    else
        wordRegion = '';
        return;
    end
    
    % Get word boundaries from event
    if ~isfield(event, 'word_boundaries') || isempty(event.word_boundaries)
        wordRegion = '';
        return;
    end
    
    wordBoundaries = event.word_boundaries;
    keys = wordBoundaries.keys;
    
    % Check each word region
    for i = 1:length(keys)
        bounds = wordBoundaries(keys{i});
        if x >= bounds(1) && x <= bounds(2) && ...  % within x bounds
           y >= bounds(3) && y <= bounds(4)         % within y bounds
            wordRegion = keys{i};
            return;
        end
    end
    
    wordRegion = '';
end

%% Helper function: findBestColumnMatch
function [bestMatch, found] = findBestColumnMatch(availableColumns, requestedColumn)
    % FINDBESTCOLUMNMATCH - Finds the best match for a column name in a dataset
    %
    % This function tries to match a requested column name with available columns,
    % handling case differences and special characters like '$'.
    
    % Check for exact match first
    if ismember(requestedColumn, availableColumns)
        bestMatch = requestedColumn;
        found = true;
        return;
    end
    
    % Check for match with/without '$' prefix
    if startsWith(requestedColumn, '$')
        altColumn = requestedColumn(2:end);
    else
        altColumn = ['$' requestedColumn];
    end
    if ismember(altColumn, availableColumns)
        bestMatch = altColumn;
        found = true;
        return;
    end
    
    % Check for case-insensitive match
    for i = 1:length(availableColumns)
        if strcmpi(requestedColumn, availableColumns{i})
            bestMatch = availableColumns{i};
            found = true;
            return;
        end
    end
    
    % No match found
    bestMatch = requestedColumn;
    found = false;
end 