class Admin::SiteContentController < Admin::BaseController
  CONTENT_FIELDS = {
    "liability_warning" => {
      attribute: :liability_warning,
      title: "Liability Warning",
      description: "This appears on public pages and in email footers.",
      markdown: false
    },
    "day_trip_safety_reminder" => {
      attribute: :day_trip_safety_reminder,
      title: "Day Trip Safety Reminder",
      description: "This appears on day trip pages. Markdown formatting is supported.",
      markdown: true
    }
  }.freeze

  before_action :set_content_field
  before_action :set_site_setting

  def edit
    authorize @site_setting, :update?
  end

  def update
    authorize @site_setting

    if @site_setting.update(site_setting_params)
      redirect_to edit_admin_site_content_path(@content_key), notice: "On belay! #{@content_config.fetch(:title)} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_content_field
    @content_key = params[:key]
    @content_config = CONTENT_FIELDS.fetch(@content_key) { raise ActiveRecord::RecordNotFound, "Unknown content field: #{@content_key}" }
    @content_attribute = @content_config.fetch(:attribute)
  end

  def set_site_setting
    @site_setting = SiteSetting.current
  end

  def site_setting_params
    params.require(:site_setting).permit(@content_attribute)
  end
end
