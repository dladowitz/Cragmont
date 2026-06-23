require "uri"

class TripReadinessChecklist
  Category = Struct.new(:key, :name, :tasks, keyword_init: true) do
    def completed_count
      tasks.count(&:complete?)
    end

    def total_count
      tasks.size
    end
  end

  Task = Struct.new(:key, :name, :kind, :complete, :source_complete, :detail, :detail_link_url, :completion, :update_label, :update_campsite, keyword_init: true) do
    def automatic?
      kind == :automatic
    end

    def manual?
      kind == :manual
    end

    def complete?
      complete
    end

    def source_complete?
      source_complete
    end

    def overrideable?
      automatic? && TripReadinessChecklist.overridable_task_key?(key)
    end
  end

  OVERRIDABLE_AUTOMATIC_TASKS = {
    campsite_coordinator_assigned: "Add Coordinator",
    whatsapp_group_created: "Add Group",
    weather_link_added: "Add Weather",
    create_google_photo_album: "Add Album"
  }.freeze
  CAMPSITE_TASK_KEY_PATTERN = /\Acampsite_(\d+)_(registered_by|registration_number|registration_cost)\z/

  MANUAL_TASKS = {
    add_photo_album_to_older_website: "Add photo album to older website",
    send_trip_details_email: "Send out trip details email with check-in info",
    send_collected_money_to_treasurer: "Send collected money to Treasurer",
    send_photo_upload_reminder: "Send reminder to participants to upload photos to album"
  }.freeze

  def self.manual_task_keys
    MANUAL_TASKS.keys.map(&:to_s)
  end

  def self.overridable_automatic_task_keys
    OVERRIDABLE_AUTOMATIC_TASKS.keys.map(&:to_s)
  end

  def self.completable_task_keys
    manual_task_keys + overridable_automatic_task_keys
  end

  def self.manual_task_key?(task_key)
    manual_task_keys.include?(task_key.to_s)
  end

  def self.completable_task_key?(task_key, trip: nil)
    task_key = task_key.to_s
    return true if completable_task_keys.include?(task_key)
    return true if trip.present? && campsite_task_key_for_trip?(task_key, trip)

    false
  end

  def self.overridable_task_key?(task_key)
    overridable_automatic_task_keys.include?(task_key.to_s) || campsite_task_key?(task_key)
  end

  def self.campsite_task_key?(task_key)
    task_key.to_s.match?(CAMPSITE_TASK_KEY_PATTERN)
  end

  def self.campsite_task_key_for_trip?(task_key, trip)
    campsite_id = task_key.to_s.match(CAMPSITE_TASK_KEY_PATTERN)&.[](1)
    campsite_id.present? && trip.campsites.exists?(id: campsite_id)
  end

  def initialize(trip)
    @trip = trip
    @completions_by_key = trip.trip_readiness_completions.index_by(&:task_key)
  end

  def categories
    @categories ||= [
      Category.new(key: "trip", name: "Trip", tasks: trip_tasks),
      Category.new(key: "campsites", name: "Campsites", tasks: campsite_tasks),
      Category.new(key: "participant", name: "Participant", tasks: participant_tasks),
      Category.new(key: "post_trip", name: "Post Trip", tasks: post_trip_tasks)
    ]
  end

  def completed_count
    categories.sum(&:completed_count)
  end

  def total_count
    categories.sum(&:total_count)
  end

  private

  attr_reader :trip, :completions_by_key

  def trip_tasks
    whatsapp_group_url = safe_http_url(trip.whatsapp_group)
    weather_url = safe_http_url(trip.weather_url)
    photo_album_url = safe_http_url(trip.photo_album_url)

    [
      automatic_task(
        :campsite_coordinator_assigned,
        "Campsite Coordinator assigned",
        trip.campsite_coordinator.present?,
        update_label: OVERRIDABLE_AUTOMATIC_TASKS.fetch(:campsite_coordinator_assigned),
        complete_detail: coordinator_detail,
        incomplete_detail: "Assign a campsite coordinator before heading out."
      ),
      automatic_task(
        :whatsapp_group_created,
        "WhatsApp Group created and added to trip",
        whatsapp_group_url.present?,
        update_label: OVERRIDABLE_AUTOMATIC_TASKS.fetch(:whatsapp_group_created),
        complete_detail: "WhatsApp group link is ready.",
        incomplete_detail: "Add a WhatsApp group URL on the trip edit page.",
        detail_link_url: whatsapp_group_url
      ),
      automatic_task(
        :weather_link_added,
        "Weather link added to group",
        weather_url.present?,
        update_label: OVERRIDABLE_AUTOMATIC_TASKS.fetch(:weather_link_added),
        complete_detail: "Weather link is ready.",
        incomplete_detail: "Add a weather URL on the trip edit page.",
        detail_link_url: weather_url
      ),
      automatic_task(
        :create_google_photo_album,
        "Create Google Photo Album",
        photo_album_url.present?,
        update_label: OVERRIDABLE_AUTOMATIC_TASKS.fetch(:create_google_photo_album),
        complete_detail: "Photo album link is ready.",
        incomplete_detail: "Add a Google Photo Album URL on the trip edit page.",
        detail_link_url: photo_album_url
      ),
      manual_task(:add_photo_album_to_older_website, MANUAL_TASKS.fetch(:add_photo_album_to_older_website))
    ]
  end

  def participant_tasks
    [
      automatic_task(
        :all_confirmed_participants_signed_waiver,
        "All confirmed participants signed waiver",
        confirmed_participants_ready?(&:waiver_signed?),
        complete_detail: "Every confirmed participant has signed a waiver.",
        incomplete_detail: missing_confirmed_participants_detail(:waiver_signed?, "waiver")
      ),
      automatic_task(
        :all_confirmed_primary_participants_paid_or_waived,
        "All confirmed primary participants paid or have fees waived",
        confirmed_primary_participants_ready?(&:payment_paid_or_settled?),
        complete_detail: "Every confirmed primary participant is paid, manual-paid, or waived.",
        incomplete_detail: missing_confirmed_primary_participants_detail(:payment_paid_or_settled?, "payment")
      ),
      automatic_task(
        :all_confirmed_participants_assigned_parking,
        "All confirmed participants assigned parking",
        confirmed_participants_ready? { |signup| !signup.unassigned? },
        complete_detail: "Every confirmed participant has a parking status.",
        incomplete_detail: missing_confirmed_participants_detail(->(signup) { !signup.unassigned? }, "parking")
      ),
      manual_task(
        :send_trip_details_email,
        MANUAL_TASKS.fetch(:send_trip_details_email),
        "Include campsite number, campsite registration number, the person who registered the site, and that person's photo ID details."
      )
    ]
  end

  def campsite_tasks
    return [ no_campsites_task ] if campsites.empty?

    campsites.flat_map do |campsite|
      [
        campsite_task(
          campsite,
          :registered_by,
          "Registered By",
          campsite.registered_by.present?,
          update_label: "Add Registered By",
          complete_detail: "#{campsite_name(campsite)} has a registrant.",
          incomplete_detail: "#{campsite_name(campsite)} still needs a registrant."
        ),
        campsite_task(
          campsite,
          :registration_number,
          "Registration Number",
          campsite.registration_number.present?,
          update_label: "Add Registration Number",
          complete_detail: "#{campsite_name(campsite)} has a registration number.",
          incomplete_detail: "#{campsite_name(campsite)} still needs a registration number."
        ),
        campsite_task(
          campsite,
          :registration_cost,
          "Registration Cost",
          campsite.registration_fee_cents.positive?,
          update_label: "Add Registration Cost",
          complete_detail: "#{campsite_name(campsite)} has a registration cost.",
          incomplete_detail: "#{campsite_name(campsite)} still needs a registration cost."
        )
      ]
    end
  end

  def post_trip_tasks
    [
      manual_task(:send_collected_money_to_treasurer, MANUAL_TASKS.fetch(:send_collected_money_to_treasurer)),
      manual_task(:send_photo_upload_reminder, MANUAL_TASKS.fetch(:send_photo_upload_reminder))
    ]
  end

  def automatic_task(key, name, source_complete, update_label: nil, update_campsite: nil, complete_detail:, incomplete_detail:, detail_link_url: nil)
    completion = completions_by_key[key.to_s]
    Task.new(
      key: key.to_s,
      name: name,
      kind: :automatic,
      complete: source_complete || completion.present?,
      source_complete: source_complete,
      detail: source_complete ? complete_detail : incomplete_detail,
      detail_link_url: (detail_link_url if source_complete),
      completion: completion,
      update_label: update_label,
      update_campsite: update_campsite
    )
  end

  def campsite_task(campsite, key_suffix, name, source_complete, update_label:, complete_detail:, incomplete_detail:)
    automatic_task(
      "campsite_#{campsite.id}_#{key_suffix}",
      "#{campsite_name(campsite)}: #{name}",
      source_complete,
      update_label: update_label,
      update_campsite: campsite,
      complete_detail: complete_detail,
      incomplete_detail: incomplete_detail
    )
  end

  def no_campsites_task
    automatic_task(
      :campsites_added,
      "Campsites added",
      false,
      complete_detail: "Campsites have been added.",
      incomplete_detail: "No campsites have been added yet."
    )
  end

  def manual_task(key, name, detail = nil)
    completion = completions_by_key[key.to_s]
    Task.new(
      key: key.to_s,
      name: name,
      kind: :manual,
      complete: completion.present?,
      source_complete: false,
      detail: detail,
      detail_link_url: nil,
      completion: completion,
      update_label: nil,
      update_campsite: nil
    )
  end

  def confirmed_participants
    @confirmed_participants ||= trip.campsite_signups.confirmed.includes(:waiver, :user, :campsite_signup_minors).to_a
  end

  def confirmed_primary_participants
    @confirmed_primary_participants ||= trip.campsite_signups.confirmed.primary.includes(:payments, :user).to_a
  end

  def confirmed_participants_ready?(&block)
    confirmed_participants.any? && confirmed_participants.all?(&block)
  end

  def confirmed_primary_participants_ready?(&block)
    confirmed_primary_participants.any? && confirmed_primary_participants.all?(&block)
  end

  def campsites
    @campsites ||= trip.campsites.includes(:campground, :registered_by).order(:arrival_date, :site_number).to_a
  end

  def missing_confirmed_participants_detail(predicate, label)
    return "No confirmed participants yet." if confirmed_participants.empty?

    missing_names = missing_signup_names(confirmed_participants, predicate)
    return "Every confirmed participant has #{label} handled." if missing_names.empty?

    "Still needs #{label}: #{missing_names.to_sentence}."
  end

  def missing_confirmed_primary_participants_detail(predicate, label)
    return "No confirmed primary participants yet." if confirmed_primary_participants.empty?

    missing_names = missing_signup_names(confirmed_primary_participants, predicate)
    return "Every confirmed primary participant has #{label} handled." if missing_names.empty?

    "Still needs #{label}: #{missing_names.to_sentence}."
  end

  def missing_signup_names(signups, predicate)
    signups.reject { |signup| predicate_matches?(predicate, signup) }.map { |signup| signup.user.full_name }
  end

  def predicate_matches?(predicate, signup)
    if predicate.respond_to?(:call)
      predicate.call(signup)
    else
      signup.public_send(predicate)
    end
  end

  def coordinator_detail
    return "Campsite coordinator is #{trip.campsite_coordinator.full_name}." if trip.campsite_coordinator.present?

    "Assign a campsite coordinator before heading out."
  end

  def campsite_name(campsite)
    "#{campsite.campground.name} site #{campsite.site_number}"
  end

  def safe_http_url(url)
    uri = URI.parse(url.to_s)
    return unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
