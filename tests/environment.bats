#!/usr/bin/env bats



setup() {

    load "$BATS_PATH/load.bash"

    #export AWS_STUB_DEBUG=/dev/tty
    #export SSH_ADD_STUB_DEBUG=/dev/tty
    #export SSH_AGENT_STUB_DEBUG=/dev/tty
    #export GIT_STUB_DEBUG=/dev/tty

    stub aws \
    "sts get-caller-identity --query Account --output text : echo '123456789'"
}

teardown() {
    unstub aws
}

main() {
    bash "$PWD/hooks/environment"
}

@test "Environment Variables are set correctly" {
    # Run main method
    run main

    # Global vars are populated output and lines
    echo "Output is $output $status"
    
    [ $status -eq 0 ]
    [ "$output" == "Exported AWS_ACCOUNT_ID:123456789\nAWS_DEFAULT_REGION:ap-southeast-2" ]

    assert_success
}