class Admin::SettingsController < Admin::BaseController
  def show
    @site_setting = SiteSetting.current
  end

  def update
    @site_setting = SiteSetting.current

    if @site_setting.update(site_setting_params)
      redirect_to admin_settings_path, notice: "Settings were updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def site_setting_params
    params.require(:site_setting).permit(
      :uncounted_minor_age_limit,
      :first_two_nights_fee,
      :extra_night_fee,
      :minor_fee,
      :minor_extra_night_fee
    )
  end
end
