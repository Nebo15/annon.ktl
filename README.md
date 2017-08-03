# annonktl

annonktl controls the Annon API Gateway cluster.

```
$ annonktl help

Discovery commands:

  status         Status of Annon API Gateway cluster.
  routes         Prints all routes.

Cluster configuration commands:

  taint          Update API health status.
  apply          Create or update one of resources.
  get            Display one or many resources (supports: requests, request, api).
  delete         Delete resources (supports: request, api).

Informational commands:

  help           Help about any command.
  version        Prints annonktl and gateway versions.
  config         Manage annonktl configuration.

List of global options:

  --management-endpoint=http://example.com/ - URL to Annon API Gateway management endpoint.
  --context=my_context - The name of annonktl context to use.
  -h, --help - Display help for annonktl command.

Environment variables:

  ANNONKTL_MANAGEMENT_ENDPOINT='' - URL to Annon API Gateway management endpoint.
  ANNONKTL_CONTEXT='' - The name of annonktl context to use.
  ANNONKTL_CONFIG='~/.config/annonktl/context.json' - Path to the file that stores annonktl configs.

  Global options have higher priority than environment variables.
```

## Installation

  1. Install Elixir
     
     ```
     brew install elixir
     ```

  2. This CLI tools is distributed in an escript format on Hex.pm:

      ```
      mix escript.install hex annon_ktl
      ```

  3. Add `~/.mix/escripts` to `PATH`

      ```
      echo 'PATH="~/.mix/escripts:$PATH"' >> ~/.bash_profile
      ```
     
  For convenience, consider adding `~/.mix/escripts` directory to your PATH
  environment variable. For more information, check the wikipedia article on
  PATH: [https://en.wikipedia.org/wiki/PATH_(variable)](https://en.wikipedia.org/wiki/PATH_(variable)).

  4. Add your first environment
  ```
  annonktl config context apply my_context http://example.com:8080/
  ```

## License

See [LICENSE.md](LICENSE.md).
