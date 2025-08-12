function [EEG, com] = pop_load_text_ia(EEG)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                          Option 1:                              %            
    %         Text based sentence contents for each interest area.    %
    %                (For single line reading studies)                %
    %                                                                 %
    %                                                                 %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Initialize outputs
    com = '';
    if nargin < 1
        EEG = eeg_emptyset;
    end
    
    txtFileList = {};
    
    % Clear any stale intermediate dataset settings from previous sessions
    try
        evalin('base', 'clear eyesort_save_intermediate eyesort_intermediate_save_dir eyesort_config_saved_to');
    catch
        % Variables don't exist, no problem
    end
    
    geomhoriz = { ...
        [1 0.5]       % Text File and browse button
        1             % Dataset listbox
        1             % Spacer for Save/Load section
        [0.33 0.33 0.34]   % Save config, Load config, Load last config buttons
        1             % Description of Save Intermediate button
        1             % Save Intermediate button
        1             % Parameters from interest area file
        [2 1 0.24]     % Offset edit box + help button
        [2 1 0.24]     % Pixels per char edit box + help button
        [2 1 0.24]     % Number of regions edit box + help button
        [1 2 0.24]     % Region names edit box + help button
        [2 1 0.24]     % Condition type column name edit box + help button
        [2 1 0.24]     % Condition code column name edit box + help button
        [2 1 0.24]     % Item code column name edit box + help button
        1             % EEG event codes
        [2 1 0.24]     % Start Code + help button
        [2 1 0.24]     % End Code + help button
        1             % Use sentence codes checkbox
        [2 1 0.24]     % Sentence Start Code + help button
        [2 1 0.24]     % Sentence End Code + help button
        [2 1 0.24]     % Condition Triggers + help button
        [2 1 0.24]     % Item Triggers + help button
        1             % Eye-Tracking event names (from EYE-EEG synchronization)
        1             % Customize event names checkbox
        [2 1 0.24]     % Fixation Event Type + help button
        [2 1 0.24]     % Fixation X Position Field + help button
        [2 1 0.24]     % Saccade Event Type + help button
        [2 1 0.24]     % Saccade Start X Position Field + help button
        [2 1 0.24]     % Saccade End X Position Field + help button
        1             % Spacer
        [0.5 0.2 0.2] % Cancel and confirm buttons
    };

    % Vertical geometry - heights for each row (must match geomhoriz - 31 rows)
    geomvert = [3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3];

    % Labels and dropdown menu
    uilist = { ...
        
        {'Style','text','String','Select the interest area (.txt) file containing the trial and interest area information:', 'FontWeight', 'Bold'}, ...
        {'Style','pushbutton','String','Browse','callback', @browseTxtFile}, ...
        ...
        {'Style', 'listbox', 'tag', 'datasetList', 'string', {}, 'Max', 10, 'Min', 1, 'HorizontalAlignment', 'left'}, ...
        ...
        {'Style','text','String','Global Study Parameters:', 'FontWeight', 'Bold'}, ...
        ...
        {'Style','pushbutton','String','Save Configuration','callback', @save_config_callback}, ...
        {'Style','pushbutton','String','Load Configuration','callback', @load_config_callback}, ...
        {'Style','pushbutton','String','Load Previous Configuration','callback', @load_last_config_callback}, ...
        ...
        {'Style','text','String','Save Intermediate Dataset(s): After interest area processing, but before Eye-Event Labeling', 'FontWeight', 'Bold'}, ...
        ...
        {'Style','pushbutton','String','Save Intermediate Dataset(s)','callback', @save_intermediate_callback}, ...
        ...
        {'Style','text','String','──────────Parameters from Interest Area file────────────────────────────────────', 'FontWeight', 'Bold'}, ...
        ... 
        {'Style','text','String','Sentence Offset in Pixels:'}, ...
        {'Style','edit','String','','tag','edtOffset','UserData','281','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('offset'),'FontSize',8}, ...
        ...
        {'Style','text','String','Pixels-Per-Character:' }, ...
        {'Style','edit','String','','tag','edtPxPerChar','UserData','14','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('pxPerChar'),'FontSize',8}, ...
        ...
        {'Style','text','String','Number of Interest Regions:'}, ...
        {'Style','edit','String','','tag','edtNumRegions','UserData','4','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('numRegions'),'FontSize',8}, ...
        ...
        {'Style','text','String','Region Names (comma-separated):'}, ...
        {'Style','edit','String','','tag','edtRegionNames','UserData','Beginning, PreTarget, Target_word, Ending','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('regionNames'),'FontSize',8}, ...
        ...
        {'Style', 'text', 'String', 'Condition Label Column Name(s) (used in BDF generation):'}, ...
        {'Style','edit','String','','tag','edtCondType','UserData','condition','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('condType'),'FontSize',8}, ...
        ...
        {'Style','text','String','Condition Trigger Code Column Name:'}, ...
        {'Style','edit','String','','tag','edtCondName','UserData','trigcondition','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('condName'),'FontSize',8}, ...
        ...
        {'Style','text','String','Item Trigger Code Column Name:'}, ...
        {'Style','edit','String','','tag','edtItemName','UserData','trigitem','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('itemName'),'FontSize',8}, ...
        ...
        {'Style','text','String','──────────EEG Event Codes────────────────────────────────────────────', 'FontWeight', 'Bold'}, ...
        ...
        {'Style','text','String','Start Trial Code:'}, ...
        {'Style','edit','String','','tag','edtStartCode','UserData','S254','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('startCode'),'FontSize',8}, ...
        ...
        {'Style','text','String','End Trial Code:'}, ...
        {'Style','edit','String','','tag','edtEndCode','UserData','S255','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('endCode'),'FontSize',8}, ...
        ...
        {'Style','checkbox','String','Eye-Event Time Window (Optional): ','tag','chkUseSentenceCodes','Value',0, 'callback',@toggle_sentence_codes}, ...
        ...
        {'Style','text','String','Stimulus Start Code:'}, ...
        {'Style','edit','String','','tag','edtSentenceStartCode','UserData','S250','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder,'Enable','off'}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('sentenceStart'),'FontSize',8}, ...
        ...
        {'Style','text','String','Stimulus End Code:'}, ...
        {'Style','edit','String','','tag','edtSentenceEndCode','UserData','S251','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder,'Enable','off'}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('sentenceEnd'),'FontSize',8}, ...
        ...
        {'Style','text','String','Condition Triggers (comma-separated):'}, ...
        {'Style','edit','String','','tag','edtCondTriggers','UserData','S211, S213, S221, S223','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('condTriggers'),'FontSize',8}, ...
        ...
        {'Style','text','String','Item Triggers (comma-separated):'}, ...
        {'Style','edit','String','','tag','edtItemTriggers','UserData','S1:S112','Callback',@placeholder_callback,'KeyPressFcn',@clear_placeholder}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('itemTriggers'),'FontSize',8}, ...
        ...
        {'Style','text','String','──────────Eye-Tracking Event Names (from EYE-EEG Synchronization)────────────────────────', 'FontWeight', 'Bold'}, ...
        ...
        {'Style','checkbox','String','Change default event field names (Optional):','tag','chkCustomizeEventNames','Value',0, 'callback',@toggle_event_names}, ...
        ...
        {'Style','text','String','Name of Fixation Event:'}, ...
        {'Style','edit','String','R_fixation','tag','edtFixationType','Enable','off','ForegroundColor',[0.6 0.6 0.6]}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('fixationType'),'FontSize',8}, ...
        ...
        {'Style','text','String','Name of Fixation X Position Field:'}, ...
        {'Style','edit','String','fix_avgpos_x','tag','edtFixationXField','Enable','off','ForegroundColor',[0.6 0.6 0.6]}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('fixationXField'),'FontSize',8}, ...
        ...
        {'Style','text','String','Name of Saccade Event:'}, ...
        {'Style','edit','String','R_saccade','tag','edtSaccadeType','Enable','off','ForegroundColor',[0.6 0.6 0.6]}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('saccadeType'),'FontSize',8}, ...
        ...
        {'Style','text','String','Name of Saccade Start X Position Field:'}, ...
        {'Style','edit','String','sac_startpos_x','tag','edtSaccadeStartXField','Enable','off','ForegroundColor',[0.6 0.6 0.6]}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('saccadeStartXField'),'FontSize',8}, ...
        ...
        {'Style','text','String','Name of Saccade End X Position Field:'}, ...
        {'Style','edit','String','sac_endpos_x','tag','edtSaccadeEndXField','Enable','off','ForegroundColor',[0.6 0.6 0.6]}, ...
        {'Style','pushbutton','String','?','callback',@(~,~) show_field_help('saccadeEndXField'),'FontSize',8}, ...
        ...
        {}, ...
        ...
        {}, ...
        {'Style', 'pushbutton', 'String', 'Cancel', 'callback', @(~,~) cancel_button}, ...
        {'Style', 'pushbutton', 'String', 'Confirm', 'callback', @(~,~) confirm_button}, ...
    };

     [~, ~, ~, hFig] = supergui('geomhoriz', geomhoriz, 'geomvert', geomvert, 'uilist', uilist, 'title', 'Text-Based Sentence Contents and Interest Areas');
    
    % Initialize placeholders
    init_placeholders();

%% ----------------- Nested Callback Functions -----------------
    
    % Store the chosen file path in a variable:
    function browseTxtFile(~,~)
        [fname, fpath] = uigetfile({'*.txt';'*.csv'}, 'Select IA Text File');
        figure(gcf); % Bring GUI back to front
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

    function toggle_sentence_codes(~,~)
        % Enable/disable sentence code fields based on checkbox state
        checkboxValue = get(findobj(gcf, 'tag', 'chkUseSentenceCodes'), 'Value');
        
        if checkboxValue
            % Enable the sentence code fields
            set(findobj(gcf, 'tag', 'edtSentenceStartCode'), 'Enable', 'on');
            set(findobj(gcf, 'tag', 'edtSentenceEndCode'), 'Enable', 'on');
        else
            % Disable the sentence code fields and restore placeholders
            startField = findobj(gcf, 'tag', 'edtSentenceStartCode');
            endField = findobj(gcf, 'tag', 'edtSentenceEndCode');
            set(startField, 'Enable', 'off', 'String', '');
            set(endField, 'Enable', 'off', 'String', '');
            placeholder_callback(startField, []);
            placeholder_callback(endField, []);
        end
    end

    function toggle_event_names(~,~)
        % Enable/disable event name fields based on checkbox state
        checkboxValue = get(findobj(gcf, 'tag', 'chkCustomizeEventNames'), 'Value');
        
        if checkboxValue
            % Enable the event name fields
            set(findobj(gcf, 'tag', 'edtFixationType'), 'Enable', 'on');
            set(findobj(gcf, 'tag', 'edtFixationXField'), 'Enable', 'on');
            set(findobj(gcf, 'tag', 'edtSaccadeType'), 'Enable', 'on');
            set(findobj(gcf, 'tag', 'edtSaccadeStartXField'), 'Enable', 'on');
            set(findobj(gcf, 'tag', 'edtSaccadeEndXField'), 'Enable', 'on');
        else
            % Disable the event name fields and reset to defaults
            set(findobj(gcf, 'tag', 'edtFixationType'), 'Enable', 'off', 'String', 'R_fixation', 'ForegroundColor', [0.6 0.6 0.6]);
            set(findobj(gcf, 'tag', 'edtFixationXField'), 'Enable', 'off', 'String', 'fix_avgpos_x', 'ForegroundColor', [0.6 0.6 0.6]);
            set(findobj(gcf, 'tag', 'edtSaccadeType'), 'Enable', 'off', 'String', 'R_saccade', 'ForegroundColor', [0.6 0.6 0.6]);
            set(findobj(gcf, 'tag', 'edtSaccadeStartXField'), 'Enable', 'off', 'String', 'sac_startpos_x', 'ForegroundColor', [0.6 0.6 0.6]);
            set(findobj(gcf, 'tag', 'edtSaccadeEndXField'), 'Enable', 'off', 'String', 'sac_endpos_x', 'ForegroundColor', [0.6 0.6 0.6]);
        end
    end

    function save_config_callback(~,~)
        % Gather current GUI settings into a config structure
        config = collect_gui_settings();
        if isempty(config)
            return; % Error occurred in collection
        end
        
        % Prompt user for filename
        [filename, filepath] = uiputfile('*.mat', 'Save Text IA Configuration', 'my_text_ia_config.mat');
        figure(gcf); % Bring GUI back to front
        if isequal(filename, 0)
            return; % User cancelled
        end
        
        full_filename = fullfile(filepath, filename);
        
        try
            save_text_ia_config(config, full_filename);
            % Store the custom save location for status display
            assignin('base', 'eyesort_config_saved_to', full_filename);
            msgbox(sprintf('Configuration saved successfully to:\n%s', full_filename), 'Save Complete', 'help');
            figure(gcf); % Bring GUI back to front
        catch ME
            errordlg(['Error saving configuration: ' ME.message], 'Save Error');
            figure(gcf); % Bring GUI back to front
        end
    end

    function load_config_callback(~,~)
        try
            [config, loaded_filename] = load_text_ia_config(); % Will show file dialog
            figure(gcf); % Bring GUI back to front
            if isempty(config)
                return; % User cancelled
            end
            
            % Track that configuration came from a saved file
            assignin('base', 'eyesort_config_saved_to', loaded_filename);
            
            apply_config_to_gui(config);
            msgbox('Configuration loaded successfully!', 'Load Complete', 'help');
            figure(gcf); % Bring GUI back to front
        catch ME
            errordlg(['Error loading configuration: ' ME.message], 'Load Error');
            figure(gcf); % Bring GUI back to front
        end
    end

    function load_last_config_callback(~,~)
        try
            if ~check_last_text_ia_config()
                msgbox('No previous configuration found. Use "Save Config" first to create a saved configuration.', 'No Previous Config', 'warn');
                figure(gcf); % Bring GUI back to front
                return;
            end
            
            [config, ~] = load_text_ia_config('last_text_ia_config.mat');
            apply_config_to_gui(config);
            msgbox('Last configuration loaded successfully!', 'Load Complete', 'help');
            figure(gcf); % Bring GUI back to front
        catch ME
            errordlg(['Error loading last configuration: ' ME.message], 'Load Error');
            figure(gcf); % Bring GUI back to front
        end
    end

    function save_intermediate_callback(~,~)
        % Select directory for saving intermediate datasets
        selectedDir = uigetdir(pwd, 'Select Directory for Intermediate Datasets');
        figure(gcf); % Bring GUI back to front
        if isequal(selectedDir, 0)
            return; % User cancelled
        end
        
        % Store the selected directory globally for use during processing
        assignin('base', 'eyesort_intermediate_save_dir', selectedDir);
        assignin('base', 'eyesort_save_intermediate', true);
        
        msgbox(sprintf('Intermediate datasets will be saved to:\n%s', selectedDir), 'Directory Selected', 'help');
        figure(gcf); % Bring GUI back to front
    end

    function config = collect_gui_settings()
        % Collect all current GUI settings into a configuration structure
        config = struct();
        
        try
            % Text file selection
            config.txtFileList = txtFileList;
            
            % Numeric parameters
            config.offset = get_user_input('edtOffset');
            config.pxPerChar = get_user_input('edtPxPerChar');
            config.numRegions = get_user_input('edtNumRegions');
            
            % Text parameters
            config.regionNames = get_user_input('edtRegionNames');
            config.conditionTypeColName = get_user_input('edtCondType');
            config.conditionColName = get_user_input('edtCondName');
            config.itemColName = get_user_input('edtItemName');
            config.startCode = get_user_input('edtStartCode');
            config.endCode = get_user_input('edtEndCode');
            config.sentenceStartCode = get_user_input('edtSentenceStartCode');
            config.sentenceEndCode = get_user_input('edtSentenceEndCode');
            
            % For triggers, expand ranges and save as cell arrays
            condTriggersStr = get_user_input('edtCondTriggers');
            itemTriggersStr = get_user_input('edtItemTriggers');
            
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
            
            % Save intermediate option (removed - now handled by button)
            
            % Sentence codes usage flag
            config.useSentenceCodes = get(findobj(gcf, 'tag','chkUseSentenceCodes'), 'Value');
            
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
                'conditionTypeColName', 'edtCondType', ...
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
            
            % Apply checkboxes separately
            % Save intermediate option removed - now handled by button
            
            if isfield(config, 'useSentenceCodes')
                set(findobj(gcf, 'tag', 'chkUseSentenceCodes'), 'Value', config.useSentenceCodes);
                % Trigger the callback to enable/disable sentence code fields
                toggle_sentence_codes();
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
                    
                    h = findobj('tag', gui_tag);
                    set(h, 'String', value, 'ForegroundColor', [0 0 0]); % Set to black text
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
        offsetStr = get_user_input('edtOffset');
        pxPerCharStr = get_user_input('edtPxPerChar');
        numRegionsStr = get_user_input('edtNumRegions');
        
        % Convert cell arrays to strings if necessary
        if iscell(offsetStr), offsetStr = offsetStr{1}; end
        if iscell(pxPerCharStr), pxPerCharStr = pxPerCharStr{1}; end
        if iscell(numRegionsStr), numRegionsStr = numRegionsStr{1}; end
        
        % Validate required inputs - CRITICAL: Must be non-empty strings
        if isempty(offsetStr) || ~ischar(offsetStr) || strcmp(strtrim(offsetStr), '')
            errordlg('Sentence Offset in Pixels is required', 'Missing Input');
            return;
        end
        if isempty(pxPerCharStr) || ~ischar(pxPerCharStr) || strcmp(strtrim(pxPerCharStr), '')
            errordlg('Pixels-Per-Character is required', 'Missing Input');
            return;
        end
        if isempty(numRegionsStr) || ~ischar(numRegionsStr) || strcmp(strtrim(numRegionsStr), '')
            errordlg('Number of Interest Regions is required', 'Missing Input');
            return;
        end
        
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
        
        regionNamesStr = get_user_input('edtRegionNames');
        conditionColName = get_user_input('edtCondName');
        itemColName = get_user_input('edtItemName');
        
        % Convert cell arrays to strings if necessary
        if iscell(regionNamesStr), regionNamesStr = regionNamesStr{1}; end
        if iscell(conditionColName), conditionColName = conditionColName{1}; end
        if iscell(itemColName), itemColName = itemColName{1}; end
        
        % Validate required inputs - CRITICAL: Must be non-empty strings
        if isempty(regionNamesStr) || ~ischar(regionNamesStr) || strcmp(strtrim(regionNamesStr), '')
            errordlg('Region Names is required', 'Missing Input');
            return;
        end
        if isempty(conditionColName) || ~ischar(conditionColName) || strcmp(strtrim(conditionColName), '')
            errordlg('Condition Trigger Code Column Name is required', 'Missing Input');
            return;
        end
        if isempty(itemColName) || ~ischar(itemColName) || strcmp(strtrim(itemColName), '')
            errordlg('Item Trigger Code Column Name is required', 'Missing Input');
            return;
        end
        
        % Process region names (already validated as character above)
        regionNames = strtrim(strsplit(regionNamesStr, ','));
        
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
        startCodeStr = get_user_input('edtStartCode');
        endCodeStr = get_user_input('edtEndCode');
        
        % Convert cell arrays to strings if necessary
        if iscell(startCodeStr), startCodeStr = startCodeStr{1}; end
        if iscell(endCodeStr), endCodeStr = endCodeStr{1}; end
        
        % Validate required inputs - CRITICAL: Must be strings, not empty arrays
        if isempty(startCodeStr) || ~ischar(startCodeStr) || strcmp(strtrim(startCodeStr), '')
            errordlg('Start Trial Code is required', 'Missing Input');
            return;
        end
        if isempty(endCodeStr) || ~ischar(endCodeStr) || strcmp(strtrim(endCodeStr), '')
            errordlg('End Trial Code is required', 'Missing Input');
            return;
        end
        
        % Check if user wants to use sentence codes
        useSentenceCodes = get(findobj(gcf, 'tag','chkUseSentenceCodes'), 'Value');
        if useSentenceCodes
            sentenceStartCodeStr = get_user_input('edtSentenceStartCode');
            sentenceEndCodeStr = get_user_input('edtSentenceEndCode');
            
            % Convert cell arrays to strings if necessary
            if iscell(sentenceStartCodeStr), sentenceStartCodeStr = sentenceStartCodeStr{1}; end
            if iscell(sentenceEndCodeStr), sentenceEndCodeStr = sentenceEndCodeStr{1}; end
            
            if isempty(sentenceStartCodeStr) || ~ischar(sentenceStartCodeStr) || strcmp(strtrim(sentenceStartCodeStr), '')
                errordlg('Stimulus Start Code is required when using Eye-Event Time Window', 'Missing Input');
                return;
            end
            if isempty(sentenceEndCodeStr) || ~ischar(sentenceEndCodeStr) || strcmp(strtrim(sentenceEndCodeStr), '')
                errordlg('Stimulus End Code is required when using Eye-Event Time Window', 'Missing Input');
                return;
            end
        else
            sentenceStartCodeStr = '';
            sentenceEndCodeStr = '';
        end
        condTriggersStr = get_user_input('edtCondTriggers');
        itemTriggersStr = get_user_input('edtItemTriggers');
        
        % Convert cell arrays to strings if necessary
        if iscell(condTriggersStr), condTriggersStr = condTriggersStr{1}; end
        if iscell(itemTriggersStr), itemTriggersStr = itemTriggersStr{1}; end
        
        % Validate required inputs - CRITICAL: Must be non-empty strings
        if isempty(condTriggersStr) || ~ischar(condTriggersStr) || strcmp(strtrim(condTriggersStr), '')
            errordlg('Condition Triggers is required', 'Missing Input');
            return;
        end
        if isempty(itemTriggersStr) || ~ischar(itemTriggersStr) || strcmp(strtrim(itemTriggersStr), '')
            errordlg('Item Triggers is required', 'Missing Input');
            return;
        end
        
        % Get condition type column name(s) - can be comma-separated
        conditionTypeColName = get_user_input('edtCondType');
        
        % Convert cell arrays to strings if necessary
        if iscell(conditionTypeColName), conditionTypeColName = conditionTypeColName{1}; end
        
        % Validate required input - CRITICAL: Must be non-empty string
        if isempty(conditionTypeColName) || ~ischar(conditionTypeColName) || strcmp(strtrim(conditionTypeColName), '')
            errordlg('Condition Label Column Name is required', 'Missing Input');
            return;
        end
        % Parse comma-separated column names
        conditionTypeColNames = strtrim(strsplit(conditionTypeColName, ','));
        
        % Cell arrays already converted to strings above
        
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

        % Check save status - only show popup if there are warnings
        % Check intermediate dataset status
        intermediateOK = false;
        try
            saveIntermediate = evalin('base', 'eyesort_save_intermediate');
            if saveIntermediate
                saveDir = evalin('base', 'eyesort_intermediate_save_dir');
                intermediateOK = true;
            end
        catch
            saveIntermediate = false;
        end
        
        % Check config save status
        try
            configPath = evalin('base', 'eyesort_config_saved_to');
            configMsg = sprintf('✓ Configuration: Saved to %s', configPath);
            configWarning = false;
        catch
                        configMsg = sprintf('⚠ Configuration: Not manually saved (only auto-saved and will only be temporary for your next session)\n\nIf you want to save the configuration for future use, please save it manually.');
            configWarning = true;
        end
        
        % Show popup if there are any warnings
        if ~intermediateOK || configWarning
            warnings = {};
            if ~intermediateOK
                warnings{end+1} = '⚠ Intermediate datasets: Will NOT be saved';
            end
            if configWarning
                warnings{end+1} = configMsg;
            end
            
            statusMsg = sprintf('Processing Status:\n\n%s\n\nProceed with processing?', strjoin(warnings, '\n\n'));
            choice = questdlg(statusMsg, 'Confirm Processing', 'Proceed', 'Cancel', 'Proceed');
            if strcmp(choice, 'Cancel')
                return;
            end
        end
        
        % Call the computational function with all parameters
        try
            if batch_mode
                % Process all datasets in batch mode (one at a time for memory efficiency)
                h = waitbar(0, 'Processing Text IA for all datasets...', 'Name', 'Batch Text IA Processing');
                processed_count = 0;
                failed_count = 0;
                
                % Get save intermediate option from global variables
                try
                    saveIntermediate = evalin('base', 'eyesort_save_intermediate');
                    saveDir = evalin('base', 'eyesort_intermediate_save_dir');
                catch
                    saveIntermediate = false;
                    saveDir = pwd;
                end
                
                for i = 1:length(batchFilePaths)
                    waitbar(i/length(batchFilePaths), h, sprintf('Processing dataset %d of %d: %s', i, length(batchFilePaths), strrep(batchFilenames{i}, '_', ' ')));
                    
                    try
                        % Load dataset
                        currentEEG = pop_loadset('filename', batchFilePaths{i});
                        
                        % Variables already validated as characters above
                        
                        % Process with Text IA
                        processedEEG = compute_text_based_ia(currentEEG, txtFilePath, offset, pxPerChar, ...
                                              numRegions, regionNames, conditionColName, ...
                                              itemColName, startCodeStr, endCodeStr, condTriggers, itemTriggers, ...
                                              fixationTypeStr, fixationXFieldStr, saccadeTypeStr, ...
                                              saccadeStartXFieldStr, saccadeEndXFieldStr, ...
                                              sentenceStartCodeStr, sentenceEndCodeStr, conditionTypeColNames, 'batch_mode', true);
                        
                        % Save intermediate dataset if requested
                        if saveIntermediate
                            [~, fileName, ~] = fileparts(batchFilenames{i});
                            intermediate_output_path = fullfile(saveDir, [fileName '_eyesort_ia.set']);
                            pop_saveset(processedEEG, 'filename', intermediate_output_path, 'savemode', 'twofiles');
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
                        pop_saveset(processedEEG, 'filename', temp_output_path, 'savemode', 'twofiles');
                        
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
                
                h_msg = msgbox(sprintf('Text IA processing complete!\n\nProcessed: %d datasets\nFailed: %d datasets\n\nNow proceed to step 3 (Eye-Tracking Event Labeling) to apply labels.', processed_count, failed_count), 'Batch Processing Complete');
                waitfor(h_msg); % Wait for user to close the message box
                
                % Close GUI after batch processing completion
                close(gcf);
                return; % Add return to prevent duplicate auto-save
                
            else
                % Variables already validated as characters above
                
                % Single dataset processing
                processedEEG = compute_text_based_ia(EEG, txtFilePath, offset, pxPerChar, ...
                                          numRegions, regionNames, conditionColName, ...
                                          itemColName, startCodeStr, endCodeStr, condTriggers, itemTriggers, ...
                                          fixationTypeStr, fixationXFieldStr, saccadeTypeStr, ...
                                          saccadeStartXFieldStr, saccadeEndXFieldStr, ...
                                          sentenceStartCodeStr, sentenceEndCodeStr, conditionTypeColNames);
                
                % Save intermediate dataset if requested
                try
                    saveIntermediate = evalin('base', 'eyesort_save_intermediate');
                    saveDir = evalin('base', 'eyesort_intermediate_save_dir');
                catch
                    saveIntermediate = false;
                    saveDir = pwd;
                end
                if saveIntermediate
                    if isfield(EEG, 'filename') && ~isempty(EEG.filename)
                        [~, name, ~] = fileparts(EEG.filename);
                        intermediate_path = fullfile(saveDir, [name '_eyesort_ia.set']);
                    else
                        % If no filename, use generic name in selected directory
                        intermediate_path = fullfile(saveDir, 'dataset_eyesort_ia.set');
                    end
                    
                    if ~isempty(intermediate_path)
                        pop_saveset(processedEEG, 'filename', intermediate_path, 'savemode', 'twofiles');
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

    % Initialize placeholders for edit controls (excluding eye-tracking defaults)
    function init_placeholders()
        tags = {'edtOffset','edtPxPerChar','edtNumRegions','edtRegionNames','edtCondType','edtCondName','edtItemName','edtStartCode','edtEndCode','edtSentenceStartCode','edtSentenceEndCode','edtCondTriggers','edtItemTriggers'};
        for i = 1:length(tags)
            h = findobj(gcf, 'Tag', tags{i});
            if ~isempty(h)
                placeholder_callback(h, []);
            end
        end
    end

    % Placeholder text callback
    function placeholder_callback(hObject, ~)
        userText = get(hObject, 'String');
        placeholderText = get(hObject, 'UserData');
        
        if isempty(userText)
            % Show placeholder in grey
            set(hObject, 'String', placeholderText, 'ForegroundColor', [0.6 0.6 0.6]);
        else
            % Show user text in black
            set(hObject, 'ForegroundColor', [0 0 0]);
        end
    end

    % Clear placeholder when user starts typing
    function clear_placeholder(hObject, ~)
        if isequal(get(hObject, 'ForegroundColor'), [0.6 0.6 0.6])
            set(hObject, 'String', '', 'ForegroundColor', [0 0 0]);
        end
    end

    % Get actual user input (empty if placeholder is showing)
    function value = get_user_input(tag)
        h = findobj(gcf, 'Tag', tag);
        if isempty(h)
            value = [];
            return;
        end
        
        currentText = get(h, 'String');
        isGreyText = isequal(get(h, 'ForegroundColor'), [0.6 0.6 0.6]);
        
        % Check if it's a placeholder based on:
        % 1. Grey text color AND
        % 2. Text matches the UserData (placeholder text)
        if isGreyText && ~isempty(get(h, 'UserData'))
            placeholderText = get(h, 'UserData');
            if strcmp(currentText, placeholderText)
                value = []; % This is placeholder text
            else
                value = currentText; % User entered something different
            end
        else
            value = currentText; % Not grey or no placeholder data
        end
    end
end




