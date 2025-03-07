function EEG = compute_text_based_ia_word_level_sara(EEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, ...
                                              conditionColName, itemColName)
    % Validate inputs
    if nargin < 8
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
    
    % Read the data file with preserved column names
    try
        opts = detectImportOptions(txtFilePath, 'Delimiter', '\t');
        opts.VariableNamingRule = 'preserve';
        data = readtable(txtFilePath, opts);
        
        % Display available columns for debugging
        fprintf('Available columns in the data:\n');
        disp(data.Properties.VariableNames);
        
        % Check and adjust column names if needed
        if ~ismember(conditionColName, data.Properties.VariableNames)
            if ismember(['$' conditionColName], data.Properties.VariableNames)
                conditionColName = ['$' conditionColName];
            else
                error('Column %s or $%s not found in the data file', conditionColName, conditionColName);
            end
        end
        
        if ~ismember(itemColName, data.Properties.VariableNames)
            if ismember(['$' itemColName], data.Properties.VariableNames)
                itemColName = ['$' itemColName];
            else
                error('Column %s or $%s not found in the data file', itemColName, itemColName);
            end
        end
    catch ME
        error('Failed to read file: %s. Error: %s', txtFilePath, ME.message);
    end
    
    % Create maps to store boundaries
    boundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    wordBoundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    % Process each row in the data
    for iRow = 1:height(data)
        try
            key = sprintf('%d_%d', data.(conditionColName)(iRow), data.(itemColName)(iRow));
            regionBoundaries = zeros(numRegions, 2);  % [start end]
            wordBoundaries = containers.Map('KeyType', 'char', 'ValueType', 'any');
            
            % Track running position (like word_labeller.py)
            currentPosition = offset;
            
            % Process each region
            for r = 1:numRegions
                regionStart = currentPosition;
                regionText = data.(regionNames{r}){iRow};
                if iscell(regionText)
                    regionText = char(regionText);
                end
                
                % Split region text into words
                words = strsplit(strtrim(regionText));
                
                % Process each word in the region (matching word_labeller.py logic)
                for w = 1:length(words)
                    wordKey = sprintf('%d.%d', r, w);
                    currentWord = char(words{w});
                    
                    % Calculate word boundaries using PPC (pixels per character)
                    wordStart = currentPosition;
                    wordWidth = pxPerChar * (length(currentWord) + (w > 1));  % Add space after first word
                    wordBoundaries(wordKey) = [wordStart, wordStart + wordWidth];
                    
                    % Update position for next word
                    currentPosition = wordStart + wordWidth;
                end
                
                % Store region boundaries
                regionBoundaries(r,:) = [regionStart, currentPosition];
                
                % Add space between regions (except after the last region)
                if r < numRegions
                    currentPosition = currentPosition + pxPerChar;  % Add one character width of space
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
        error('User cancelled input. Exiting function.');
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
                currentItem = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            elseif any(strcmp(eventTypeNoSpace, conditionTriggersNoSpace))
                currentCond = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            elseif startsWith(eventType, 'R_fixation') || startsWith(eventType, 'R_saccade')
                if ~isempty(currentItem) && ~isempty(currentCond)
                    key = sprintf('%d_%d', currentCond, currentItem);
                    
                    if isKey(boundaryMap, key)
                        regionBoundaries = boundaryMap(key);
                        
                        % Store region boundaries
                        EEG.event(iEvt).regionBoundaries = regionBoundaries;
                        
                        % Create word boundaries as a simple struct
                        wordBounds = struct();
                        wordKeys = wordBoundaryMap(key).keys;
                        
                        % Convert keys to valid field names and store boundaries
                        for k = 1:length(wordKeys)
                            currentKey = wordKeys{k};
                            validField = matlab.lang.makeValidName(currentKey);
                            currentMap = wordBoundaryMap(key);
                            currentBounds = currentMap(currentKey);
                            wordBounds.(validField) = currentBounds(1:2);
                        end
                        EEG.event(iEvt).word_boundaries = wordBounds;

                        % Add individual fields for each region
                        for r = 1:numRegions
                            % Region boundaries
                            EEG.event(iEvt).(sprintf('region%d_start', r)) = regionBoundaries(r, 1);
                            EEG.event(iEvt).(sprintf('region%d_end', r)) = regionBoundaries(r, 2);
                            EEG.event(iEvt).(sprintf('region%d_name', r)) = regionNames{r};
                            
                            % Count words in this region first
                            regionWordCount = sum(cellfun(@(x) startsWith(x, sprintf('%d.', r)), wordKeys));
                            regionWordNums = zeros(1, regionWordCount);
                            wordIdx = 1;
                            
                            for k = 1:length(wordKeys)
                                if startsWith(wordKeys{k}, sprintf('%d.', r))
                                    wordsSplit = strsplit(wordKeys{k}, '.');
                                    regionWordNums(wordIdx) = str2double(wordsSplit{2});
                                    wordIdx = wordIdx + 1;
                                end
                            end
                            EEG.event(iEvt).(sprintf('region%d_words', r)) = regionWordNums;
                        end
                        
                        numAssigned = numAssigned + 1;
                    end
                end
            end
        end
    end
    
    fprintf('Assigned boundaries to %d events.\n', numAssigned);
    
    % Label trials with word-level information
    try
        EEG = trial_labeling_word_level_sara(EEG, startCode, endCode, conditionTriggers, itemTriggers);
    catch ME
        warning('Error in trial labeling: %s', ME.message);
    end
end 