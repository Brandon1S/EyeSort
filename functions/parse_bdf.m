function [binRules, isValid, errors] = parse_bdf(bdfPath)

% PARSE_BDF
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Serves as a preparatory step to esnure the event data and BDF are %
% compatible with BINLISTER                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Parses a Bin Descriptor File (BDF) and returns structured binning rules.
%
% INPUTS:
%   bdfPath  - (string) Path to the Bin Descriptor File (BDF).
%
% OUTPUTS:
%   binRules - (struct) Structured representation of parsed bins.
%              Fields include:
%                  .binNumber    : Bin number (integer).
%                  .description  : Text description of the bin (string).
%                  .conditions   : Cell array of condition strings.
%   isValid  - (logical) True if the BDF file is valid, false otherwise.
%   errors   - (cell) List of parsing errors or empty if none.
%
% EXAMPLE USAGE:
%   [binRules, isValid, errors] = parse_bdf('my_bdf_file.txt');
%   if isValid
%       disp(binRules);
%   else
%       disp('Errors found:');
%       disp(errors);
%   end

% Initialize output variables

binRules = struct('binNumber', {}, 'description', {}, 'conditions', {});
isValid = true;
errors = {};

% Check if the file exists
if ~isfile(bdfPath)
    
    isValid = false;
    
    errors{end+1} = ['File not found: ' bdfPath];
    
    return;

end

% Read the BDF file
try

    bdfLines = readlines(bdfPath, 'EmptyLineRule', 'skip');

catch ME

    isValid = false;

    errors{end+1} = ['Error reading file: ' ME.message];

    return;

end

% Parse the BDF file line by line

currentBin = struct('binNumber', [], 'description', '', 'conditions', {});

state = 0; % State machine: 0 = bin number, 1 = description, 2 = conditions

for i = 1:numel(bdfLines)

    line = strtrim(bdfLines(i));
    
    % Skip comments or empty lines
    if isempty(line) || startsWith(line, '%') || startsWith(line, '//')

        continue;

    end
    
    % State machine for parsing
    try
        switch state

            case 0 % Bin Number

                if ~startsWith(line, 'Bin ')

                    error('Expected "Bin" keyword.');

                end

                currentBin.binNumber = str2double(extractAfter(line, 'Bin '));

                if isnan(currentBin.binNumber)

                    error('Invalid bin number.');

                end

                state = 1;
                
            case 1 % Bin Description

                currentBin.description = line;

                state = 2;
                
            case 2 % Bin Conditions

                if ~startsWith(line, '.{') || ~endsWith(line, '}')

                    error('Invalid condition format. Conditions must be enclosed in {}.');

                end

                % Parse condition strings (remove surrounding {})

                conditionString = extractBetween(line, '{', '}');

                conditions = strsplit(conditionString, '}{');

                currentBin.conditions = conditions;
                
                % Store parsed bin and reset state
                binRules(end+1) = currentBin; %#ok<AGROW>

                currentBin = struct('binNumber', [], 'description', '', 'conditions', {});

                state = 0;

        end

    catch ME

        % Catch and log parsing errors

        isValid = false;

        errors{end+1} = sprintf('Error on line %d: %s', i, ME.message);

        state = 0; % Reset state machine on error

    end
end

% Validate completeness
if state ~= 0

    isValid = false;

    errors{end+1} = 'Incomplete BDF file: missing conditions for last bin.';

end

% Final validation of binRules
if isValid && isempty(binRules)

    isValid = false;

    errors{end+1} = 'No valid bins found in the BDF file.';

end

end


