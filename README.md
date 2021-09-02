## AWS Environment Plugin

Buildkite Plugin for Setting AWS Defaults and Setting Git credentials on startup using Secrets Manager



## Usage

```yml
steps:
  # Run the included simple-command script that echos
    plugins:
      - aws-environment#v1.0.0: ~

```

## License

MIT (see [LICENSE](LICENSE))


## TODO 

- Finish SSM portion
- Documentation
- Tests