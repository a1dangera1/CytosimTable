#!/bin/bash

# === USER-DEFINED SECTION ===

# Array of report arguments (add as many as needed)
report_args=("solid:position" "couple:state")

# === END USER SECTION ===

# Create master folder
mkdir -p master_folder

# Define simulation command
simulation_command="./sim"
report_command="./report"

# Iterate over each configuration file
for config_file in ./config*.cym
do
    # Check if any config files are found
    if [ ! -f "$config_file" ]; then
        echo "No configuration files found in the current directory."
        exit 1
    fi

    firstPart=$(echo "$config_file" | cut -d '.' -f 2)
    fileIndex=$(echo $firstPart | cut -d 'g' -f 2)

    # Create folder for this result set
    mkdir -p master_folder/"result$fileIndex"

    # Run simulation
    echo "Running simulation with configuration file $config_file"
    $simulation_command "$config_file"

    # Run all report commands in the array
    for arg in "${report_args[@]}"
    do
        output_file="${arg//:/_}$fileIndex.txt"
        echo "Running report with argument: $arg → Output: $output_file"
        $report_command "$arg" > "$output_file"
        mv "$output_file" master_folder/"result$fileIndex"/
    done

done

echo "All simulations are complete."
