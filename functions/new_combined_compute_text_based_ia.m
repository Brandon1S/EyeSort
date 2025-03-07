function EEG = new_combined_compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, ...
                                              conditionColName, itemColName, startCode, endCode, conditionTriggers, itemTriggers)
    % If EEG is an array (i.e., multiple datasets), process each in a loop.
    if numel(EEG) > 1
        for idx = 1:numel(EEG)
            fprintf('\nProcessing dataset %d of %d...\n', idx, numel(EEG));
            currentEEG = EEG(idx); % Work with a single dataset
            
            % Process the current dataset
            currentEEG = process_single_dataset(currentEEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, conditionColName, itemColName, ...
                                              startCode, endCode, conditionTriggers, itemTriggers);
            
            % Store back in the array - NO SAVING
            EEG(idx) = currentEEG;
        end
        fprintf('\nAll %d datasets processed successfully!\n', numel(EEG));
        return;
    end
    
    % Otherwise, process a single dataset
    EEG = process_single_dataset(EEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, conditionColName, itemColName, ...
                                              startCode, endCode, conditionTriggers, itemTriggers);
end

function EEG = process_single_dataset(EEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, conditionColName, itemColName, ...
                                              startCode, endCode, conditionTriggers, itemTriggers)
    %% Validate inputs and read the interest area text file
    if nargin < 12
        error('compute_text_based_ia_word_level: Not enough input arguments.');
    end
    if isempty(EEG)
        error('EEG is empty. Cannot proceed.');
    end
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        error('EEG.event is missing or empty. Cannot proceed without event data.');
    end

    if ~exist(txtFilePath, 'file')
        error('The file "%s" does not exist.', txtFilePath);
    end

    if length(regionNames) ~= numRegions
        error('Number of regionNames (%d) does not match numRegions (%d).', ...
               length(regionNames), numRegions);
    end

    fprintf('Input Parameters:\n');
    fprintf('Offset: %d, Pixels per char: %d\n', offset, pxPerChar);
    fprintf('Number of regions: %d\n', numRegions);
    fprintf('Region names: %s\n', strjoin(regionNames, ', '));
    fprintf('Condition column: %s, Item column: %s\n', conditionColName, itemColName);

    opts = detectImportOptions(txtFilePath, 'Delimiter', '\t');
    opts.VariableNamingRule = 'preserve';
    for i = 1:length(regionNames)
        opts = setvaropts(opts, regionNames{i}, 'WhitespaceRule', 'preserve');
    end

    fprintf('\nDetected column names in file:\n');
    disp(opts.VariableNames);
    data = readtable(txtFilePath, opts);
    fprintf('\nActual table column names after import:\n');
    disp(data.Properties.VariableNames);

    [conditionColName, foundCondCol] = findBestColumnMatch(data.Properties.VariableNames, conditionColName);
    [itemColName, foundItemCol] = findBestColumnMatch(data.Properties.VariableNames, itemColName);
    if ~foundCondCol
        fprintf('Could not find condition column "%s". Available columns:\n', conditionColName);
        disp(data.Properties.VariableNames);
        error('Condition column not found. Please check the column name.');
    end
    if ~foundItemCol
        fprintf('Could not find item column "%s". Available columns:\n', itemColName);
        disp(data.Properties.VariableNames);
        error('Item column not found. Please check the column name.');
    end

    fprintf('Using condition column: %s\n', conditionColName);
    fprintf('Using item column: %s\n', itemColName);

    fprintf('\nFirst few rows of condition and item data:\n');
    head_data = head(data);
    try
        disp([head_data.(conditionColName), head_data.(itemColName)]);
    catch ME
        fprintf('Error accessing columns: %s\n', ME.message);
        disp(data.Properties.VariableNames);
        rethrow(ME);
    end

    %% Build mapping containers for region boundaries and word boundaries
    boundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    wordBoundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    regionWordsMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    fprintf('Processing %d rows of data...\n', height(data));
    for iRow = 1:height(data)
        try
            key = sprintf('%d_%d', data.(conditionColName)(iRow), data.(itemColName)(iRow));
            currentPosition = offset;
            regionBoundaries = zeros(numRegions, 2);
            wordBoundaries = containers.Map('KeyType', 'char', 'ValueType', 'any');
            regionWords = struct();
            for r = 1:numRegions
                regionStart = currentPosition;
                regionText = data.(regionNames{r}){iRow};
                if iscell(regionText)
                    regionText = char(regionText);
                end
                regionWidth = pxPerChar * length(regionText);
                currentPosition = regionStart + regionWidth;
                regionBoundaries(r,:) = [regionStart, currentPosition];
                [wordStarts, wordEnds] = regexp(regionText, '(\s*\S+)', 'start', 'end');
                wordsInRegion = regexp(regionText, '(\s*\S+)', 'match');
                regionWords.(sprintf('region%d_words', r)) = wordsInRegion;
                for idx = 1:length(wordStarts)
                    wordKey = sprintf('%d.%d', r, idx);
                    wordPixelStart = regionStart + (wordStarts(idx) - 1) * pxPerChar;
                    wordPixelEnd   = regionStart + wordEnds(idx) * pxPerChar;
                    wordBoundaries(wordKey) = [wordPixelStart, wordPixelEnd];
                end
            end
            boundaryMap(key) = regionBoundaries;
            wordBoundaryMap(key) = wordBoundaries;
            regionWordsMap(key) = regionWords;
        catch ME
            warning('Error processing row %d: %s', iRow, ME.message);
        end
    end
    fprintf('Processed %d rows\n', height(data));

    %% Assign region boundaries to EEG events
    [EEG.event.regionBoundaries] = deal([]);
    [EEG.event.word_boundaries] = deal([]);
    for r = 1:numRegions
        [EEG.event.(sprintf('region%d_start', r))] = deal(0);
        [EEG.event.(sprintf('region%d_end', r))] = deal(0);
        [EEG.event.(sprintf('region%d_name', r))] = deal('');
        [EEG.event.(sprintf('region%d_words', r))] = deal([]);
    end

    fprintf('Processing EEG events for boundary assignment...\n');
    numAssigned = 0;
    currentItem = [];
    currentCond = [];
    trialRunning = false;
    lastValidKey = '';

    conditionTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), conditionTriggers, 'UniformOutput', false);
    itemTriggersNoSpace = cellfun(@(x) strrep(x, ' ', ''), itemTriggers, 'UniformOutput', false);

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
            if any(strcmp(eventTypeNoSpace, itemTriggersNoSpace))
                currentItem = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            elseif any(strcmp(eventTypeNoSpace, conditionTriggersNoSpace))
                currentCond = str2double(regexp(eventTypeNoSpace, '\d+', 'match', 'once'));
            end
            if ~isempty(currentItem) && ~isempty(currentCond)
                lastValidKey = sprintf('%d_%d', currentCond, currentItem);
            end
        end

        if trialRunning && ~isempty(lastValidKey)
            if isKey(boundaryMap, lastValidKey)
                regionBoundaries = boundaryMap(lastValidKey);
                EEG.event(iEvt).regionBoundaries = regionBoundaries;
                for r = 1:numRegions
                    EEG.event(iEvt).(sprintf('region%d_start', r)) = regionBoundaries(r, 1);
                    EEG.event(iEvt).(sprintf('region%d_end', r)) = regionBoundaries(r, 2);
                    EEG.event(iEvt).(sprintf('region%d_name', r)) = regionNames{r};
                end
                if startsWith(EEG.event(iEvt).type, 'R_fixation')
                    if isfield(EEG.event(iEvt), 'fix_avgpos_x')
                        fix_pos_x = EEG.event(iEvt).fix_avgpos_x;
                    elseif isfield(EEG.event(iEvt), 'px')
                        fix_pos_x = EEG.event(iEvt).px;
                    else
                        warning('No x position field found for event %d. Skipping region assignment.', iEvt);
                        continue;
                    end
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

            if isKey(regionWordsMap, lastValidKey)
                regionWords = regionWordsMap(lastValidKey);
                for r = 1:numRegions
                    EEG.event(iEvt).(sprintf('region%d_words', r)) = regionWords.(sprintf('region%d_words', r));
                end
            end

            if isKey(wordBoundaryMap, lastValidKey)
                wordBounds = struct();
                wordKeys = wordBoundaryMap(lastValidKey).keys;
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

    fprintf('Finished processing EEG events.\n');

    %% Call trial labeling
    fprintf('Performing trial labeling...\n');
    EEG = new_trial_labelling(EEG, startCode, endCode, conditionTriggers, itemTriggers);

    % Add a custom field to track processing status instead of using EEG.saved
    EEG.eyesort_processed = true;
    
    fprintf('\nProcessing complete! You can now filter the dataset using the Filter Datasets option in the EyeSort menu.\n');
end

%% Helper function: findBestColumnMatch (unchanged core functionality)
function [bestMatch, found] = findBestColumnMatch(availableColumns, requestedColumn)
    if ismember(requestedColumn, availableColumns)
        bestMatch = requestedColumn;
        found = true;
        return;
    end
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
    for i = 1:length(availableColumns)
        if strcmpi(requestedColumn, availableColumns{i})
            bestMatch = availableColumns{i};
            found = true;
            return;
        end
    end
    bestMatch = requestedColumn;
    found = false;
end
