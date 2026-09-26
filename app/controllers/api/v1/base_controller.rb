class Api::V1::BaseController < Admin::BaseController
  rescue_from ActionController::InvalidAuthenticityToken do
    render json: { error: "Use the CSRF token from the signed-in admin page" }, status: :unprocessable_entity
  end

  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: "Not found" }, status: :not_found
  end

  rescue_from ActionController::BadRequest do |error|
    render json: { error: error.message }, status: :bad_request
  end

  private

  def permitted_payload(key, *attributes)
    input = params.require(key)
    raise ActionController::BadRequest, "#{key} must be an object" unless input.is_a?(ActionController::Parameters)

    permitted = input.permit(*attributes)
    unknown = input.keys - permitted.keys
    raise ActionController::BadRequest, "Unsupported #{key} fields: #{unknown.join(', ')}" if unknown.any?

    permitted
  end

  def validation_error(record)
    render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
  end
end
