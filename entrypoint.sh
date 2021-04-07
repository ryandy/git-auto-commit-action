#!/bin/bash

set -eu

# Prevent wildcard expansion from occurring in the shell. This is particularly
# important when dealing with INPUT_FILE_PATTERN, which may include wildcard
# characters. We don't want the shell to glob expand the patterns before they're
# passed to git status/add, so turn on "noglob" for this script.
set -o noglob

_main() {
    _switch_to_repository

    if _git_is_dirty || "$INPUT_SKIP_DIRTY_CHECK"; then

        echo "::set-output name=changes_detected::true";

        _switch_to_branch

        _add_files

        _local_commit

        _tag_commit

        _push_to_github
    else

        echo "::set-output name=changes_detected::false";

        echo "Working tree clean. Nothing to commit.";
    fi
}


_switch_to_repository() {
    echo "INPUT_REPOSITORY value: $INPUT_REPOSITORY";
    cd "$INPUT_REPOSITORY";
}

_git_is_dirty() {
    # shellcheck disable=SC2086
    [ -n "$(git status -s -- $INPUT_FILE_PATTERN)" ]
}

_switch_to_branch() {
    echo "INPUT_BRANCH value: $INPUT_BRANCH";

    # Fetch remote to make sure that repo can be switched to the right branch.

    if "$INPUT_SKIP_FETCH"; then
        echo "::debug::git-fetch has not been executed";
    else
        git fetch --depth=1;
    fi

    # Switch to branch from current Workflow run
    # shellcheck disable=SC2086
    git checkout $INPUT_BRANCH;
}

_add_files() {
    echo "INPUT_FILE_PATTERN: ${INPUT_FILE_PATTERN}";

    # shellcheck disable=SC2086
    git add ${INPUT_FILE_PATTERN};
}

_local_commit() {
    echo "INPUT_COMMIT_OPTIONS: ${INPUT_COMMIT_OPTIONS}";
    echo "::debug::Apply commit options ${INPUT_COMMIT_OPTIONS}";

    # shellcheck disable=SC2206
    INPUT_COMMIT_OPTIONS_ARRAY=( $INPUT_COMMIT_OPTIONS );

    echo "INPUT_COMMIT_USER_NAME: ${INPUT_COMMIT_USER_NAME}";
    echo "INPUT_COMMIT_USER_EMAIL: ${INPUT_COMMIT_USER_EMAIL}";
    echo "INPUT_COMMIT_MESSAGE: ${INPUT_COMMIT_MESSAGE}";
    echo "INPUT_COMMIT_AUTHOR: ${INPUT_COMMIT_AUTHOR}";

    git -c user.name="$INPUT_COMMIT_USER_NAME" -c user.email="$INPUT_COMMIT_USER_EMAIL" \
        commit -m "$INPUT_COMMIT_MESSAGE" \
        --author="$INPUT_COMMIT_AUTHOR" \
        ${INPUT_COMMIT_OPTIONS:+"${INPUT_COMMIT_OPTIONS_ARRAY[@]}"};
}

_tag_commit() {
    echo "INPUT_TAGGING_MESSAGE: ${INPUT_TAGGING_MESSAGE}"

    if [ -n "$INPUT_TAGGING_MESSAGE" ]
    then
        echo "::debug::Create tag $INPUT_TAGGING_MESSAGE";
        git -c user.name="$INPUT_COMMIT_USER_NAME" -c user.email="$INPUT_COMMIT_USER_EMAIL" tag -a "$INPUT_TAGGING_MESSAGE" -m "$INPUT_TAGGING_MESSAGE";
    else
        echo "No tagging message supplied. No tag will be added.";
    fi
}

_push_to_github() {

    echo "INPUT_PUSH_OPTIONS: ${INPUT_PUSH_OPTIONS}";
    echo "::debug::Apply push options ${INPUT_PUSH_OPTIONS}";

    # shellcheck disable=SC2206
    INPUT_PUSH_OPTIONS_ARRAY=( $INPUT_PUSH_OPTIONS );

    if [ -z "$INPUT_BRANCH" ]
    then
        # Only add `--tags` option, if `$INPUT_TAGGING_MESSAGE` is set
        if [ -n "$INPUT_TAGGING_MESSAGE" ]
        then
            echo "::debug::git push origin --tags";
            git push origin --follow-tags --atomic ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
        else
            echo "::debug::git push origin";
            git push origin ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
        fi

    else
        echo "::debug::Push commit to remote branch $INPUT_BRANCH";
        git push --set-upstream origin "HEAD:$INPUT_BRANCH" --follow-tags --atomic ${INPUT_PUSH_OPTIONS:+"${INPUT_PUSH_OPTIONS_ARRAY[@]}"};
    fi
}

_main
