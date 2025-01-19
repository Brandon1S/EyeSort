function EEG = compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, numRegions, regionNames, conditionColName, itemColName)

% compute_text_based_ia() - Compute pixel-based Interest Area (IA) boundaries from
%                           monospaced text data, then attach to EEG.event.
%
% Usage:
%   >> EEG = compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
%                                  numRegions, regionNames, conditionColName, itemColName);
%
% Inputs:
%   EEG               - EEGLAB EEG structure to be updated
%   txtFilePath       - Path to the .txt (or .csv) file containing text-based IAs
%   offset            - Starting horizontal pixel offset from the left edge
%   pxPerChar         - Number of horizontal pixels per character (monospaced font)
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
%   - Assume a single-line reading paradigm (Y-dimension is fixed).
%   - If your experiment has multi-line text or variable Y positions, consider
%     a separate approach or precomputed pixel boundaries. Option # 2
%   - This function merely computes region boundaries and attaches them to EEG.event.
%     The actual "region of fixation" labeling occurs in a separate step once
%     you have (X,Y) fixation data. This will be done in the filter sequence.

    % Ensure the correct number of arguments
    if nargin < 8
        error('Compute_text_based_ia: Not enough input arguments. Please check the help section.')
    end

    if ~exist(txtFilePath, 'file')
        error('compute_text_based_ia: The file "%s" does not exist,', txtFilePath)
    end

    if ~iscell(regionNames) || length(regionNames) ~= numRegions
        error(['compute_text_based_ia: "regionNames" must be a cell array of length '  'numRegions (%d).'], numRegions);
    end

    if ~isfield(EEG, 'event') || isempty(EEG.event)
        warning('compute_text_based_ia: EEG.event is empty or missing. Nothing to merge?');
    end

    % -------------------------------------------------------------------------
    %  Read File into a Table
    % -------------------------------------------------------------------------
    try
        dataTable = readtable(txtFilePath, 'Delimiter','\t', 'FileType','text', 'VariableNamingRule','preserve');
    catch ME
        % If tab-delimited doesn't work, try other strategies or rethrow
        warning('Failed to read file with tab delimiter. Attempting auto detect...');
        dataTable = readtable(txtFilePath); 
    end
    
    % Check if required columns exist
    requiredCols = [ {conditionColName}, {itemColName}, regionNames ];
    for c = 1:length(requiredCols)
        if ~ismember(requiredCols{c}, dataTable.Properties.VariableNames)
            error('compute_text_based_ia: Missing column "%s" in the file.', requiredCols{c});
        end
    end
    
    % -------------------------------------------------------------------------
    % 2) Iterate Over Each Row in dataTable => Compute Region Boundaries
    % -------------------------------------------------------------------------
    numTrialsInFile = height(dataTable);
    fprintf('Computing text-based IA boundaries for %d rows in %s...\n', ...
            numTrialsInFile, txtFilePath);
    
    % Store boundaries in a structure array or cell array, keyed by (cond,item).
    % Another approach is to directly attach to EEG.event in this loop
    boundaryMap = containers.Map();  
   
    % Key will be "conditionName_itemName", value = matrix of region boundaries
    for iRow = 1:numTrialsInFile
        condValue = dataTable.(conditionColName)(iRow); % if cell-string or char
        if ischar(condValue) || isstring(condValue)
            condStr = char(condValue);
        else
            % Convert numeric condition to string
            condStr = num2str(condValue);
        end
        
        itemValue = dataTable.(itemColName)(iRow);
        if ischar(itemValue) || isstring(itemValue)
            itemStr = char(itemValue);
        else
            itemStr = num2str(itemValue);
        end
        
        currentKey = sprintf('%s_%s', condStr, itemStr);
        
        % Builds a [numRegions x 2] matrix: [startPix, endPix] for each region
        regionBoundaries = nan(numRegions, 2);
        
        currOffset = offset;
        for r = 1:numRegions
            regionText = dataTable.(regionNames{r})(iRow);
            
            % Handle empty or missing text
            if isempty(regionText)
                nChars = 0; 
            else
                nChars = length(regionText);
            end
            
            regionStart = currOffset;
            
            % - 1 to include (inclusive) the last characters width
            regionEnd   = currOffset + (nChars * pxPerChar) - 1;
            % If nChars=0, regionEnd < regionStart, handle that gracefully
            if regionEnd < regionStart
                regionEnd = regionStart;  % or keep it regionStart-1; depends on preference
            end
            
            regionBoundaries(r,:) = [regionStart, regionEnd];
            
            % Update offset for next region
            currOffset = regionEnd + 1;
        end
        
        % Store in the map
        boundaryMap(currentKey) = regionBoundaries;
    end
    
    fprintf('Finished computing IA boundaries. Now merging with EEG.event...\n');
    
    % -------------------------------------------------------------------------
    % 3) Merge Region Boundaries with EEG.event
    % -------------------------------------------------------------------------
    nEvents = length(EEG.event);
    numAssigned = 0;
    
    for iEvt = 1:nEvents
        % We assume there's some way to read the condition/item from EEG.event
        % e.g.:
        %  - EEG.event(iEvt).condition
        %  - EEG.event(iEvt).item
        % Adjust these lines to match your data.
        if isfield(EEG.event, 'condition') && isfield(EEG.event, 'item')
            condStr = EEG.event(iEvt).trigcondition;
            itemStr = EEG.event(iEvt).trigitem;
        else
            % If your triggers store them in .type or .value, adapt here
            condStr = 'UnknownCondition';
            itemStr = 'UnknownItem';
        end
        
        if isnumeric(condStr), condStr = num2str(condStr); end
        if isnumeric(itemStr), itemStr = num2str(itemStr); end
        
        currentKey = sprintf('%s_%s', condStr, itemStr);
        
        if isKey(boundaryMap, currentKey)
            regionBoundaries = boundaryMap(currentKey);
            
            % Option 1: store as a matrix in a single field
            EEG.event(iEvt).regionBoundaries = regionBoundaries;
            
           
           
            %% This is to be implemented 
            % Option 2: store each region start/end separately
            % for r = 1:size(regionBoundaries,1)
            %     startField = sprintf('region%d_start', r);
            %     endField   = sprintf('region%d_end', r);
            %     EEG.event(iEvt).(startField) = regionBoundaries(r,1);
            %     EEG.event(iEvt).(endField)   = regionBoundaries(r,2);
            % end
            
            numAssigned = numAssigned + 1;
        else
            % Not found in the map, so this event won't have regionBoundaries
            % It's not necessarily an error—maybe it's a practice trial or something
        end
    end
    
    fprintf('Merged IA boundaries with %d EEG.event entries.\n', numAssigned);
    fprintf('Done. You can now use these boundaries for region-of-fixation assignment.\n');