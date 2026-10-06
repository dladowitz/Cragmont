class ResourcesController < ApplicationController
  before_action :require_resource_login, except: %i[index show]
  before_action :set_resource, only: %i[edit update destroy]

  def index
    @category = params[:category]
    @resources = Resource.where(category: @category).includes(:user).newest_first
  end

  def show
    @resource = Resource.includes(:user).find_by!(id: params[:id], category: params[:category], kind: "article")
  end

  def new
    @resource = current_user.resources.build(kind: "link", category: params[:category].presence_in(Resource::CATEGORIES.keys))
    authorize @resource
  end

  def create
    @resource = current_user.resources.build(resource_params)
    authorize @resource

    if @resource.save
      redirect_to resource_category_path(@resource.category), notice: "On belay! Your resource is up."
    else
      flash.now[:alert] = "Whipper! A few fields need another look."
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @resource.update(resource_params)
      redirect_to resource_category_path(@resource.category), notice: "On belay! Your changes are up."
    else
      flash.now[:alert] = "Whipper! A few fields need another look."
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @resource.destroy!
    redirect_to resource_category_path(@resource.category), notice: "Resource deleted.", status: :see_other
  end

  private

  def require_resource_login
    return if user_signed_in?

    return_to = request.get? ? request.fullpath : new_resource_path
    redirect_to new_session_path(return_to: return_to), alert: "Tie in first: log in to submit a resource."
  end

  def set_resource
    @resource = Resource.find(params[:id])
    authorize @resource
  end

  def resource_params
    params.require(:resource).permit(:category, :kind, :title, :url, :body)
  end
end
