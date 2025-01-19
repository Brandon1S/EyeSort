function save_filter_setup_input()
    % Get the handle to the GUI
    fig = gcf;

    % Retrieve shared data
    data = guidata(fig);
    if isempty(data)
        data = struct();
    end

    %% Collect Inputs
    % 1. Loaded EEG Datasets
    datasetDropdown = findobj(fig, 'tag', 'datasetDropdown');
    if ~isempty(datasetDropdown)
        datasetList = get(datasetDropdown, 'string');
        if iscell(datasetList)
            data.datasets = datasetList; % Save datasets
        else
            data.datasets = {datasetList};
        end
    end

    % 2. Loaded Interest Areas
    IADropdown = findobj(fig, 'tag', 'IADropdown');
    if ~isempty(IADropdown)
        IAList = get(IADropdown, 'string');
        if iscell(IAList)
            data.interestAreas = IAList; % Save interest areas
        else
            data.interestAreas = {IAList};
        end
    end

    % 3. Number of Regions
    numRegionsField = findobj(fig, 'tag', 'numRegions');
    if ~isempty(numRegionsField)
        numRegionsStr = get(numRegionsField, 'string');
        data.numRegions = str2double(numRegionsStr); % Convert to numeric
        if isnan(data.numRegions) || data.numRegions <= 0
            warndlg('Please enter a valid number of regions.');
            return;
        end
    end

    % 4. Trial Codes
    trialCodesField = findobj(fig, 'tag', 'trialcodes');
    if ~isempty(trialCodesField)
        trialCodes = get(trialCodesField, 'string');
        data.trialCodes = strsplit(trialCodes, '\n'); % Split into cell array
        data.trialCodes = data.trialCodes(~cellfun('isempty', data.trialCodes)); % Remove empty lines
    end

    %% Save All Inputs to Shared Data
    guidata(fig, data);

    %% Proceed to the Next Step
    % Here, you can add functionality to move to the next GUI or process inputs
    disp('All inputs saved successfully!');
    disp(data); % Display saved data for debugging

  
    % close(fig);
    
end

