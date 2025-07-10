function CytosimTable(userInput)
    % Handle defaults
    if ~exist('userInput', 'var') || ~isstruct(userInput)
        userInput = struct();
    end
    if ~isfield(userInput, 'manual') || isempty(userInput.manual)
        userInput.manual = 0;
    end
    if ~isfield(userInput, 'workDir') || isempty(userInput.workDir)
        userInput.workDir = pwd;
        fprintf('No workDir provided. Using current directory: %s\n', userInput.workDir);
    end
    if ~isfield(userInput, 'tableName') || isempty(userInput.tableName)
        userInput.tableName = 'CytosimTable';
        fprintf('No tableName provided. Using default: %s\n', userInput.tableName);
    end

    if userInput.manual == 1
        % === MANUAL MODE ===
        if ~isfield(userInput, 'multWorkDir') || isempty(userInput.multWorkDir)
            error('manual mode requires userInput.multWorkDir (cell array of file paths).');
        end

        config.Name = userInput.tableName;
        config.steps = userInput.multWorkDir;

        % Use existing logic from individualTableInput
        masterTable = runIndividualTable(config);

        assignin('base', userInput.tableName, masterTable);
        fprintf('Manual mode complete. "%s" is now in the workspace.\n', userInput.tableName);
        return;
    end

    % === AUTOMATIC MODE ===
    useFilter = false;
    if isfield(userInput, 'resultTypes') && iscell(userInput.resultTypes) && ~isempty(userInput.resultTypes)
        filterList = cellfun(@char, userInput.resultTypes, 'UniformOutput', false);
        useFilter = true;
        fprintf('Filtering .txt files using: %s\n', strjoin(filterList, ', '));
    else
        fprintf('No resultTypes provided. Using all .txt files.\n');
    end

    if ~isfolder(userInput.workDir)
        error('The specified workDir "%s" does not exist.', userInput.workDir);
    end

    % Process subfolders
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

        config.Name = 'tempMasterTable';
        config.steps = cell(length(txtFiles), 1);
        for j = 1:length(txtFiles)
            config.steps{j} = fullfile(subfolderPath, txtFiles(j).name);
        end

        masterTable = runIndividualTable(config);
        if isempty(masterTable)
            fprintf('Failed to retrieve masterTable. Skipping.\n');
            continue;
        end

        entry = struct();
        entry.Time = masterTable.Time;
        otherVars = setdiff(masterTable.Properties.VariableNames, {'Time'});
        for k = 1:numel(otherVars)
            entry.(otherVars{k}) = masterTable.(otherVars{k});
        end

        if isempty(combinedStructArray)
            combinedStructArray = repmat(entry, 1, 1);
        else
            combinedStructArray = syncStructFields(combinedStructArray, entry);
        end
    end

    assignin('base', userInput.tableName, combinedStructArray);
    fprintf('Automatic mode complete. Struct array "%s" is now in the workspace.\n', userInput.tableName);
end

% === Supporting functions below ===

function masterTable = runIndividualTable(config)
    masterTable = table;
    fprintf('Creating master table "%s".\n', config.Name);

    for stepIdx = 1:size(config.steps, 1)
        dataFile = config.steps{stepIdx, 1};
        groupName = detectGroupName(dataFile);
        cytosimTable = doNotOpen(dataFile);

        if ~ismember('Time', masterTable.Properties.VariableNames)
            masterTable.Time = cytosimTable.Time;
        end

        groupSubtable = table;
        varNames = setdiff(cytosimTable.Properties.VariableNames, {'Time'});
        nFrames = height(cytosimTable);

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

function structArray = syncStructFields(structArray, entry)
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
