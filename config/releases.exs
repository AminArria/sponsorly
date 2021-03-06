# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

database_url =
  System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :sponsorly, Sponsorly.Repo,
  ssl: true,
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :sponsorly, SponsorlyWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base


bamboo_adapter =
  if System.get_env("USE_LOCAL_ADAPTER") == "true" do
    Bamboo.LocalAdapter
  else
    Bamboo.PostmarkAdapter
  end

postmark_api_key =
  if bamboo_adapter == Bamboo.PostmarkAdapter do
    System.get_env("POSTMARK_API_KEY") ||
      raise """
      Postmark API key is missing.
      """
  end

# Bamboo Postmark adapter config
config :sponsorly, SponsorlyWeb.Mailer,
  adapter: bamboo_adapter,
  api_key: postmark_api_key

config :sponsorly, SponsorlyWeb.Endpoint, server: true
