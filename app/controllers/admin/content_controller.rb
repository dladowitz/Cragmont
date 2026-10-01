class Admin::ContentController < Admin::BaseController
  def index
    authorize ContentPage, :index?
  end
end
