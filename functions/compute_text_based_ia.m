function EEG = compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, numRegions, regionNames, conditionColName, itemColName)

% compute_text_based_ia() - Compute pixel-based Interest Area boundaries from
%                           text and pixel data without having the regions 
%                           pre-defined.
% Usage:
%   >> EEG = compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
%                                  numRegions, regionNames, conditionColName, itemColName);
%
% Inputs:
%   EEG               - EEGLAB EEG structure to be updated
%   txtFilePath       - Path to the .txt (or .csv) file containing text-based IAs
%   offset            - Starting horizontal pixel offset from the left edge
%   pxPerChar         - Number of horizontal pixels per character
%   numRegions        - Number of text-based regions (columns) for each trial/item
%   regionNames       - Cell array with the names of the region columns in txtFile
%   conditionColName  - Name of the column containing condition labels
%   itemColName       - Name of the column containing item labels
%
% Outputs:
%   EEG               - Updated EEG structure with IA boundaries attached to EEG.event
%
% The .txt file is assumed to have columns for:
%   1) Condition
%   2) Item
%   3) region text columns (e.g., Region1, Region2, etc.)
%
% Example:
%   EEG = compute_text_based_ia(EEG, 'sentenceRegions.txt', 50, 10, 3, ...
%                               {'Region1','Region2','Region3'}, ...
%                               'Condition','Item');
%
% Note:
%   - Assumes a single-line reading paradigm (Y-dimension is fixed).
%   - If your experiment has multi-line text or variable Y positions, consider
%     a separate approach or precomputed pixel boundaries. Option # 2
%   - This function merely computes region boundaries and attaches them to EEG.event.
%     The actual "region of fixation" labeling occurs in a separate step once
%     you have (X,Y) fixation data. This will be done in the filter sequence.

    
    % Original event check
    if ~isfield(EEG, 'event') || isempty(EEG.event)
        error('compute_text_based_ia: EEG.event is empty or missing. Cannot proceed without event data.');
    end

    % Debugging output for numRegions at entry
    fprintf('Debug: Initial numRegions value: %d (class: %s)\n', numRegions, class(numRegions));
    
    % Validate numRegions once at the start
    if ~isscalar(numRegions) || ~isnumeric(numRegions) || numRegions <= 0
        error('compute_text_based_ia: "numRegions" must be a positive scalar number. Got %s of class %s', ...
              mat2str(numRegions), class(numRegions));
    end
    
    % Convert to double to ensure consistency
    numRegions = double(numRegions);

    % Ensure the correct number of arguments
    if nargin < 8
        error('Compute_text_based_ia: Not enough input arguments. Please check the help section.')
    end

    if ~exist(txtFilePath, 'file')
        error('compute_text_based_ia: The file "%s" does not exist,', txtFilePath)
    end

    % Validate regionNames
    if ~iscell(regionNames)
        error('compute_text_based_ia: "regionNames" must be a cell array.');
    end
    
    if length(regionNames) ~= numRegions
        error('compute_text_based_ia: Number of region names (%d) does not match numRegions (%d).', ...
              length(regionNames), numRegions);
    end

    % -------------------------------------------------------------------------
    % 1) Read the Interest Area File and Compute Regions
    % -------------------------------------------------------------------------
    fprintf('Step 1: Reading IA file and computing pixel regions...\n');
    
    try
        % Read table with specific encoding
        opts = detectImportOptions(txtFilePath, 'FileType', 'text');
        opts.Encoding = 'UTF-8';  % Try UTF-8 encoding
        dataTable = readtable(txtFilePath, opts);
        
        % Clean up column names
        newNames = regexprep(dataTable.Properties.VariableNames, '\s+', '_');
        dataTable.Properties.VariableNames = newNames;
        
        % Convert trigger values to numbers and create all possible combinations
        if iscell(dataTable.trigcondition) && iscell(dataTable.trigitem)
            % Extract numbers from conditions and items
            conditions = cellfun(@(x) str2double(regexp(char(x), '\d+', 'match')), ...
                               dataTable.trigcondition, 'UniformOutput', false);
            items = cellfun(@(x) str2double(regexp(regexprep(char(x), '\s+', ''), '\d+', 'match')), ...
                           dataTable.trigitem, 'UniformOutput', false);
            
            % Create expanded table with all condition-item combinations
            expandedTable = create_all_combinations(dataTable, conditions, items);
            dataTable = expandedTable;
        end
        
    catch
        error('compute_text_based_ia: Unable to read the interest area file');
    end

    % Validate required columns with detailed feedback
    requiredCols = [{conditionColName}, {itemColName}, regionNames];
    missingCols = cell(length(requiredCols), 1);  % Preallocate
    numMissing = 0;
    
    for col = requiredCols
        if ~ismember(col{:}, dataTable.Properties.VariableNames)
            numMissing = numMissing + 1;
            missingCols{numMissing} = col{:};
        end
    end
    missingCols = missingCols(1:numMissing);  % Trim unused cells
    
    if ~isempty(missingCols)
        error(['compute_text_based_ia: Missing required columns in the file: %s\n', ...
               'Available columns are: %s'], ...
               strjoin(missingCols, ', '), ...
               strjoin(dataTable.Properties.VariableNames, ', '));
    end

    % Build boundary map for interest areas
    boundaryMap = build_boundary_map(dataTable, offset, pxPerChar, numRegions, regionNames, 'trigcondition', 'trigitem');

    % -------------------------------------------------------------------------
    % 2) Prompt User for Trial, Condition, and Item Codes
    % -------------------------------------------------------------------------
    fprintf('Step 2: Prompting user for trial and trigger information...\n');

    % Create GUI pop-up to collect Start and End Trial Triggers, Condition Triggers, and Item Triggers
    userInput = inputdlg({'Start Trial Trigger:', ...
                          'End Trial Trigger:', ...
                          'Condition Triggers (comma-separated):', ...
                          'Item Triggers (comma-separated):'}, ...
                         'Input Trial/Trigger Information', ...
                         [1 50; 1 50; 1 50; 1 50], ...
                         {'S254', 'S255', 'S224, S213, S221', 'S39, S8, S152'});
    
    if isempty(userInput)
        error('compute_text_based_ia: User cancelled input. Exiting function.');
    end

    startCode = userInput{1};
    endCode = userInput{2};
    conditionTriggers = strsplit(userInput{3}, ',');
    itemTriggers = strsplit(userInput{4}, ',');

    % -------------------------------------------------------------------------
    % 3) Process Each Trial and Assign Regions
    % -------------------------------------------------------------------------
    fprintf('Step 3: Processing trials and assigning pixel boundaries...\n');

    nEvents = length(EEG.event);
    trialRunning = false;
    currentItem = [];
    currentCond = [];
    numAssigned = 0;

    for iEvt = 1:nEvents
        eventType = EEG.event(iEvt).type;

        % Convert numeric event types to strings
        if isnumeric(eventType)
            eventType = num2str(eventType);
        end

        % Detect start of trial
        if strcmp(eventType, startCode)
            trialRunning = true;
            currentItem = [];
            currentCond = [];
            continue;
        end

        % Detect end of trial
        if strcmp(eventType, endCode)
            trialRunning = false;
            continue;
        end

        % Process events within a trial
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
                
                % Assign pixel boundaries if both condition and item are known
                if ~isempty(currentItem) && ~isempty(currentCond)
                    key = sprintf('%d_%d', currentCond, currentItem);

                    if isKey(boundaryMap, key)
                        
                        regionBoundaries = boundaryMap(key);
                        
                        % Attach region boundaries to the current event
                        EEG.event(iEvt).regionBoundaries = regionBoundaries;

                        % Add individual fields for each region
                        for r = 1:numRegions
                            EEG.event(iEvt).(sprintf('region%d_start', r)) = regionBoundaries(r, 1);
                            EEG.event(iEvt).(sprintf('region%d_end', r)) = regionBoundaries(r, 2);
                            EEG.event(iEvt).(sprintf('region%d_name', r)) = regionNames{r};
                        end

                        numAssigned = numAssigned + 1;
                    end
                end
            end
        end
    end

    fprintf('Assigned pixel boundaries to %d EEG.event entries.\n', numAssigned);

    %% Verify If a new dataset should be created or to just update the existing dataset
    %{
    % Update the existing dataset
    EEG.setname = [EEG.setname '_ia'];  % Append '_ia' to indicate IA processing
    EEG = eeg_checkset(EEG);  % Verify dataset 
    
    fprintf('Successfully updated dataset with interest area boundaries.\n');
    %}
end

% -------------------------------------------------------------------------
% Helper Function: Build Boundary Map
% -------------------------------------------------------------------------
function boundaryMap = build_boundary_map(dataTable, offset, pxPerChar, numRegions, regionNames, conditionColName, itemColName)
    % Create a map to store boundaries for each condition-item pair
    boundaryMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    for iRow = 1:height(dataTable)
        try
            % Get condition and item codes directly as numbers
            condCode = dataTable.(conditionColName)(iRow);
            itemCode = dataTable.(itemColName)(iRow);
            
            if isnan(condCode) || isnan(itemCode)
                warning('Row %d: Invalid condition (%g) or item (%g) code', ...
                        iRow, condCode, itemCode);
                continue;
            end
            
            key = sprintf('%d_%d', condCode, itemCode);
            
            % Compute region boundaries
            regionBoundaries = zeros(numRegions, 2);
            currOffset = offset;

            for r = 1:numRegions
                % Get the text and ensure it's a character array
                regionText = dataTable.(regionNames{r}){iRow};
                if iscell(regionText)
                    regionText = regionText{1};
                end
                regionText = char(regionText);
                
                nChars = length(regionText);
                regionStart = currOffset;
                regionEnd = currOffset + (nChars * pxPerChar) - 1;
                regionBoundaries(r, :) = [regionStart, regionEnd];
                currOffset = regionEnd + 1;
            end

            boundaryMap(key) = regionBoundaries;
            
        catch ME
            warning('Error processing row %d: %s', iRow, ME.message);
            continue;
        end
    end
end

% Helper function to create all possible condition-item combinations
function expandedTable = create_all_combinations(table, conditions, items)
    
    % Calculate total number of combinations
    totalCombos = sum(cellfun(@length, conditions) .* cellfun(@length, items));
    
    % Preallocate array
    allRows = cell(totalCombos, 1);
    currentRow = 1;
    
    % For each row in the original table
    for i = 1:height(table)
        rowConditions = conditions{i};
        rowItems = items{i};
        
        % Create all possible combinations for this row
        for j = 1:length(rowConditions)
            for k = 1:length(rowItems)
                % Copy the entire row
                newRow = table(i,:);
                % Update condition and item
                newRow.trigcondition = rowConditions(j);
                newRow.trigitem = rowItems(k);
                % Store the new row
                allRows{currentRow} = newRow;
                currentRow = currentRow + 1;
            end
        end
    end
    
    % Combine all rows into a new table
    expandedTable = vertcat(allRows{:});
end