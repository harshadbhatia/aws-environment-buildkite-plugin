#!/usr/bin/env bats



setup() {

    load "$BATS_PATH/load.bash"
    #export AWS_STUB_DEBUG=/dev/tty
    #export SSH_ADD_STUB_DEBUG=/dev/tty
    #export SSH_AGENT_STUB_DEBUG=/dev/tty
    #export GIT_STUB_DEBUG=/dev/tty

    # Secret Manager Default Stub values
    export TMP_DIR=/tmp/run.bats/$$
    mkdir -p $TMP_DIR
    export BUILDKITE_QUEUE=my-queue
    export BUILDKITE_REPO=git@github.com:buildkite/test-repo.git
    stub ssh-agent "-s : echo export SSH_AGENT_PID=93799"
    stub ssh-add "- : cat > $TMP_DIR/ssh-add-input ; echo added ssh key"
    cat << EOF > $TMP_DIR/ssh-secrets-default
{
    "SecretList": [
        {
            "ARN": "arn:aws:secretsmanager:ap-southeast-2:xxxxx:secret:buildkite/my-queue/my-pipeline/ssh-private-key-xxxx",
            "Name": "buildkite/my-queue/ssh-private-key"
        }
    ]
}
EOF
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
    "secretsmanager list-secrets : cat $TMP_DIR/ssh-secrets-default" \
    "secretsmanager get-secret-value --secret-id buildkite/my-queue/ssh-private-key --query SecretString --output text : echo test-repo"

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
    "secretsmanager list-secrets : cat $TMP_DIR/ssh-secrets-default" \
    "secretsmanager get-secret-value --secret-id buildkite/my-queue/ssh-private-key --query SecretString --output text : echo test-key"

    # Run main method
    run main

    [ $status -eq 0 ]
    assert_success
    assert_line "Found ssh-key at buildkite/my-queue/ssh-private-key"
    assert_output --partial "ssh-agent (pid 93799)"
    assert_output --partial "added ssh key"
    assert_equal "$(head $TMP_DIR/ssh-add-input)" "test-key"
}


@test "Secret Manager Custom Secret Key Prefix SSH Key Loaded correctly" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager list-secrets : cat $TMP_DIR/ssh-secrets-custom" \
    "secretsmanager get-secret-value --secret-id my-custom-prefix/ssh-private-key --query SecretString --output text : echo test-key"

    # Override default secret key prefix
    export BUILDKITE_PLUGIN_AWS_ENVIRONMENT_SECRETS_PREFIX=my-custom-prefix/
    cat << EOF > $TMP_DIR/ssh-secrets-custom
{
    "SecretList": [
        {
            "ARN": "arn:aws:secretsmanager:ap-southeast-2:xxxxx:secret:buildkite/my-queue/my-pipeline/ssh-private-key-xxxx",
            "Name": "my-custom-prefix/ssh-private-key"
        }
    ]
}
EOF

    # Run main method
    run main

    [ $status -eq 0 ]
    assert_success
    assert_line "Found ssh-key at my-custom-prefix/ssh-private-key"
    assert_output --partial "ssh-agent (pid 93799)"
    assert_output --partial "added ssh key"
    assert_equal "$(cat $TMP_DIR/ssh-add-input)" "test-key"
}

@test "Secret Manager No Secrets in SM" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager list-secrets : echo None" \

    # Run main method
    run main

    assert_line "No secrets found"
    [ $status -eq 0 ]
}

@test "Secret Manager No relevant secret keys found in SM" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager list-secrets : cat $TMP_DIR/ssh-secrets-no-relevant-secret" \

    cat << EOF > $TMP_DIR/ssh-secrets-no-relevant-secret
{
    "SecretList": [
        {
            "ARN": "arn:aws:secretsmanager:ap-southeast-2:xxxxx:secret:buildkite/my-queue/my-pipeline/ssh-private-key-xxxx",
            "Name": "randomsecret"
        }
    ]
}
EOF

    # Run main method
    run main
    assert_output --partial "Failed to find any ssh key secrets"
    assert_failure
    [ $status -eq 1 ]
}

@test "Secret Manager GIT PAS not implemented yet" {
    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'" \
    "secretsmanager list-secrets : cat $TMP_DIR/ssh-secrets-default"

    export BUILDKITE_REPO=https://github.com/buildkite/test-repo.git

    # Run main method
    run main
    assert_line "Authentication through Git Personal Access Token not implemented yet."
    assert_failure
    [ $status -eq 1 ]
}