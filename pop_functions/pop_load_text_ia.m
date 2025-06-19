function [EEG, com] = pop_load_text_ia(EEG)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                          Option 1:                              %            
    %         Text based sentence contents for each interest area.    %
    %                (For single line reading studies)                %
    %                                                                 %
    %                                                                 %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Initialize outputs (good practice for pop functions)
    com = '';
    if nargin < 1
        EEG = eeg_emptyset;
    end
    
    txtFileList = {};
    
    geomhoriz = { ...
        [1 0.5]       % Text File and browse button
        1             % Dataset listbox
        1             % Spacer for Save/Load section
        [0.33 0.33 0.34]   % Save config, Load config, Load last config buttons
        1             % Spacer
        [2 1]         % Offset edit box
        [2 1]         % Pixels per char edit box
        [2 1]         % Number of regions edit box
        [0.4 1]       % Region names edit box
        [2 1]         % Condition type column name edit box
        [2 1]         % Condition code column name edit box
        [2 1]         % Item code column name edit box
        [2 1]         % Start Code
        [2 1]         % End Code
        [2 1]         % Sentence Start Code
        [2 1]         % Sentence End Code
        [2 1]         % Condition Triggers
        [2 1]         % Item Triggers
        [2 1]         % Fixation Event Type
        [2 1]         % Fixation X Position Field
        [2 1]         % Saccade Event Type
        [2 1]         % Saccade Start X Position Field
        [2 1]         % Saccade End X Position Field
        1             % Spacer
        1             % Save intermediate checkbox
        [0.5 0.2 0.2] % Cancel and confirm buttons
    };

    % Labels and dropdown menu
    uilist = { ...
        
        {'Style','text','String','Select the interest area text file containing the trial and interest area information:'}, ...
        {'Style','pushbutton','String','Browse','callback', @browseTxtFile}, ...
        ...
        {'Style', 'listbox', 'tag', 'datasetList', 'string', {}, 'Max', 10, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ...
        {}, ...
        ...
        {'Style','pushbutton','String','Save Config','callback', @save_config_callback}, ...
        {'Style','pushbutton','String','Load Config','callback', @load_config_callback}, ...
        {'Style','pushbutton','String','Load Last Config','callback', @load_last_config_callback}, ...
        ...
        {}, ...
        ... 
        {'Style','text','String','Offset (in pixels):'}, ...
        {'Style','edit','String','281','tag','edtOffset'}, ...
        ...
        {'Style','text','String','Pixels per char:' }, ...
        {'Style','edit','String','14','tag','edtPxPerChar'}, ...
        ...
        {'Style','text','String','Number of regions:'}, ...
        {'Style','edit','String','4','tag','edtNumRegions'}, ...
        ...
        {'Style','text','String','Region Names (separate by comma):'}, ...
        {'Style','edit','String','Beginning, PreTarget, Target_word, Ending','tag','edtRegionNames'}, ...
        ...
        {'Style', 'text', 'String', 'Condition Type Column Name:'}, ...
        {'Style','edit','String','condition','tag','edtCondType'}, ...
        ...
        {'Style','text','String','Condition Code Column Name:'}, ...
        {'Style','edit','String','trigcondition','tag','edtCondName'}, ...
        ...
        {'Style','text','String','Item Code Column Name:'}, ...
        {'Style','edit','String','trigitem','tag','edtItemName'}, ...
        ...
        {'Style','text','String','Start Trial Code:'}, ...
        {'Style','edit','String','S254','tag','edtStartCode'}, ...
        ...
        {'Style','text','String','End Trial Code:'}, ...
        {'Style','edit','String','S255','tag','edtEndCode'}, ...
        ...
        {'Style','text','String','Sentence Start Code:'}, ...
        {'Style','edit','String','S250','tag','edtSentenceStartCode'}, ...
        ...
        {'Style','text','String','Sentence End Code:'}, ...
        {'Style','edit','String','S251','tag','edtSentenceEndCode'}, ...
        ...
        {'Style','text','String','Condition Triggers (comma-separated):'}, ...
        {'Style','edit','String','S211, S213, S221, S223','tag','edtCondTriggers'}, ...
        ...
        {'Style','text','String','Item Triggers (Can be a range: S1:S112):'}, ...
        {'Style','edit','String','S1:S112','tag','edtItemTriggers'}, ...
        ...
        {'Style','text','String','Name of Fixation Event:'}, ...
        {'Style','edit','String','R_fixation','tag','edtFixationType'}, ...
        ...
        {'Style','text','String','Name of Fixation X Position Field:'}, ...
        {'Style','edit','String','fix_avgpos_x','tag','edtFixationXField'}, ...
        ...
        {'Style','text','String','Name of Saccade Event:'}, ...
        {'Style','edit','String','R_saccade','tag','edtSaccadeType'}, ...
        ...
        {'Style','text','String','Name of Saccade Start X Position Field:'}, ...
        {'Style','edit','String','sac_startpos_x','tag','edtSaccadeStartXField'}, ...
        ...
        {'Style','text','String','Name of Saccade End X Position Field:'}, ...
        {'Style','edit','String','sac_endpos_x','tag','edtSaccadeEndXField'}, ...
        ...
        {}, ...
        ...
        {'Style','checkbox','String','Save intermediate datasets (after IA processing, before filtering)','tag','chkSaveIntermediate','Value',0}, ...
        ...
        {}, ...
        {'Style', 'pushbutton', 'String', 'Cancel', 'callback', @(~,~) cancel_button}, ...
        {'Style', 'pushbutton', 'String', 'Confirm', 'callback', @(~,~) confirm_button}, ...
    };

     [~, ~, ~, ~] = supergui('geomhoriz', geomhoriz, 'uilist', uilist, 'title', 'Load Text IA');

%% ----------------- Nested Callback Functions -----------------
    
    % Store the chosen file path in a variable:
    function browseTxtFile(~,~)
        [fname, fpath] = uigetfile({'*.txt';'*.csv'}, 'Select IA Text File');
        if isequal(fname,0)
            return; % user cancelled
        end
        filePath = fullfile(fpath,fname);

        txtFileList = { filePath };

        set(findobj(gcf, 'tag','datasetList'), 'string', txtFileList, 'value',1);
    end

    function cancel_button(~,~)
        close(gcf);
        disp('User selected cancel: No text file for text interest areas');
    end

    function save_config_callback(~,~)
        % Gather current GUI settings into a config structure
        config = collect_gui_settings();
        if isempty(config)
            return; % Error occurred in collection
        end
        
        % Prompt user for filename
        [filename, filepath] = uiputfile('*.mat', 'Save Text IA Configuration', 'my_text_ia_config.mat');
        if isequal(filename, 0)
            return; % User cancelled
        end
        
        full_filename = fullfile(filepath, filename);
        
        try
            save_text_ia_config(config, full_filename);
            msgbox(sprintf('Configuration saved successfully to:\n%s', full_filename), 'Save Complete', 'help');
        catch ME
            errordlg(['Error saving configuration: ' ME.message], 'Save Error');
        end
    end

    function load_config_callback(~,~)
        try
            config = load_text_ia_config(); % Will show file dialog
            if isempty(config)
                return; % User cancelled
            end
            
            apply_config_to_gui(config);
            msgbox('Configuration loaded successfully!', 'Load Complete', 'help');
        catch ME
            errordlg(['Error loading configuration: ' ME.message], 'Load Error');
        end
    end

    function load_last_config_callback(~,~)
        try
            if ~check_last_text_ia_config()
                msgbox('No previous configuration found. Use "Save Config" first to create a saved configuration.', 'No Previous Config', 'warn');
                return;
            end
            
            config = load_text_ia_config('last_text_ia_config.mat');
            apply_config_to_gui(config);
            msgbox('Last configuration loaded successfully!', 'Load Complete', 'help');
        catch ME
            errordlg(['Error loading last configuration: ' ME.message], 'Load Error');
        end
    end

    function config = collect_gui_settings()
        % Collect all current GUI settings into a configuration structure
        config = struct();
        
        try
            % Text file selection
            config.txtFileList = txtFileList;
            
            % Numeric parameters
            config.offset = get(findobj('tag','edtOffset'), 'String');
            config.pxPerChar = get(findobj('tag','edtPxPerChar'), 'String');
            config.numRegions = get(findobj('tag','edtNumRegions'), 'String');
            
            % Text parameters
            config.regionNames = get(findobj('tag','edtRegionNames'), 'String');
            config.conditionColName = get(findobj('tag','edtCondName'), 'String');
            config.itemColName = get(findobj('tag','edtItemName'), 'String');
            config.startCode = get(findobj('tag','edtStartCode'), 'String');
            config.endCode = get(findobj('tag','edtEndCode'), 'String');
            config.sentenceStartCode = get(findobj('tag','edtSentenceStartCode'), 'String');
            config.sentenceEndCode = get(findobj('tag','edtSentenceEndCode'), 'String');
            
            % For triggers, expand ranges and save as cell arrays
            condTriggersStr = get(findobj('tag','edtCondTriggers'), 'String');
            itemTriggersStr = get(findobj('tag','edtItemTriggers'), 'String');
            
            % Convert cell arrays to strings if necessary
            if iscell(condTriggersStr), condTriggersStr = condTriggersStr{1}; end
            if iscell(itemTriggersStr), itemTriggersStr = itemTriggersStr{1}; end
            
            % Process condition triggers (simple comma separation)
            config.condTriggers = strtrim(strsplit(condTriggersStr, ','));
            
            % Process item triggers (use helper for complex range expansion)
            config.itemTriggers = expand_trigger_ranges(itemTriggersStr);
            
            % Field name parameters
            config.fixationType = get(findobj('tag','edtFixationType'), 'String');
            config.fixationXField = get(findobj('tag','edtFixationXField'), 'String');
            config.saccadeType = get(findobj('tag','edtSaccadeType'), 'String');
            config.saccadeStartXField = get(findobj('tag','edtSaccadeStartXField'), 'String');
            config.saccadeEndXField = get(findobj('tag','edtSaccadeEndXField'), 'String');
            
            % Save intermediate option
            config.saveIntermediate = get(findobj('tag','chkSaveIntermediate'), 'Value');
            
            % Convert cell arrays to strings if necessary (except triggers which should stay as cell arrays)
            fields = fieldnames(config);
            for i = 1:length(fields)
                field_name = fields{i};
                if iscell(config.(field_name)) && ~strcmp(field_name, 'txtFileList') && ...
                   ~strcmp(field_name, 'condTriggers') && ~strcmp(field_name, 'itemTriggers')
                    config.(field_name) = config.(field_name){1};
                end
            end
            
        catch ME
            errordlg(['Error collecting GUI settings: ' ME.message], 'Collection Error');
            config = [];
        end
    end

    function apply_config_to_gui(config)
        % Apply loaded configuration to GUI controls
        try
            % Text file selection
            if isfield(config, 'txtFileList') && ~isempty(config.txtFileList)
                txtFileList = config.txtFileList;
                set(findobj(gcf, 'tag','datasetList'), 'string', txtFileList, 'value', 1);
            end
            
            % Apply all text field values
            field_mapping = struct(...
                'offset', 'edtOffset', ...
                'pxPerChar', 'edtPxPerChar', ...
                'numRegions', 'edtNumRegions', ...
                'regionNames', 'edtRegionNames', ...
                'conditionColName', 'edtCondName', ...
                'itemColName', 'edtItemName', ...
                'startCode', 'edtStartCode', ...
                'endCode', 'edtEndCode', ...
                'sentenceStartCode', 'edtSentenceStartCode', ...
                'sentenceEndCode', 'edtSentenceEndCode', ...
                'condTriggers', 'edtCondTriggers', ...
                'itemTriggers', 'edtItemTriggers', ...
                'fixationType', 'edtFixationType', ...
                'fixationXField', 'edtFixationXField', ...
                'saccadeType', 'edtSaccadeType', ...
                'saccadeStartXField', 'edtSaccadeStartXField', ...
                'saccadeEndXField', 'edtSaccadeEndXField');
            
            % Apply checkbox separately
            if isfield(config, 'saveIntermediate')
                set(findobj('tag', 'chkSaveIntermediate'), 'Value', config.saveIntermediate);
            end
            
            config_fields = fieldnames(field_mapping);
            for i = 1:length(config_fields)
                field_name = config_fields{i};
                gui_tag = field_mapping.(field_name);
                
                if isfield(config, field_name)
                    value = config.(field_name);
                    
                    % Convert cell arrays back to comma-separated strings for GUI display
                    if iscell(value)
                        if strcmp(field_name, 'condTriggers') || strcmp(field_name, 'itemTriggers')
                            % For triggers, create comma-separated string
                            value = strjoin(value, ', ');
                        elseif ~strcmp(field_name, 'txtFileList')
                            % For other cell arrays (shouldn't happen but just in case)
                            value = value{1};
                        end
                    end
                    
                    set(findobj('tag', gui_tag), 'String', value);
                end
            end
            
        catch ME
            errordlg(['Error applying configuration to GUI: ' ME.message], 'Apply Error');
        end
    end

    function confirm_button(~,~)
                % Check if we're in batch mode
        batch_mode = false;
        batchFilePaths = {};
        batchFilenames = {};
        outputDir = '';
        
        try
            batch_mode = evalin('base', 'eyesort_batch_mode');
            if batch_mode
                batchFilePaths = evalin('base', 'eyesort_batch_file_paths');
                batchFilenames = evalin('base', 'eyesort_batch_filenames');
                outputDir = evalin('base', 'eyesort_batch_output_dir');
                fprintf('Batch mode detected: Processing %d datasets\n', length(batchFilePaths));
            end
        catch
            % Not in batch mode, continue with single dataset
        end
        
        % Get current EEG from base workspace for single dataset mode
        if ~batch_mode
            try
                EEG = evalin('base', 'EEG');
            catch ME
                errordlg('No EEG dataset loaded in EEGLAB.', 'Error');
                return;
            end
        else
            % Load first dataset as reference for validation
            try
                EEG = pop_loadset('filename', batchFilePaths{1});
            catch ME
                errordlg('Could not load first dataset for validation.', 'Error');
                return;
            end
        end
        
        % Gather parameters from GUI and ensure proper type conversion
        offsetStr = get(findobj('tag','edtOffset'), 'String');
        pxPerCharStr = get(findobj('tag','edtPxPerChar'), 'String');
        numRegionsStr = get(findobj('tag','edtNumRegions'), 'String');
        
        % Convert cell arrays to strings if necessary
        if iscell(offsetStr), offsetStr = offsetStr{1}; end
        if iscell(pxPerCharStr), pxPerCharStr = pxPerCharStr{1}; end
        if iscell(numRegionsStr), numRegionsStr = numRegionsStr{1}; end
        
        % Convert to numbers and validate
        offset = str2double(offsetStr);
        pxPerChar = str2double(pxPerCharStr);
        numRegions = str2double(numRegionsStr);
        
        % Validate numeric conversions
        if any(isnan([offset, pxPerChar, numRegions])) || ...
           ~isscalar(offset) || ~isscalar(pxPerChar) || ~isscalar(numRegions)
            errordlg('Invalid numeric input for offset, pixels per char, or number of regions', 'Invalid Input');
            return;
        end
        
        % Ensure numRegions is a positive integer
        numRegions = floor(abs(numRegions));
        if numRegions <= 0
            errordlg('Number of regions must be positive', 'Invalid Input');
            return;
        end
        
        regionNamesStr = get(findobj('tag','edtRegionNames'), 'String');
        conditionColName = get(findobj('tag','edtCondName'), 'String');
        itemColName = get(findobj('tag','edtItemName'), 'String');
        
        % Convert cell arrays to strings if necessary
        if iscell(regionNamesStr), regionNamesStr = regionNamesStr{1}; end
        if iscell(conditionColName), conditionColName = conditionColName{1}; end
        if iscell(itemColName), itemColName = itemColName{1}; end
        
        % Process region names
        if ischar(regionNamesStr)
            regionNames = strtrim(strsplit(regionNamesStr, ','));
        else
            errordlg('Region names must be a comma-separated string.', 'Invalid Input');
            return;
        end
        
        % Validate region names match number of regions
        if length(regionNames) ~= numRegions
            errordlg(sprintf('Number of region names (%d) does not match number of regions (%d)', ...
                    length(regionNames), numRegions), 'Invalid Input');
            return;
        end

        % Validate the user selected a file
        if isempty(txtFileList)
            errordlg('No text file selected. Please browse for a file.','File Missing');
            return;
        end

        % If only one file is expected, take the first cell
        txtFilePath = txtFileList{1};

        % Get new parameters from GUI
        startCodeStr = get(findobj('tag','edtStartCode'), 'String');
        endCodeStr = get(findobj('tag','edtEndCode'), 'String');
        sentenceStartCodeStr = get(findobj('tag','edtSentenceStartCode'), 'String');
        sentenceEndCodeStr = get(findobj('tag','edtSentenceEndCode'), 'String');
        condTriggersStr = get(findobj('tag','edtCondTriggers'), 'String');
        itemTriggersStr = get(findobj('tag','edtItemTriggers'), 'String');
        
        % Convert cell arrays to strings if necessary
        if iscell(startCodeStr), startCodeStr = startCodeStr{1}; end
        if iscell(endCodeStr), endCodeStr = endCodeStr{1}; end
        if iscell(sentenceStartCodeStr), sentenceStartCodeStr = sentenceStartCodeStr{1}; end
        if iscell(sentenceEndCodeStr), sentenceEndCodeStr = sentenceEndCodeStr{1}; end
        if iscell(condTriggersStr), condTriggersStr = condTriggersStr{1}; end
        if iscell(itemTriggersStr), itemTriggersStr = itemTriggersStr{1}; end
        
        % Parse comma-separated lists into cell arrays
        condTriggers = strtrim(strsplit(condTriggersStr, ','));
        
        % Expand item triggers for immediate processing (ranges like "S1:S112" → cell array)
        itemTriggers = expand_trigger_ranges(itemTriggersStr);
        
        % Display the expanded item triggers for verification
        if length(itemTriggers) > 10
            fprintf('Generated %d item triggers: %s ... %s\n', length(itemTriggers), ...
                    strjoin(itemTriggers(1:5), ', '), strjoin(itemTriggers(end-4:end), ', '));
        else
            fprintf('Generated item triggers: %s\n', strjoin(itemTriggers, ', '));
        end

        % Get new field name parameters from GUI
        fixationTypeStr = get(findobj('tag','edtFixationType'), 'String');
        fixationXFieldStr = get(findobj('tag','edtFixationXField'), 'String');
        saccadeTypeStr = get(findobj('tag','edtSaccadeType'), 'String');
        saccadeStartXFieldStr = get(findobj('tag','edtSaccadeStartXField'), 'String');
        saccadeEndXFieldStr = get(findobj('tag','edtSaccadeEndXField'), 'String');
        
        % Convert cell arrays to strings if necessary
        if iscell(fixationTypeStr), fixationTypeStr = fixationTypeStr{1}; end
        if iscell(fixationXFieldStr), fixationXFieldStr = fixationXFieldStr{1}; end
        if iscell(saccadeTypeStr), saccadeTypeStr = saccadeTypeStr{1}; end
        if iscell(saccadeStartXFieldStr), saccadeStartXFieldStr = saccadeStartXFieldStr{1}; end
        if iscell(saccadeEndXFieldStr), saccadeEndXFieldStr = saccadeEndXFieldStr{1}; end
        
        % Validate that all required field names are provided
        if isempty(fixationTypeStr) || isempty(fixationXFieldStr) || ...
           isempty(saccadeTypeStr) || isempty(saccadeStartXFieldStr) || ...
           isempty(saccadeEndXFieldStr)
            errordlg('All field names must be specified. Please fill in all fields.', 'Missing Input');
            return;
        end

        % Call the computational function with all parameters
        try
            if batch_mode
                % Process all datasets in batch mode (one at a time for memory efficiency)
                h = waitbar(0, 'Processing Text IA for all datasets...', 'Name', 'Batch Text IA Processing');
                processed_count = 0;
                failed_count = 0;
                
                % Get save intermediate option
                saveIntermediate = get(findobj('tag','chkSaveIntermediate'), 'Value');
                
                for i = 1:length(batchFilePaths)
                    waitbar(i/length(batchFilePaths), h, sprintf('Processing dataset %d of %d: %s', i, length(batchFilePaths), batchFilenames{i}));
                    
                    try
                        % Load dataset
                        currentEEG = pop_loadset('filename', batchFilePaths{i});
                        
                        % Process with Text IA
                        processedEEG = compute_text_based_ia(currentEEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, conditionColName, ...
                                              itemColName, startCodeStr, endCodeStr, condTriggers, itemTriggers, ...
                                              fixationTypeStr, fixationXFieldStr, saccadeTypeStr, ...
                                              saccadeStartXFieldStr, saccadeEndXFieldStr, ...
                                              sentenceStartCodeStr, sentenceEndCodeStr, 'batch_mode', true);
                        
                        % Save intermediate dataset if requested
                        if saveIntermediate
                            [~, fileName, ~] = fileparts(batchFilenames{i});
                            intermediate_output_path = fullfile(outputDir, [fileName '_eyesort_ia.set']);
                            pop_saveset(processedEEG, 'filename', intermediate_output_path, 'savemode', 'onefile');
                            fprintf('Intermediate dataset saved: %s\n', [fileName '_eyesort_ia.set']);
                        end
                        
                        % Save processed dataset (temporary file for next step)
                        [~, fileName, ~] = fileparts(batchFilenames{i});
                        
                        % Create temporary directory for intermediate files
                        temp_dir = fullfile(tempdir, 'eyesort_temp');
                        if ~exist(temp_dir, 'dir')
                            mkdir(temp_dir);
                        end
                        
                        temp_output_path = fullfile(temp_dir, [fileName '_textia_temp.set']);
                        pop_saveset(processedEEG, 'filename', temp_output_path, 'savemode', 'onefile');
                        
                        % Update the file path to point to processed version
                        batchFilePaths{i} = temp_output_path;
                        
                        processed_count = processed_count + 1;
                        fprintf('Successfully processed: %s\n', batchFilenames{i});
                        
                        % Clear from memory
                        clear currentEEG processedEEG;
                        
                    catch ME
                        warning('Failed to process dataset %s: %s', batchFilenames{i}, ME.message);
                        failed_count = failed_count + 1;
                    end
                end
                
                delete(h);
                
                % Update batch file paths with processed versions
                assignin('base', 'eyesort_batch_file_paths', batchFilePaths);
                
                % Auto-save current configuration before showing completion message
                try
                    config = collect_gui_settings();
                    if ~isempty(config)
                        save_text_ia_config(config, 'last_text_ia_config.mat');
                    end
                catch
                    % Don't fail the main process if auto-save fails
                    fprintf('Note: Could not auto-save configuration (this is not critical)\n');
                end
                
                % Load the first processed dataset for GUI display
                try
                    firstProcessedEEG = pop_loadset('filename', batchFilePaths{1});
                    % Ensure EEG structure is properly formatted for EEGLAB
                    if ~isfield(firstProcessedEEG, 'saved')
                        firstProcessedEEG.saved = 'no';
                    end
                    assignin('base', 'EEG', firstProcessedEEG);
                    processedEEG = firstProcessedEEG; % For the local variable
                                    catch ME
                        warning('EYESORT:LoadError', 'Could not load first processed dataset: %s', ME.message);
                        processedEEG = EEG; % Use original
                end
                
                h_msg = msgbox(sprintf('Text IA processing complete!\n\nProcessed: %d datasets\nFailed: %d datasets\n\nNow proceed to step 3 (Filter Datasets) to apply filters.', processed_count, failed_count), 'Batch Processing Complete');
                waitfor(h_msg); % Wait for user to close the message box
                
                % Close GUI after batch processing completion
                close(gcf);
                return; % Add return to prevent duplicate auto-save
                
            else
                % Single dataset processing
                processedEEG = compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                                          numRegions, regionNames, conditionColName, ...
                                          itemColName, startCodeStr, endCodeStr, condTriggers, itemTriggers, ...
                                          fixationTypeStr, fixationXFieldStr, saccadeTypeStr, ...
                                          saccadeStartXFieldStr, saccadeEndXFieldStr, ...
                                          sentenceStartCodeStr, sentenceEndCodeStr);
                
                % Save intermediate dataset if requested
                saveIntermediate = get(findobj('tag','chkSaveIntermediate'), 'Value');
                if saveIntermediate
                    if isfield(EEG, 'filename') && ~isempty(EEG.filename)
                        [filepath, name, ~] = fileparts(fullfile(EEG.filepath, EEG.filename));
                        intermediate_path = fullfile(filepath, [name '_eyesort_ia.set']);
                    else
                        % If no filename, prompt user for save location
                        [filename, filepath] = uiputfile('*.set', 'Save Intermediate Dataset', 'dataset_eyesort_ia.set');
                        if ~isequal(filename, 0)
                            intermediate_path = fullfile(filepath, filename);
                        else
                            intermediate_path = ''; % User cancelled
                        end
                    end
                    
                    if ~isempty(intermediate_path)
                        pop_saveset(processedEEG, 'filename', intermediate_path, 'savemode', 'onefile');
                        fprintf('Intermediate dataset saved: %s\n', intermediate_path);
                    end
                end
                
                % Store processed data back to base workspace
                % Ensure EEG structure is properly formatted for EEGLAB
                if ~isfield(processedEEG, 'saved')
                    processedEEG.saved = 'no';
                end
                assignin('base', 'EEG', processedEEG);
                
                % Note: Avoiding eeglab('redraw') to prevent GUI issues
            end
            
            % Auto-save current configuration for future use
            try
                config = collect_gui_settings();
                if ~isempty(config)
                    save_text_ia_config(config, 'last_text_ia_config.mat');
                end
            catch
                % Don't fail the main process if auto-save fails
                fprintf('Note: Could not auto-save configuration (this is not critical)\n');
            end

            % Update command string for history
            com = sprintf('EEG = pop_loadTextIA(EEG); %% file=%s offset=%g px=%g',...
                     txtFilePath, offset, pxPerChar);

            % Close GUI
            close(gcf);
            
        catch ME
            errordlg(['Error: ' ME.message], 'Error');
            return;
        end
    end
end




