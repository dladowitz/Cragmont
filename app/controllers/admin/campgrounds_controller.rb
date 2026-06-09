class Admin::CampgroundsController < Admin::BaseController
  before_action :set_campground, only: %i[show edit update destroy]

  def index
    authorize Campground
    @campgrounds = Campground.order(:name)
  end

  def show
    authorize @campground
    @campsites = @campground.campsites.includes(:trip).order(:arrival_date, :site_number)
  end

  def new
    @campground = Campground.new
    authorize @campground
  end

  def edit
    authorize @campground
  end

  def create
    @campground = Campground.new(campground_params)
    authorize @campground

    if @campground.save
      redirect_to admin_campground_path(@campground), notice: "Campground was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @campground

    if @campground.update(campground_params)
      redirect_to admin_campground_path(@campground), notice: "Campground was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @campground

    if @campground.destroy
      redirect_to admin_campgrounds_path, notice: "Campground was deleted.", status: :see_other
    else
      redirect_to admin_campground_path(@campground),
        alert: "Campground cannot be deleted while campsites are assigned to it.",
        status: :see_other
    end
  end

  private

  def set_campground
    @campground = Campground.find(params[:id])
  end

  def campground_params
    params.require(:campground).permit(:name, :location, :website, :notes)
  end
end
