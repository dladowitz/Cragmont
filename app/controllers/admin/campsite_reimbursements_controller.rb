require "csv"

class Admin::CampsiteReimbursementsController < Admin::BaseController
  REIMBURSEMENT_FILTERS = %w[unreimbursed reimbursed all].freeze

  def index
    @selected_reimbursement_filters = selected_reimbursement_filters

    campsites = Campsite
      .joins(:trip, :campground)
      .where(trips: { trip_type: "camping", deleted_at: nil })
    campsites = filter_campsites(campsites)

    ordered_campsites = campsites
      .includes(
        :campground,
        :registered_by,
        :registration_reimbursed_by,
        :registration_reimbursement_recorded_by,
        trip: :campsite_coordinator
      )
      .order("trips.start_date ASC", "trips.name ASC", "campgrounds.name ASC", "campsites.site_number ASC")

    respond_to do |format|
      format.html do
        @campsites_by_trip = ordered_campsites.group_by(&:trip)
        @users = User.order(:first_name, :last_name)
      end
      format.csv do
        send_data campsite_reimbursements_csv(ordered_campsites),
          filename: "campsite-reimbursements-#{Date.current.iso8601}.csv",
          type: "text/csv; charset=utf-8"
      end
    end
  end

  private

  def selected_reimbursement_filters
    return [ "unreimbursed" ] if params[:filters].blank?

    selected = Array(params[:reimbursement_status]).select { |status| status.in?(REIMBURSEMENT_FILTERS) }
    selected.presence || [ "unreimbursed" ]
  end

  def filter_campsites(campsites)
    return campsites if @selected_reimbursement_filters.include?("all")

    conditions = []
    if @selected_reimbursement_filters.include?("unreimbursed")
      conditions << "(campsites.registration_fee_cents > 0 AND campsites.registration_reimbursed_at IS NULL)"
    end
    if @selected_reimbursement_filters.include?("reimbursed")
      conditions << "campsites.registration_reimbursed_at IS NOT NULL"
    end

    campsites.where(conditions.join(" OR "))
  end

  def campsite_reimbursements_csv(campsites)
    CSV.generate(headers: true) do |csv|
      csv << [
        "Trip",
        "Trip Start",
        "Trip End",
        "Campground",
        "Site Number",
        "Registered by",
        "Fees paid",
        "Reimbursed",
        "Reimbursed On"
      ]

      campsites.each do |campsite|
        csv << [
          campsite.trip.name,
          campsite.trip.start_date.iso8601,
          campsite.trip.end_date.iso8601,
          campsite.campground.name,
          campsite.site_number,
          campsite.registered_by&.full_name || "None",
          format("%.2f", campsite.registration_fee_cents.to_i / 100.0),
          campsite.registration_reimbursed? ? "Yes" : "No",
          campsite.registration_reimbursed_at&.to_date&.iso8601
        ]
      end
    end
  end
end
