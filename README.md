## AWS Environment Plugin

Buildkite Plugin for Setting AWS Defaults and Setting Git credentials on startup using Secrets Manager

This is still WIP Repo


## Usage

```yml
steps:
  # Run the included simple-command script that echos
    plugins:
      - harshadbhatia/aws-environment#v0.1.3:
          debug: true # Default False
          secret_name: mysecretname # Default "buildkite/{queue_name}/ssh-private-key"
```


## Usage

Your builds will check the following Secrets Manager names by default unless specified with `secret_name`:
### Default
* `buildkite/{queue_name}/ssh-private-key`

### With `secret_name`
* `{secret_name}`

Both of these secrets use the `SecretString` type and refer to git authentication.

## Uploading Secrets

### Setting SSH Keys for Git Checkouts

This example uploads an ssh key for a git+ssh checkout for a pipeline:

```bash
# generate a deploy key for your project
ssh-keygen -t rsa -b 4096 -f id_rsa_buildkite
pbcopy < id_rsa_buildkite.pub # paste this into your github deploy key

# create a managed secret with the private key
aws secretsmanager create-secret \
  --name "buildkite/{queue_name}/ssh-private-key" \
  --secret-string "$(cat file://id_rsa_buildkite)"
```

## License

MIT (see [LICENSE](LICENSE))


## TODO 

- Documentation
- Tests

## Developing

To run the tests:

```shell
make run-tests
```

## Contributing

1. Fork the repo
2. Make the changes
3. Run the tests
4. Commit and push your changes
5. Send a pull request