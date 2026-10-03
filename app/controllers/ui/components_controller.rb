class Ui::ComponentsController < ApplicationController
  def index
    raise ActionController::RoutingError, "Not Found" unless Rails.env.development? || Rails.env.test?
  end
end
