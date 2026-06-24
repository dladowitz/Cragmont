class TripDetailsEmailTemplate < ApplicationRecord
  YOSEMITE_SUBJECT = "CCC {{trip_dates_short}}: Yosemite {{campgrounds}}".freeze
  YOSEMITE_BODY = <<~MARKDOWN.strip
    Hey everyone,

    If you are getting this, you signed up for the Cragmont Trip to **Yosemite** this week.
    I'm looking forward to seeing all of you!

    Here is some information about the trip listed in priority order. Read through the **Safety** section otherwise you might have trouble getting to the campsite.

    ---

    ## Campsite Assignments & Check-In (READ THIS)

    **Copy down your site assignment as well as the Registration info**.
    Cell service is spotty on the way to the park as well as in the park.

    Double check the Trip page for the final Campsite assignments. They may change until a day before the trip.
    **Trip page:** [{{trip_page_url}}]({{trip_page_url}})

    --





    **Campsite Registration Info**

    {{campsite_registration_info}}

    --

    **If you are arriving BEFORE 5pm**

    The camp hosts are usually at the campsite gate until 5pm.
    To check in you'll need to provide the following to the camp host:

    1. Site number
    2. Name of person who registered the site
    3. Reservation number
    4. Photo of the registering person's ID

    It's not great for privacy, but unfortunately this is the system Yosemite Campgrounds require.
    In a separate email you'll get a copy of the photo ID of the person who registered for your site.
    The person checking in will also get two parking passes.

    **If you are arriving AFTER 5pm**

    No one will be at the campsite gate.
    The camp hosts will leave a sign-in sheet at the gate.
    The first party arriving will need to fill it out to indicate you've arrived.

    You'll need:

    1. Site number
    2. Name of person who registered the site
    3. Reservation number

    Technically the hosts want someone to come check in between 10am and 4pm the next day.
    Make sure to bring the site owner's photo ID if you check-in in person.

    These hours are not convenient for folks hiking and climbing. The camp hosts know this.
    It's ok if no one checks-in in person. You might get a note on your site about this.
    It's safe to disregard as long as:

    1. One party checks in after hours
    2. You have visible signs of occupying the campsite (tents or equipment)

    This will prevent the camp host from giving away your site.

    ---

    ## Parking (READ THIS)

    Double check the Trip page for the final Parking assignments.
    **Trip page:** [{{trip_page_url}}]({{trip_page_url}})

    If your name says **Reserved Parking** you have a dedicated parking spot at the site.
    If your name says **Open Spot** you can take one of the first come first serve spots. Usually there is one per site.
    If your name says **Overflow Lot** don't park at the campsite except for loading.

    Each site has two parking spots. **Do not park more than 2 cars at a site overnight**.
    We've had camp hosts wake people up to move a car.
    If you are at the campsite during the day and prepared to move a car if asked it's fine to have extra cars temporarily.
    Just don't block the road.

    **Overflow Lots:**
    For Upper Pines sites there is an overflow lot nearby used at the Yosemite Valley Trailhead you can park in.
    Parking on the road between the campground and Curry Village has worked well in past years.
    For Hodgdon Meadow there are a number of small parking areas spread around the campsite.

    ---

    ## Safety (READ THIS)

    Remember you are responsible for your own safety out there.
    As a club Cragmont offers no instruction or education. It's a social base camp.

    Many members have a deep well of knowledge and are willing to share. We encourage you to learn from each other.
    However no one is authorized to share official guidance or teachings on behalf of the club.

    The club has no tests and does not objectively verify anyone's knowledge or experience. **Being a Cragmont member does not mean a member has any specific skills.** They may or may not know how to build an anchor properly. Or belay, rappel, place protection or any other climbing skill. **It is solely up to you to decide if you should trust the skills, advice, or thoughts of other climbers.**

    Cragmont is simply an organization that helps bring together like minded climbers in outdoor settings.
    Make sure you are properly trained on aspects of outdoor climbing before fully trusting someone you don't know.

    ---

    ## (OK you can stop reading if you want)

    Here is some general information about the campsites and park.
    If you are a regular you probably know this stuff already.

    ---

    ## Communication

    There is a WhatsApp Group created for this specific trip.
    Sign up to communicate with everyone:
    [WhatsApp Trip Link]({{whatsapp_group_url}})

    If you don't have WhatsApp you can text the Campsite Coordinator here:
    **{{coordinator_name}}:** {{coordinator_phone}}

    ---

    ## Campfire

    Campfires are currently **Allowed** in the campgrounds between 5pm and 10pm.

    {{group_campfire_info}}

    Come on by to hang out and share stories about your climbing adventures.
    This is a great time to learn from others about what they know about the park.

    **[Campground Regulations](https://www.nps.gov/yose/planyourvisit/campregs.htm) and [Fire Restrictions](https://www.nps.gov/yose/planyourvisit/firerestrictions.htm)**

    ---

    ## Access to the Park

    For 2026 there are no reservations needed to get into Yosemite.
    However you do need to pay a [Park Entrance Fee](https://www.nps.gov/yose/planyourvisit/fees.htm) (or have a pass):

    - $35 good for 7 days
    - $70 for a Yosemite Annual Pass
    - $80 for a National Parks Annual Pass

    Each of these covers everyone entering in the same vehicle.

    Note that the entrance gates are staffed roughly from 8am to 5pm.
    If you enter AND exit outside of those times you generally won't have to pay as there is no one to collect fees.

    **[Non-Residents](https://www.nps.gov/aboutus/nonresident-fees.htm):** Sadly the federal government recently made updates requiring each non-resident to pay $100 in addition to the vehicle entry fee. Alternatively a non resident can buy an annual park pass for $250.

    That said, in the past gate staff has not asked for ID from anyone other than a person paying for vehicle entry (or presenting an annual park pass for entry).
    It's unlikely they would know or ask if anyone else in the car is a non-resident and then ask to pay the additional fee.
    Of course this could change at any time. Best to be prepared to pay the increased fee if asked.

    [How a "resident" is defined by the parks service](https://www.nps.gov/aboutus/nonresident-fees.htm): "A visitor will need to show proof of U.S. citizenship or residency. Acceptable documents include a U.S. Passport, U.S. government (state or territory)-issued driver's license or state ID, or Permanent Resident card ("green card")."

    ---

    ## Food

    All food must be stored in the Bear Bins at the campsites. Do not store food in your cars.

    If your campsite is full please be mindful of how many coolers and food boxes you are packing.
    The Bear Bins are shared between people at your campsite.
    If there are 6 people at your campsite, the Bear Bin will fill up pretty quick.

    ---

    ## Weather

    Trip weather link: [{{weather_url}}]({{weather_url}})

    ---

    ## Cell Phone & WIFI

    Reception is very hit or miss in Yosemite. If you need reception you'll generally be able to drive around and find some, though it might be very slow.
    You *might* get WIFI access at one of the valley hotels.
    If you drive out of the park your first best bet for WIFI is the [Rush Creek Lodge](https://maps.app.goo.gl/ZkTR97zEpxNsCCry6)

    ---

    ## Traffic & Crag Parking Lots

    Some weekends are busier than others.
    If the park is very busy you'll want to plan your entrance and movement throughout the park ahead of time to avoid frustration.

    - There may be lines getting into the park between 8am and 11am.
    - The crag parking lots can fill up during the day.
    - It's best to park at a crag by 8am. Then don't plan to drive to another crag until 4pm.

    ---

    **Alright, let's go climbing! (Or whatever you're doing.)**

    - **{{coordinator_name}}**
  MARKDOWN

  DEFAULT_TEMPLATES = [
    {
      name: "Yosemite",
      area_key: "yosemite",
      subject_template: YOSEMITE_SUBJECT,
      body_markdown: YOSEMITE_BODY,
      active: true
    }
  ].freeze

  scope :active, -> { where(active: true) }

  validates :name, :area_key, :subject_template, :body_markdown, presence: true
  validates :name, uniqueness: { scope: :area_key }

  def self.ensure_defaults!
    DEFAULT_TEMPLATES.each do |attributes|
      find_or_create_by!(name: attributes.fetch(:name), area_key: attributes.fetch(:area_key)) do |template|
        template.assign_attributes(attributes)
      end
    end
  end

  def build_trip_details_email(trip)
    trip.build_trip_details_email(
      trip_details_email_template: self,
      subject: subject_template,
      body_markdown: body_markdown
    )
  end
end
