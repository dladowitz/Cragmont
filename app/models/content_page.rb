class ContentPage < ApplicationRecord
  WHAT_TO_EXPECT_BODY = <<~MARKDOWN.strip
    **Cragmont trips are a shared base camp, not a guided trip.**

    The goal is to bring climbers together and give them space to camp, exchange beta, cook, prep, and socialize with other climbers.

    We secure campsites so there is space for that to happen. In the mornings and evenings, participants often gather around tables and campfires to share what they plan to climb or what they climbed that day.

    This is a great space to ask about routes to help plan your adventures for the weekend. Often you'll hear about epics you may want to avoid (or repeat depending on your appetite!)

    ## Do I need a partner to come on a trip?

    You do not need a partner to show up, but you will generally want one so you can get out climbing.

    Most climbers come on trips with climbing partners already lined up. Occasionally, you may find someone at camp who is also looking for a partner, though it can be hard to know whether they have the same climbing goals, skills, and risk tolerance.

    If you do not have a partner lined up, join our [WhatsApp Community](https://chat.whatsapp.com/DngyoeuFkg61oCZXPyyAgX?mode=gi_t) and look for a partner for the weekend. You can also [sign up for our email list](https://www.cragmontclimbingclub.org/join-the-list) and send a message to the group.

    ## Will Cragmont teach me to climb outside?

    No. Cragmont does not provide formal instruction, and we do not test members on their climbing skills or teaching ability. Every participant brings a different mix of experience, judgment, and skills, which may or may not be what you need.

    ## Can I learn climbing skills from people on trips?

    Maybe. Many people you meet on trips have deep knowledge of climbing systems and are often happy to share what they know with newer and experienced climbers alike.

    That said, it is up to you to decide whom to listen to and whom to climb with. It takes time to know whether someone is giving you sound climbing information when it comes to how to set up anchors, place gear, or evaluate a system.

    One of the best ways to build that judgment is to take a class from a professional guiding company. Once you learn the basics, you will be better equipped to decide whom to trust when receiving new climbing information.

    ## Do climbing parties climb together or separate on trips?

    Both happen. Some parties have specific multi-pitch goals that do not lend themselves well to larger groups, so they head out separately during the day and come back to camp to share stories.

    Other days, multiple parties decide to go to the same single-pitch cragging wall. In those instances, people may put up a few ropes and share anchors and routes. When this happens it's organic and not planned by the club.

    You are responsible for deciding whether you trust the person who set up an anchor or rope. Ask questions, make sure you understand the setup, and decide whether you have enough knowledge to vet their skills. Remember that you are trusting your life to the gear and systems you choose to use.

    ## Do I need to be a club member to join a trip?

    Nope. Trips are open to everyone, and signups are first come, first served. Club members only get priority for parking spots at a site and for moving off the waitlist if a trip is full.

    ## Do I need to be a climber to join a trip?

    Nope. Sometimes climbers come on trips and decide to take it easy for the weekend. They might hike, spend time at the river, or simply hang out with friends who are climbing.

    Often climbers come with friends who are not climbers so spend time with them instead of climbing.

    As long as you are friendly and like the outdoors, you are welcome.

    ## Do you know any professional climbing companies I can take classes from?

    Here are a few companies our members have taken classes with and recommend:

    - [Vertical Pursuits](https://www.verticalpursuitsclimbing.com/) (based around Lake Tahoe)
    - [Lovers Leap Guides](https://loversleap.net/) (based around South Lake Tahoe)

    We do not have firsthand knowledge of this company, but they are local to the Bay Area so may be worth checking out:

    - [SANNO Adventures](https://www.saanoadventures.com/)

    ## I have more questions

    We would love to hear from you. Send us a message on our [Get Help](/help) page.
  MARKDOWN

  DEFAULT_PAGES = {
    "what_to_expect" => {
      title: "What to expect on a Cragmont trip",
      subtitle: "A quick topo for your first outing with the club.",
      body: WHAT_TO_EXPECT_BODY
    }
  }.freeze

  validates :slug, presence: true, uniqueness: true
  validates :title, :body, presence: true

  def self.current!(slug)
    default_attributes = DEFAULT_PAGES.fetch(slug) { raise ActiveRecord::RecordNotFound, "Unknown content page: #{slug}" }

    find_or_create_by!(slug: slug) do |page|
      page.title = default_attributes.fetch(:title)
      page.subtitle = default_attributes.fetch(:subtitle)
      page.body = default_attributes.fetch(:body)
    end
  end
end
