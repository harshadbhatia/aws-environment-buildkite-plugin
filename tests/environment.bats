#!/usr/bin/env bats

default_stubs() {
    # Default stub values
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id buildkite/my-queue/ssh-private-key --query SecretString --output text : echo test-key"
    stub ssh-add "- : cat > $TMP_DIR/ssh-add-input ; echo added ssh key"
    stub ssh-agent "-s : echo export SSH_AGENT_PID=93799"
}

setup() {
    sm_set_up() {
        # Secret Manager Default Env var params
        export BUILDKITE_QUEUE=my-queue
        export BUILDKITE_REPO=git@github.com:buildkite/test-repo.git

        # Test Resources & Directories
        export TEST_RESOURCES_DIR="$PWD/tests/resources"
        export TMP_DIR=/tmp/run.bats/$$
        mkdir -p $TMP_DIR
    }

    load "$BATS_PATH/load.bash"

    #export AWS_STUB_DEBUG=/dev/tty
    #export SSH_ADD_STUB_DEBUG=/dev/tty
    #export SSH_AGENT_STUB_DEBUG=/dev/tty
    #export GIT_STUB_DEBUG=/dev/tty

    sm_set_up
}

teardown() {
    unstub aws
    unstub ssh-agent
    unstub ssh-add
    rm -rf "$TMP_DIR"
}

main() {
    . "$PWD/hooks/environment"

    # Pre-exit hook is used to kill the SSH agent if running, BATs test will not terminate if the SSH agent is running.
    . "$PWD/hooks/pre-exit"
}


@test "Environment Variables are set correctly" {
    default_stubs

    # Run main method
    run main
    # Global vars are populated output and lines
    [ $status -eq 0 ]

    # Match Correct echo
    assert_line "Exported AWS_ACCOUNT_ID:123456789"
    assert_line "AWS_DEFAULT_REGION:ap-southeast-2"
    assert_line "CDK_DEFAULT_ACCOUNT:123456789"
    assert_line "CDK_DEFAULT_REGION:ap-southeast-2"
    assert_success
}


@test "Error if AWS_ACCOUNT_ID is empty" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo ''"
    # Run main method
    run main
    # Global vars are populated output and lines

    [ $status -eq 0 ]
    [ "$output" == "Error in setting AWS_ACCOUNT_ID" ]

    assert_success
}


@test "Default Secret Name from SM loaded correctly" {
    default_stubs

    # Run main method
    run main

    [ $status -eq 0 ]
    assert_success
    assert_output --partial "ssh-agent (pid 93799)"
    assert_output --partial "added ssh key"
    assert_equal "$(cat $TMP_DIR/ssh-add-input)" "test-key"
}


@test "Custom Secret Name from SM loaded correctly" {
    custom_secret_name=my-custom-prefix/ssh-private-key
    default_stubs

    # Override AWS default stub
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id ${custom_secret_name} --query SecretString --output text : echo test-key"

    # Override default secret key name
    export BUILDKITE_PLUGIN_AWS_ENVIRONMENT_SECRET_NAME=$custom_secret_name

    # Set to Debug Mode
    export BUILDKITE_PLUGIN_AWS_ENVIRONMENT_DEBUG=true

    # Run main method
    run main

    [ $status -eq 0 ]
    assert_success
    assert_line "Retrieving secret ${custom_secret_name} in region ap-southeast-2"
    assert_output --partial "ssh-agent (pid 93799)"
    assert_output --partial "added ssh key"
    assert_equal "$(cat $TMP_DIR/ssh-add-input)" "test-key"
}


@test "Sample SSH Key Loaded correctly" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id buildkite/my-queue/ssh-private-key --query SecretString --output text : \
    cat $TEST_RESOURCES_DIR/sample.key"

    # Run main method
    run main

    [ $status -eq 0 ]
    assert_success
    assert_output --partial "Loading ssh-key into ssh-agent (pid "
    assert_line "Identity added: (stdin) (your_email@example.com)"
    assert_output --partial "~~~ Stopping ssh-agent "
}

@test "Cant Find Specified Secret Name in SM" {
    custom_secret_name=non-existent-secret
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id ${custom_secret_name} --query SecretString --output text : \
    echo \"An error occurred (ResourceNotFoundException) when calling the GetSecretValue operation: \
    Secrets Manager can't find the specified secret.\"; exit 1"

    # Override default secret key name
    export BUILDKITE_PLUGIN_AWS_ENVIRONMENT_SECRET_NAME=$custom_secret_name

    # Run main method
    run main
    assert_line "+++ :warning: Failed to get secret ${custom_secret_name}"
    assert_failure
    [ $status -eq 1 ]
}

@test "Git PAS Authentication not implemented yet" {
    default_stubs

    # Override Repo
    export BUILDKITE_REPO=https://github.com/buildkite/test-repo.git

    # Run main method
    run main
    assert_line "Authentication through Git Personal Access Token not implemented yet."
    assert_failure
    [ $status -eq 1 ]
}