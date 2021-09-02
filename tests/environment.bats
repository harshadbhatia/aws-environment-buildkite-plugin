#!/usr/bin/env bats



setup() {

    load "$BATS_PATH/load.bash"

    #export AWS_STUB_DEBUG=/dev/tty
    #export SSH_ADD_STUB_DEBUG=/dev/tty
    #export SSH_AGENT_STUB_DEBUG=/dev/tty
    #export GIT_STUB_DEBUG=/dev/tty

}

teardown() {
    unstub aws
}

main() {
    bash "$PWD/hooks/environment"
}


@test "Environment Variables are set correctly" {

    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'"
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