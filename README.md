## AWS Environment Plugin

Buildkite Plugin for Setting AWS Defaults and Setting Git credentials on startup using Secrets Manager

This is still WIP Repo


## Usage

```yml
steps:
  # Run the included simple-command script that echos
    plugins:
      - alfacode/aws-environment#v0.1.0: ~

```

## License

MIT (see [LICENSE](LICENSE))


## TODO 

- Finish SSM portion
- Documentation
- Tests

## Developing

To run the tests:

```shell
docker-compose run --rm tests
```

## Contributing

1. Fork the repo
2. Make the changes
3. Run the tests
4. Commit and push your changes
5. Send a pull request