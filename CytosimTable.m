function CytosimTable(userInput)
% CytosimTable - Processes Cytosim simulation output files into a structured table or struct array.
% Supports both automatic mode (recursive folder scan) and manual mode (explicit file list).
%
% ===================== USER INPUT STRUCTURE =====================
% Required:
%   userInput.automode           : (string) 'on' or 'off'
%       'on'  → Automatic mode (default)
%       'off' → Manual mode (requires cytosimFilePaths)
%
% Optional (AUTOMATIC MODE):
%   userInput.workDir            : (string) path to directory containing simulation subfolders
%                                   Default: current directory (pwd)
%   userInput.resultTypes        : (cell array of strings) e.g., {'solid_position', 'couple_state'}
%                                   Filters which .txt files to include based on filename prefix
%
% Optional (MANUAL MODE):
%   userInput.cytosimFilePaths   : (cell array of strings) full paths to .txt result files
%                                   Required when automode = 'off'
%
% Optional (BOTH MODES):
%   userInput.tableName          : (string) name of the variable to assign in base workspace
%                                   Default: 'CytosimTable'
% ===============================================================

    % === Handle missing input and set default values ===
    if ~exist('userInput', 'var') || ~isstruct(userInput)
        userInput = struct(); % Initialize empty input if none provided
    end

    % Set default mode to 'on' (automatic mode)
    if ~isfield(userInput, 'automode') || isempty(userInput.automode)
        userInput.automode = 'on';
    end

    % Default working directory is current directory if not specified
    if ~isfield(userInput, 'workDir') || isempty(userInput.workDir)
        userInput.workDir = pwd;
        fprintf('No workDir provided. Using current directory: %s\n', userInput.workDir);
    end

    % Default output variable name
    if ~isfield(userInput, 'tableName') || isempty(userInput.tableName)
        userInput.tableName = 'CytosimTable';
        fprintf('No tableName provided. Using default: %s\n', userInput.tableName);
    end

    % === MANUAL MODE LOGIC ===
    if strcmpi(userInput.automode, 'off')
        % Validate required manual input: list of cytosim result file paths
        if ~isfield(userInput, 'cytosimFilePaths') || isempty(userInput.cytosimFilePaths)
            warning('Manual mode requires userInput.cytosimFilePaths (cell array of file paths). Aborting.');
            return;
        end

        % Prepare configuration for processing files manually
        config.Name = userInput.tableName;
        config.steps = userInput.cytosimFilePaths;

        % Generate combined table from specified files
        masterTable = runIndividualTable(config);

        % Validate output before assigning
        if isempty(masterTable)
            warning('No data returned from runIndividualTable. Aborting.');
            return;
        end

        % Assign the generated table to the base workspace
        assignin('base', userInput.tableName, masterTable);
        fprintf('Manual mode complete. "%s" is now in the workspace.\n', userInput.tableName);
        return;
    end

    % === AUTOMATIC MODE LOGIC ===
    useFilter = false; % Default is to use all .txt files

    % If resultTypes is provided, configure filtering of result files
    if isfield(userInput, 'resultTypes') && iscell(userInput.resultTypes) && ~isempty(userInput.resultTypes)
        filterList = cellfun(@char, userInput.resultTypes, 'UniformOutput', false);
        useFilter = true;
        fprintf('Filtering .txt files using: %s\n', strjoin(filterList, ', '));
    else
        fprintf('No resultTypes provided. Using all .txt files.\n');
    end

    % Validate that the provided working directory exists
    if ~isfolder(userInput.workDir)
        error('The specified workDir "%s" does not exist.', userInput.workDir);
    end

    % List all subfolders in the working directory
    subfolders = dir(userInput.workDir);
    subfolders = subfolders([subfolders.isdir]);
    subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

    combinedStructArray = []; % Initialize empty output struct array
    totalFilesProcessed = 0;  % Count files to check for empty result at the end

    % === Loop through each subfolder and process matching files ===
    for i = 1:length(subfolders)
        subfolderPath = fullfile(userInput.workDir, subfolders(i).name);
        fprintf('Processing folder: %s\n', subfolderPath);

        % Get all .txt files in this subfolder
        txtFiles = dir(fullfile(subfolderPath, '*.txt'));

        % Apply resultTypes filtering if needed
        if useFilter
            txtFiles = txtFiles(arrayfun(@(f) any(startsWith(f.name, filterList)), txtFiles));
        end

        % If no valid files, skip to next folder
        if isempty(txtFiles)
            fprintf('No matching .txt files in "%s". Skipping.\n', subfolderPath);
            continue;
        end

        % Prepare file list for processing
        config.Name = 'tempMasterTable';
        config.steps = cell(length(txtFiles), 1);
        for j = 1:length(txtFiles)
            config.steps{j} = fullfile(subfolderPath, txtFiles(j).name);
        end

        % Update file counter
        totalFilesProcessed = totalFilesProcessed + length(txtFiles);

        % Run parser on the collected .txt files
        masterTable = runIndividualTable(config);

        % If the table returned is empty, skip adding
        if isempty(masterTable)
            fprintf('Failed to retrieve masterTable. Skipping.\n');
            continue;
        end

        % Convert table to struct for merging
        entry = struct();
        entry.Time = masterTable.Time;
        otherVars = setdiff(masterTable.Properties.VariableNames, {'Time'});
        for k = 1:numel(otherVars)
            entry.(otherVars{k}) = masterTable.(otherVars{k});
        end

        % Initialize or append to the combined struct array
        if isempty(combinedStructArray)
            combinedStructArray = repmat(entry, 1, 1);
        else
            combinedStructArray = syncStructFields(combinedStructArray, entry);
        end
    end

    % === Finalize and assign output ===
    if totalFilesProcessed == 0
        warning('No files found or processed. Aborting.');
        return;
    end

    % Push the combined struct array to the base workspace
    assignin('base', userInput.tableName, combinedStructArray);
    fprintf('Automatic mode complete. Struct array "%s" is now in the workspace.\n', userInput.tableName);
end

% === Supporting Function: Reads and structures output from file list ===
function masterTable = runIndividualTable(config)
    masterTable = table;
    fprintf('Creating master table "%s".\n', config.Name);

    for stepIdx = 1:size(config.steps, 1)
        dataFile = config.steps{stepIdx, 1};
        groupName = detectGroupName(dataFile); % Extract group name from header
        cytosimTable = doNotOpen(dataFile);    % Read and parse Cytosim file

        % Ensure time column is initialized only once
        if ~ismember('Time', masterTable.Properties.VariableNames)
            masterTable.Time = cytosimTable.Time;
        end

        groupSubtable = table;
        varNames = setdiff(cytosimTable.Properties.VariableNames, {'Time'});
        nFrames = height(cytosimTable);

        % Convert each variable's cell array to a numeric matrix
        for v = 1:length(varNames)
            var = varNames{v};
            allVals = cytosimTable.(var);
            maxLength = max(cellfun(@(x) size(x, 2), allVals));
            varMatrix = nan(nFrames, maxLength);
            for t = 1:nFrames
                val = allVals{t};
                if ~isempty(val)
                    val = val(:).';
                    varMatrix(t, 1:numel(val)) = val;
                end
            end
            groupSubtable.(var) = varMatrix;
        end

        masterTable.(groupName) = groupSubtable;
        fprintf('Group "%s" added.\n', groupName);
    end
end

% === Supporting Function: Extracts the report type from file header ===
function groupName = detectGroupName(dataFile)
    text = fileread(dataFile);
    match = regexp(text, '% report (\w+):', 'tokens', 'once');
    if ~isempty(match)
        groupName = match{1};
    else
        groupName = 'UnknownGroup';
    end
    if ~contains(text, 'identity')
        groupName = [groupName, 'Average'];
    end
end

% === Supporting Function: Ensures struct fields are synchronized ===
function structArray = syncStructFields(structArray, entry)
    existingFields = fieldnames(structArray);
    newFields = fieldnames(entry);

    % Add missing fields to entry
    for f = 1:numel(existingFields)
        if ~isfield(entry, existingFields{f})
            entry.(existingFields{f}) = [];
        end
    end

    % Add missing fields to struct array
    for f = 1:numel(newFields)
        if ~isfield(structArray, newFields{f})
            [structArray.(newFields{f})] = deal([]);
        end
    end

    % Append entry
    structArray(end+1) = entry;
end
