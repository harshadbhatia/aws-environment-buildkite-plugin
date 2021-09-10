#!/usr/bin/env bats



setup() {
    load "$BATS_PATH/load.bash"
    #export AWS_STUB_DEBUG=/dev/tty
    #export SSH_ADD_STUB_DEBUG=/dev/tty
    #export SSH_AGENT_STUB_DEBUG=/dev/tty
    #export GIT_STUB_DEBUG=/dev/tty

    # Secret Manager Default Stub values
    export TEST_RESOURCES_DIR="$PWD/tests/resources"
    export TMP_DIR=/tmp/run.bats/$$
    mkdir -p $TMP_DIR
    export BUILDKITE_QUEUE=my-queue
    export BUILDKITE_REPO=git@github.com:buildkite/test-repo.git
}

teardown() {
    unstub aws
    unstub ssh-agent
    unstub ssh-add
    rm -rf "$TMP_DIR"
}

main() {
    bash "$PWD/hooks/environment"
}


@test "Environment Variables are set correctly" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id buildkite/my-queue/ssh-private-key --query SecretString --output text : echo test-key"
    stub ssh-add "- : cat > $TMP_DIR/ssh-add-input ; echo added ssh key"
    stub ssh-agent "-s : echo export SSH_AGENT_PID=93799"

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


@test "Secret Manager Default Secret Key Prefix SSH Key Loaded correctly" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id buildkite/my-queue/ssh-private-key --query SecretString --output text : echo test-key"
    stub ssh-add "- : cat > $TMP_DIR/ssh-add-input ; echo added ssh key"
    stub ssh-agent "-s : echo export SSH_AGENT_PID=93799"


    # Run main method
    run main

    [ $status -eq 0 ]
    assert_success
    assert_output --partial "ssh-agent (pid 93799)"
    assert_output --partial "added ssh key"
    assert_equal "$(cat $TMP_DIR/ssh-add-input)" "test-key"
}


@test "Secret Manager Custom Secret Key Prefix SSH Key Loaded correctly" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id my-custom-prefix/ssh-private-key --query SecretString --output text : echo test-key"
    stub ssh-add "- : cat > $TMP_DIR/ssh-add-input ; echo added ssh key"
    stub ssh-agent "-s : echo export SSH_AGENT_PID=93799"


    # Override default secret key name
    export BUILDKITE_PLUGIN_AWS_ENVIRONMENT_SECRET_NAME=my-custom-prefix/ssh-private-key

    # Set to Debug Mode
    export BUILDKITE_PLUGIN_AWS_ENVIRONMENT_DEBUG=true

    # Run main method
    run main

    [ $status -eq 0 ]
    assert_success
    assert_line "Retrieving secret my-custom-prefix/ssh-private-key in region ap-southeast-2"
    assert_output --partial "ssh-agent (pid 93799)"
    assert_output --partial "added ssh key"
    assert_equal "$(cat $TMP_DIR/ssh-add-input)" "test-key"
}

@test "Secret Manager Test SSH Key Loaded correctly" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id buildkite/my-queue/ssh-private-key --query SecretString --output text : \
    cat $TEST_RESOURCES_DIR/test.key"
    # stub ssh-add "- : /usr/bin/ssh-add -"
    # stub ssh-agent \ "-s : /usr/bin/ssh-agent -s"


    # Run main method
    run main

    [ $status -eq 0 ]
    assert_success
    assert_output --partial "Loading ssh-key into ssh-agent (pid"
    assert_line 'Identity added: (stdin) (your_email@example.com)'
}

@test "No ssh key found in SM" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager get-secret-value --secret-id non-existent-secret --query SecretString --output text : \
    echo \"An error occurred (ResourceNotFoundException) when calling the GetSecretValue operation: \
    Secrets Manager can't find the specified secret.\"; exit 1"

    # Override default secret key name
    export BUILDKITE_PLUGIN_AWS_ENVIRONMENT_SECRET_NAME=non-existent-secret

    # Run main method
    run main
    assert_line "+++ :warning: Failed to get secret non-existent-secret"
    assert_failure
    [ $status -eq 1 ]
}

@test "Secret Manager GIT PAS not implemented yet" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'"

    export BUILDKITE_REPO=https://github.com/buildkite/test-repo.git

    # Run main method
    run main
    assert_line "Authentication through Git Personal Access Token not implemented yet."
    assert_failure
    [ $status -eq 1 ]
}