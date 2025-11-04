class Account::Seeder
  attr_reader :account, :creator

  def initialize(account, creator)
    @account = account
    @creator = creator
  end

  def seed
    Current.set session: session do
      populate
    end
  end

  def seed!
    raise "You can't run in production environments" unless Rails.env.local?

    delete_everything
    seed
  end

  private
    def session
      creator.identity.sessions.last
    end

    def populate
      # ---------------
      # Playground Collection
      # ---------------
      playground = Collection.create! name: "Playground", creator: creator, all_access: true

      # Cards
      playground.cards.create! creator: creator, title: "Watch this: Fizzy orientation video", status: "published", description: <<~HTML
        <p>There’s a whole lot more you can do in Fizzy. In the video below 37signals founder and CEO, Jason Fried, will walk you through the basics in just 8 minutes.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/videos/fizzyorientation-4k.mp4" caption="Fizzy orientation" content-type="video/mp4" filename="fizzyorientation-4k.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Grab the invite link to invite someone else", status: "published", description: <<~HTML
        <p>Open Fizzy menu, select “<b><strong>+ Add people</b></strong>”, then copy the invite link. You can give this link to someone else so they can make an login for themselves in your account.</p>
      HTML

      playground.cards.create! creator: creator, title: "Head back home to check out activity", status: "published", description: <<~HTML
        <p>Hit “1” or pull down the BOXCAR menu and select “Home”.</p>
      HTML

      playground.cards.create! creator: creator, title: "Check out all cards assigned to you", status: "published", description: <<~HTML
        <p>Pull down the Fizzy menu at the top of the screen, and select “<b><strong>Assigned to me</b></strong>” or just hit “3” on your keyboard any time.</p>
      HTML

      playground.cards.create! creator: creator, title: "Open the Fizzy menu", status: "published", description: <<~HTML
        <p>The Fizzy menu is how you get around the app. Click “<b><strong>Fizzy</b></strong>” at the top of the screen or hit the “J” key on your keyboard to pop it open.</p>
      HTML

      playground.cards.create! creator: creator, title: "Assign this card to yourself", status: "published", description: <<~HTML
        <p>Click the little head with the + next to it, pick yourself.</p>
      HTML

      playground.cards.create! creator: creator, title: "Tag this card “Design” then move it to YES", status: "published", description: <<~HTML
        <p>Click the little Tag icon, type “design”, then “<b><strong>Create tag</b></strong>”. Then, move the card to the new “YES” column you created in the previous step.</p>
      HTML

      playground.cards.create! creator: creator, title: "Make two more columns", status: "published", description: <<~HTML
        <ol>
          <li>Make one called "Yes"</li>
          <li>Make another called "Working on"</li>
        </ol>
        <p><br></p>
        <p>Go back to the Board view, click the little “+” to the right of the DONE column, name the column, pick a color, then do it again.</p>
        <p><br></p>
        <p>After that, drag this card to “DONE” or select “DONE” in the sidebar.</p>
      HTML

      playground.cards.create! creator: creator, title: "Move this card to NOT NOW", status: "published", description: <<~HTML
        <p>You can either select “NOT NOW” over in the sidebar, or you can go back out to the board view and drag this card into the “NOT NOW” column on the left side.</p>
      HTML

      playground.cards.create! creator: creator, title: "Rename this card", status: "published", description: <<~HTML
        <ol>
          <li>Click the title and you can rename the card, change the description, or add more information to the card.</li>
          <li>Then, hit "Mark as Done" at the bottom of the card.</li>
          <li>Finally, hit “<b><strong>←Playground</strong></b>” in the top left of the screen to go back to the board.</li>
        </ol>
      HTML
    end

    def delete_everything
      Current.set session: session do
        Collection.destroy_all
      end
    end
end
