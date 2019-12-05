defmodule AuthedAws do
  @moduledoc """
  Makes requests with ExAws. When requests fail auth, updates the ExAws
  credentials using the provided credential_process command.
  """
  use GenServer
  @table_name :authed_aws_creds

  def start_link(credential_process_cmd) do
    GenServer.start_link(
      __MODULE__,
      %{credential_process_cmd: credential_process_cmd},
      name: __MODULE__
    )
  end

  def init(state) do
    :ets.new(@table_name, [:set, :named_table, :protected, read_concurrency: true])
    {:ok, state}
  end

  def request(request, opts \\ []) do
    do_request(request, opts, 0)
  end

  def handle_call(:refresh_credentials, _from, state) do
    case AuthedAws.Cmd.fetch_new_credentials(state.credential_process_cmd) do
      {:ok, credentials, expiration} ->
        :ets.insert(@table_name, {:credentials, credentials, expiration})
        {:reply, {:ok, credentials}, state}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  defp fetch_current_credentials() do
    case :ets.lookup(@table_name, :credentials) do
      [{:credentials, creds, expiration}] ->
        if DateTime.compare(expiration, DateTime.utc_now()) == :lt do
          {:ok, creds}
        else
          refresh_credentials()
        end

      [] ->
        refresh_credentials()
    end
  end

  defp do_request(request, opts, retries) do
    with {:creds, {:ok, creds}} <- {:creds, fetch_current_credentials()},
         {:request, {:ok, response}} <-
           {:request, ExAws.request(request, Keyword.merge(creds, opts))} do
      {:ok, response}
    else
      {:creds, error} ->
        error

      # missing required key
      {:request, {:error, "Required key: " <> _}} ->
        retry(request, opts, retries)

      # credentials expired or malformed
      {:request, {:error, {:http_error, code, _body}}} when code in [400, 403] ->
        retry(request, opts, retries)

      # any other request error
      {:request, error} ->
        error
    end
  end

  defp retry(_request, _opts, retries) when retries > 1 do
    {:error, :could_not_fetch_credentials}
  end

  defp retry(request, opts, retries) do
    do_request(request, opts, retries + 1)
  end

  defp refresh_credentials() do
    GenServer.call(__MODULE__, :refresh_credentials)
  end
end
