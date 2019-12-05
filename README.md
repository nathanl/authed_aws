# AuthedAws

Uses `:ex_aws` to make requests to AWS, authenticated according to the [`credential_process`](https://docs.aws.amazon.com/cli/latest/topic/config-vars.html#sourcing-credentials-from-external-processes) command you supply.

Once it's set up, you can simply use `AuthedAws.request/1` in place of `ExAws.request/1`.

For example:

```elixir
ExAws.S3.list_objects("my-bucket")
|> AuthedAws.request(region: "us-west-1")
```

## Installation

Point your `mix.exs` repo usage to this git repo.

```elixir
def deps do
  [
    {:authed_aws, "~> 0.1.0", git: "this-repo-url"}
  ]
end
```

## Configuration

`authed_aws` needs the following configuration.

### `credential_process` command

`:authed_aws` needs to know the `credential_process` command to run to fetch your AWS credentials.
You must provide the full command string as an argument to `AuthedAws.start_link/1` when you add it to your supervision tree.

For example:

```elixir
{AuthedAws, credential_process_cmd()}
```

You can get that command from an environment variable or wherever else you like.
One option is to specify it in your `~/.aws/config`, like this:

    [profile dev]
    credential_process = my_command -u some_user -a some_account -r some_role
    region = us-west-3

Then you can use `ExAws` to fetch the value from there:

```elixir
defp credential_process_cmd() do
  ExAws.CredentialsIni.security_credentials("dev")
  |> Map.fetch!(:credential_process)
end
```

### JSON library

`:authed_aws` also needs to parse the JSON string your `credential_process` command returns, and for that, it needs a JSON library, which you must configure. For example:

```elixir
config :authed_aws, :json_codec, Jason
```

Note that your command must return JSON which matches [Amazon's specification](https://docs.aws.amazon.com/cli/latest/topic/config-vars.html#sourcing-credentials-from-external-processes).
