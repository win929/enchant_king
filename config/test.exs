import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :enchant_king, EnchantKingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "uuhtGLh9Ij7NDEugVSPlS56XSuqA/5OuiBxDTuyrMU/C5m6/e6USh6/B1Ds2CEL0",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
