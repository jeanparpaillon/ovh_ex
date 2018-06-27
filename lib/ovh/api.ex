defmodule Ovh.Api do
  @moduledoc """
  https://api.ovh.com/console/
  """
  require Logger
  
  @endpoints %{
    'ovh-eu': 'https://eu.api.ovh.com/1.0',
    'ovh-us': 'https://api.ovhcloud.com/1.0',
    'ovh-ca': 'https://ca.api.ovh.com/1.0',
    'kimsufi-eu': 'https://eu.api.kimsufi.com/1.0',
    'kimsufi-ca': 'https://ca.api.kimsufi.com/1.0',
    'soyoustart-eu': 'https://eu.api.soyoustart.com/1.0',
    'soyoustart-ca': 'https://ca.api.soyoustart.com/1.0',
  }
  
  defmacro __using__(_opts) do
    quote do
      import Ovh.Api
    end
  end

  def get(path, http_opts \\ [], opts \\ []) do
    query = Path.join baseurl(), path
    headers = ovh_headers("GET", query)
    req = {'#{query}', headers}
    case :httpc.request(:get, req, http_opts, opts) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, Poison.decode!(body)}
      {:ok, {{_, code, reason}, _, _}} ->
        {:error, {code, reason}}
      {:error, err} ->
        {:error, err}
    end
  end

  ###
  ### Priv
  ###
  defp ovh_headers(method, query, body \\ "") do
    ak = Confex.get_env(:ovh, :app_key)
    as = Confex.get_env(:ovh, :app_secret)
    ck = Confex.get_env(:ovh, :consumer_key)
    ts = :os.system_time(:seconds) + delta_time()
    sig = "$1$" <> hash(as <> "+" <> ck <> "+" <> method <> "+" <> query <> "+" <> body <> "+" <> "#{ts}")
    [
      {'X-Ovh-Application', '#{ak}'},
      {'X-Ovh-Timestamp', '#{ts}'},
      {'X-Ovh-Signature', '#{sig}'},
      {'X-Ovh-Consumer', '#{ck}'}
    ]
  end

  def hash(s) do
    s
    |> (&(:crypto.hash(:sha, &1))).()
    |> Base.encode16(case: :lower)
  end

  defp baseurl, do: @endpoints[Confex.get_env(:ovh, :endpoint)]

  def delta_time() do
    case Application.fetch_env(:ovh, :delta_time) do
      :error -> do_delta_time()
      {:ok, delta} -> delta
    end
  end

  defp do_delta_time do
    url = Path.join baseurl(), "/auth/time"
    with {:ok, {{_, 200, _}, _, body}} <- :httpc.request('#{url}'),
         {ovh_time, _} <- Integer.parse("#{body}") do
      delta = ovh_time - :os.system_time(:seconds)
      Logger.debug("Fetch OVH time: #{ovh_time} (delta: #{delta})")
      Application.put_env(:ovh, :delta_time, delta)
      delta
    else
      _ -> raise "Can not get OVH time"
    end
  end
end