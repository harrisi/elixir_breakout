import Config

config :logger,
       :default_formatter,
       format: {Breakout.Logger, :format},
       handle_otp_reports: true,
       handle_sasl_reports: true,
       # format: "$time [$level] $message\n\t$metadata\n",
       metadata: [
         :error_code,
         :mfa,
         :line,
         :pid,
         :registered_name,
         :process_label,
         :crash_reason,
         :msg
       ]
