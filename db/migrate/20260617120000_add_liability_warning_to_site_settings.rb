class AddLiabilityWarningToSiteSettings < ActiveRecord::Migration[8.0]
  DEFAULT_LIABILITY_WARNING = "Cragmont is not a teaching organization. It's a social base camp. We create shared spaces to connect with other climbers. We hope you'll exchange knowledge and learn from one another. However, Cragmont does not test or vet members. It's up to you to decide what knowledge is correct and what might lead to danger. If you are new to climbing, the best way to help with these decisions is to take classes from professional guides."

  def change
    add_column :site_settings, :liability_warning, :text, null: false, default: DEFAULT_LIABILITY_WARNING
  end
end
