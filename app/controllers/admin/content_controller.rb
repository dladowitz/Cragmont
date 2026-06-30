class Admin::ContentController < Admin::BaseController
  def index
    authorize ContentPage, :edit?
  end
end
