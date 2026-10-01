Rails.application.config.session_store :cookie_store,
  key: "_cragmont_session",
  expire_after: 4.months,
  same_site: :lax,
  secure: Rails.env.production?
