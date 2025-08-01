function [EEG, com] = pop_generate_bdf(EEG)
% POP_GENERATE_BDF - GUI wrapper for generate_bdf_file function
%
% Usage:
%   >> [EEG, com] = pop_generate_bdf(EEG);
%
% Inputs:
%   EEG   - EEGLAB EEG structure or ALLEEG array with labeled events
%
% Outputs:
%   EEG   - Same as input EEG
%   com   - Command string for EEGLAB history
%
% This function presents a GUI to create a BINLISTER Bin Descriptor File (BDF)
% from labeled events in EEG datasets. The BDF file can then be used with 
% EEGLAB's BINLISTER function for further processing.
%
% See also: generate_bdf_file, pop_label_datasets

    % Initialize output
    com = '';
    
    % If no EEG input, try to get it from base workspace
    if nargin < 1
        try
            EEG = evalin('base', 'EEG');
        catch
            try
                EEG = evalin('base', 'ALLEEG');
            catch
                errordlg('No EEG or ALLEEG found in EEGLAB workspace.', 'Error');
                return;
            end
        end
    end
    
    % Validate input
    if isempty(EEG)
        errordlg('EEG dataset is empty. Please load Labeled datasets first.', 'Error');
        return;
    end
    
    % Check if EEG is labeled
    hasLabeledEvents = false;
    
    if length(EEG) > 1
        % Check multiple datasets
        for i = 1:length(EEG)
            if ~isempty(EEG(i)) && isfield(EEG(i), 'event') && ~isempty(EEG(i).event)
                % Check for 6-digit event codes (labeled events)
                for j = 1:length(EEG(i).event)
                    if isfield(EEG(i).event(j), 'type') && ischar(EEG(i).event(j).type) && ...
                            length(EEG(i).event(j).type) == 6 && all(isstrprop(EEG(i).event(j).type, 'digit'))
                        hasLabeledEvents = true;
                        break;
                    end
                end
                if hasLabeledEvents
                    break;
                end
            end
        end
    else
        % Check single dataset
        if isfield(EEG, 'event') && ~isempty(EEG.event)
            for i = 1:length(EEG.event)
                if isfield(EEG.event(i), 'type') && ischar(EEG.event(i).type) && ...
                        length(EEG.event(i).type) == 6 && all(isstrprop(EEG.event(i).type, 'digit'))
                    hasLabeledEvents = true;
                    break;
                end
            end
        end
    end
    
    if ~hasLabeledEvents
        errordlg('No labeled events found in the dataset(s). Please run labeling first.', 'Error');
        return;
    end
    
    % Create the figure for the GUI
    hFig = figure('Name','Generate BINLISTER BDF File', ...
                  'NumberTitle','off', ...
                  'MenuBar','none', ...
                  'ToolBar','none', ...
                  'Color',[0.94 0.94 0.94], ...
                  'Resize', 'off', ...
                  'Position', [300 300 450 250]);
    
    % Define the UI controls
    uicontrol('Style', 'text', ...
              'String', 'Generate BINLISTER Bin Descriptor File', ...
              'FontSize', 14, ...
              'FontWeight', 'bold', ...
              'Position', [20 200 410 30]);
          
    % Description text
    uicontrol('Style', 'text', ...
              'String', ['This will analyze the 6-digit label codes in your labeled datasets ' ...
                         'and create a BINLISTER compatible bin descriptor file (BDF).' char(10) ...
                         'The BDF can be used with BINLISTER for further analysis.'], ...
              'Position', [20 130 410 60], ...
              'HorizontalAlignment', 'left');
    
    % Dataset info text
    if length(EEG) > 1
        datasetText = sprintf('Analyzing %d labeled datasets', length(EEG));
    else
        datasetText = 'Analyzing current labeled dataset';
    end
    
    uicontrol('Style', 'text', ...
              'String', datasetText, ...
              'Position', [20 100 410 20], ...
              'HorizontalAlignment', 'left', ...
              'FontWeight', 'bold');
    
    % Buttons
    uicontrol('Style', 'pushbutton', ...
              'String', 'Cancel', ...
              'Position', [120 20 100 40], ...
              'Callback', @cancelCallback);
          
    uicontrol('Style', 'pushbutton', ...
              'String', 'Generate BDF', ...
              'Position', [230 20 100 40], ...
              'Callback', @generateCallback);
    
    % Wait for user interaction
    uiwait(hFig);
    
    % Callback functions
    function cancelCallback(~, ~)
        close(hFig);
    end
    
    function generateCallback(~, ~)
        try
            % Close the dialog first
            close(hFig);
            
            % Generate BDF file - let it auto-detect datasets from workspace
            % This allows it to find ALLEEG if available, or fall back to EEG
            % The function will handle its own file dialog
            generate_bdf_file();
            
            % Create command string for history
            com = sprintf('EEG = pop_generate_bdf(EEG);');
            
            % Show success message
            msgbox('BDF file created successfully!', 'Success');
            
        catch ME
            % Error handling
            errordlg(['Error generating BDF file: ' ME.message], 'Error');
        end
    end
end 