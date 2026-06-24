class Admin::TripDetailsEmailTemplatesController < Admin::BaseController
  before_action :ensure_default_templates
  before_action :set_template, only: %i[edit update]

  def index
    authorize TripDetailsEmailTemplate
    @templates = TripDetailsEmailTemplate.order(:area_key, :name)
  end

  def edit
    authorize @template
  end

  def update
    authorize @template

    if @template.update(template_params)
      redirect_to edit_admin_trip_details_email_template_path(@template), notice: "On belay! Trip details email template was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def preview
    authorize TripDetailsEmailTemplate

    render html: helpers.render_trip_details_email_markdown(params[:body])
  end

  private

  def ensure_default_templates
    TripDetailsEmailTemplate.ensure_defaults!
  end

  def set_template
    @template = TripDetailsEmailTemplate.find(params[:id])
  end

  def template_params
    params.require(:trip_details_email_template).permit(:name, :subject_template, :body_markdown, :active)
  end
end
