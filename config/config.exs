use Mix.Config


config :stream_data, :initial_size, 1
config :stream_data, :max_runs, 100
config :stream_data, :max_shrinking_steps, 100


import_config "#{Mix.env}.exs"
