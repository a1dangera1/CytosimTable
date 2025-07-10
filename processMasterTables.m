function processMasterTables(userInput)
    % processMasterTables - Processes Cytosim output folders into a struct array.
    %
    % INPUT: userInput (struct) with optional fields:
    %   - workDir      : root directory with subfolders (default: current directory)
    %   - tableName    : output variable name in base workspace (default: 'CytosimTable')
    %   - resultTypes  : cell array of filename prefixes to filter .txt files (default: all .txt files)
    
    % === Handle Defaults ===
    if ~exist('userInput', 'var') || ~isstruct(userInput)
        userInput = struct();
    end
    if ~isfield(userInput, 'workDir') || isempty(userInput.workDir)
        userInput.workDir = pwd;
        fprintf('No workDir provided. Using current directory: %s\n', userInput.workDir);
    end
    if ~isfield(userInput, 'tableName') || isempty(userInput.tableName)
        userInput.tableName = 'CytosimTable';
        fprintf('No tableName provided. Using default: %s\n', userInput.tableName);
    end
    useFilter = false;
    if isfield(userInput, 'resultTypes') && iscell(userInput.resultTypes) && ~isempty(userInput.resultTypes)
        filterList = cellfun(@char, userInput.resultTypes, 'UniformOutput', false);
        useFilter = true;
        fprintf('Filtering .txt files using: %s\n', strjoin(filterList, ', '));
    else
        fprintf('No resultTypes provided. Using all .txt files.\n');
    end

    % === Validate folder ===
    if ~isfolder(userInput.workDir)
        error('The specified workDir "%s" does not exist.', userInput.workDir);
    end

    % === Process subfolders ===
    subfolders = dir(userInput.workDir);
    subfolders = subfolders([subfolders.isdir]);
    subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

    combinedStructArray = [];
    for i = 1:length(subfolders)
        subfolderPath = fullfile(userInput.workDir, subfolders(i).name);
        fprintf('Processing folder: %s\n', subfolderPath);

        txtFiles = dir(fullfile(subfolderPath, '*.txt'));

        if useFilter
            txtFiles = txtFiles(arrayfun(@(f) any(startsWith(f.name, filterList)), txtFiles));
        end

        if isempty(txtFiles)
            fprintf('No matching .txt files in "%s". Skipping.\n', subfolderPath);
            continue;
        end

        % === Build config for masterTableFinal ===
        config.Name = 'tempMasterTable';
        config.steps = cell(length(txtFiles), 1);
        for j = 1:length(txtFiles)
            config.steps{j} = fullfile(subfolderPath, txtFiles(j).name);
        end

        % === Run and retrieve table ===
        masterTableFinal(config);
        if evalin('base', "exist('tempMasterTable', 'var')")
            masterTable = evalin('base', 'tempMasterTable');
            evalin('base', 'clear tempMasterTable');
        else
            fprintf('Failed to retrieve tempMasterTable. Skipping.\n');
            continue;
        end

        % === Build struct entry ===
        entry = struct();
        entry.Time = masterTable.Time;

        otherVars = setdiff(masterTable.Properties.VariableNames, {'Time'});
        for k = 1:numel(otherVars)
            entry.(otherVars{k}) = masterTable.(otherVars{k});
        end

        % === Append to array ===
        if isempty(combinedStructArray)
            combinedStructArray = repmat(entry, 1, 1);
        else
            combinedStructArray = syncStructFields(combinedStructArray, entry);
        end
    end

    % === Output to base workspace ===
    assignin('base', userInput.tableName, combinedStructArray);
    fprintf('Struct array "%s" is now in the base workspace.\n', userInput.tableName);
end

function structArray = syncStructFields(structArray, entry)
    % Ensures all structs have the same fields
    existingFields = fieldnames(structArray);
    newFields = fieldnames(entry);

    for f = 1:numel(existingFields)
        if ~isfield(entry, existingFields{f})
            entry.(existingFields{f}) = [];
        end
    end
    for f = 1:numel(newFields)
        if ~isfield(structArray, newFields{f})
            [structArray.(newFields{f})] = deal([]);
        end
    end
    structArray(end+1) = entry;
end
