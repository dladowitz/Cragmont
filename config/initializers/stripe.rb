if defined?(Stripe)
  stripe_api_version = ENV.fetch("STRIPE_API_VERSION", "2026-05-27.dahlia")
  stripe_secret_key = ENV["STRIPE_SECRET_KEY"].presence
  stripe_publishable_key = ENV["STRIPE_PUBLISHABLE_KEY"].presence
  stripe_webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"].presence

  if Rails.env.production?
    missing = []
    missing << "STRIPE_SECRET_KEY" if stripe_secret_key.blank?
    missing << "STRIPE_PUBLISHABLE_KEY" if stripe_publishable_key.blank?
    missing << "STRIPE_WEBHOOK_SECRET" if stripe_webhook_secret.blank?

    raise "Missing Stripe configuration: #{missing.to_sentence}" if missing.any?
  elsif stripe_secret_key&.start_with?("sk_live")
    raise "Stripe live secret keys are only allowed in production"
  end

  Stripe.api_version = stripe_api_version
  Stripe.api_key = stripe_secret_key if stripe_secret_key.present?
end
