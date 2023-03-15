#!/bin/bash

set -e

usage() {
    cat<<EOF
Handles the version control of the target helm chart
Available Commands:
    helm versio increment [CHART]           Increment minor vergion of current chart
    helm versio validate [CHART] [REPO]     Validate current chart version agains lastest one deployed
    helm versio lookup [CHART] [REPO]       Check latest chart version deployed on the registry
    helm versio print [CHART]               Print current chart version
    --help                                  Display this text
EOF
}

# Create the passthru array
PASSTHRU=()
while [[ $# -gt 0 ]]; do
    key="$1"

    # Parse arguments
    case $key in
    --help)
        HELP=TRUE
        shift # past argument
        ;;
    *)                   # unknown option
        PASSTHRU+=("$1") # save it in an array for later
        shift            # past argument
        ;;
    esac
done

# Restore PASSTHRU parameters
set -- "${PASSTHRU[@]}"

# Show help if flagged
if [ "$HELP" == "TRUE" ]; then
    usage
    exit 0
fi

# COMMAND must be either 'fetch', 'list', or 'delete'
COMMAND=${PASSTHRU[0]}

if [ "$COMMAND" == "increment" ]; then
    CHART_PATH=${PASSTHRU[1]}
    if [ "$CHART_PATH" == "" ]; then
        echo "Chart path was not provided"
        exit 1
    fi
    CURRENT=$(grep '^version:' "$CHART_PATH/Chart.yaml" | cut -d':' -f 2 | tr -d '"' | tr -d ' ')
    INCREMENTED=$(echo "$CURRENT" | awk -F. -v OFS=. '{$NF += 1 ; print}')
    gsed -i "s\version: $CURRENT\version: $INCREMENTED\g" "$CHART_PATH/Chart.yaml"
    CHART_NAME=$(grep '^name:' "$CHART_PATH/Chart.yaml" | cut -d':' -f 2 | tr -d '"' | tr -d ' ')
    echo "Chart '$CHART_NAME' update from version '$CURRENT' to version '$INCREMENTED'"
    exit 0
elif [ "$COMMAND" == "validate" ]; then
    CHART_PATH=${PASSTHRU[1]}
    if [ "$CHART_PATH" == "" ]; then
        echo "Chart path was not provided"
        exit 1
    fi
    CHART_REPO=${PASSTHRU[2]}
    CURRENT=$(grep '^version:' "$CHART_PATH/Chart.yaml" | cut -d':' -f 2 | tr -d '"' | tr -d ' ')
    CHART_NAME=$(grep '^name:' "$CHART_PATH/Chart.yaml" | cut -d':' -f 2 | tr -d '"' | tr -d ' ')
    PUBLISHED=$(helm search repo "$CHART_REPO"/"$CHART_NAME" -o json | cut -d '"' -f 8)

    if [ "$CHART_REPO" == "" ]; then
        echo "Chart repo not provided, will search for '$CHART_NAME' on all repos"
        FOUND=$(helm search repo "$CHART_NAME" -o json | cut -d '/' -f 1 | cut -d '"' -f4)
        if [ "$PUBLISHED" == "[]" ]; then
            echo "Chart '$CHART_NAME' was not found on any repo"
            exit 0
        else
            if [ "$CURRENT" == "$PUBLISHED" ]; then
                echo "Chart '$CHART_NAME' was found in '$FOUND' repo"
                if [ "$IGNORE" == true ]; then
                    echo "Chart '$CHART_NAME' version '$CURRENT' hasn't been updated, ignoring..."
                    exit 0
                fi
                echo "Chart '$CHART_NAME' version '$CURRENT' hasn't been updated"
            else
                echo "Chart '$CHART_NAME' was found in '$FOUND' repo"
                echo "Chart '$CHART_NAME' version '$CURRENT' has been updated"
                exit 0
            fi
        fi
    else
        if [ "$PUBLISHED" == "[]" ]; then
            echo "Chart '$CHART_NAME' was not found in '$CHART_REPO' repo"
            exit 0
        else
            if [ "$CURRENT" == "$PUBLISHED" ]; then
                if [ "$IGNORE" == true ]; then
                    echo "Chart '$CHART_NAME' version '$CURRENT' hasn't been updated, ignoring..."
                    exit 0
                fi
                echo "Chart '$CHART_NAME' version '$CURRENT' hasn't been updated"
                echo "Chart '$CHART_NAME' version '$CURRENT' hasn't been updated"
            else
                echo "Chart '$CHART_NAME' version '$CURRENT' has been updated"
                exit 0
            fi
        fi
    fi
    exit 2
elif [ "$COMMAND" == "lookup" ]; then
    CHART_PATH=${PASSTHRU[1]}
    if [ "$CHART_PATH" == "" ]; then
        echo "Chart path was not provided"
        exit 1
    fi
    CHART_REPO=${PASSTHRU[2]}
    CHART_NAME=$(grep '^name:' "$CHART_PATH/Chart.yaml" | cut -d':' -f 2 | tr -d '"' | tr -d ' ')
    PUBLISHED=$(helm search repo "$CHART_REPO"/"$CHART_NAME" -o json | cut -d '"' -f 8)
    if [ "$CHART_REPO" == "" ]; then
        echo "Chart repo not provided, will search for '$CHART_NAME' on all repos"
        FOUND=$(helm search repo "$CHART_NAME" -o json | cut -d '/' -f 1 | cut -d '"' -f4)
        if [ "$PUBLISHED" == "[]" ]; then
            echo "Chart '$CHART_NAME' was not found any repo"
        else
            echo "Chart '$CHART_NAME' was found in '$FOUND' repo"
            echo "Chart '$CHART_NAME' lastest publish version in '$FOUND' is '$PUBLISHED'"
        fi
    else
        if [ "$PUBLISHED" == "[]" ]; then
            echo "Chart '$CHART_NAME' was not found on '$CHART_REPO' repo"
        else
            echo "Chart '$CHART_NAME' lastest publish version in '$CHART_REPO' is '$PUBLISHED'"
        fi
    fi
    exit 0
elif [ "$COMMAND" == "print" ]; then
    CHART_PATH=${PASSTHRU[1]}
    if [ "$CHART_PATH" == "" ]; then
        echo "Chart path was not provided"
        exit 1
    fi
    CURRENT=$(grep '^version:' "$CHART_PATH/Chart.yaml" | cut -d':' -f 2 | tr -d '"' | tr -d ' ')
    CHART_NAME=$(grep '^name:' "$CHART_PATH/Chart.yaml" | cut -d':' -f 2 | tr -d '"' | tr -d ' ')
    echo "Chart '$CHART_NAME' current version is '$CURRENT'"
    exit 0
else
    echo "Error: Invalid command."
    usage
    exit 1
fi
