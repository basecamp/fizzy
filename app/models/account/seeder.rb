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
      # Playground Board
      # ---------------
      playground = Board.create! name: "Playground", creator: creator, all_access: true

      # Cards
      playground.cards.create! creator: creator, title: "Finally, watch this Fizzy orientation video", status: "published", description: <<~HTML
        <p>There’s a whole lot more you can do in Fizzy. In the video below 37signals founder and CEO, Jason Fried, will walk you through the basics in just 8 minutes.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/videos/fizzyorientation-4k.mp4" caption="Fizzy orientation" content-type="video/mp4" filename="fizzyorientation-4k.mp4"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Now, grab the invite link to invite someone else", status: "published", description: <<~HTML
        <p>Open Fizzy menu, select “<b><strong>+ Add people</b></strong>”, then copy the invite link. You can give this link to someone else so they can make an login for themselves in your account.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/invite-link.gif" alt="Demo of copying invite link" caption="Get a link to invite co-workers" content-type="image/*" filename="invite-link.gif" presentation="gallery"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Then, head back home to check out activity", status: "published", description: <<~HTML
        <p>Hit “1” or pull down the Fizzy menu and select “Home”.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/back-to-home.gif" alt="Demo of visiting Home" caption="Go back to Home for Latest Activity" content-type="image/*" filename="back-to-home.gif" presentation="gallery"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Now,check out all cards assigned to you", status: "published", description: <<~HTML
        <p>Pull down the Fizzy menu at the top of the screen, and select “<b><strong>Assigned to me</b></strong>” or just hit “3” on your keyboard any time.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/all-assigned.gif" alt="Demo of navigating to 'Assigned to Me'" caption="See all cards assigned to me" content-type="image/*" filename="all-assigned.gif" presentation="gallery"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Then, open the Fizzy menu", status: "published", description: <<~HTML
        <p>The Fizzy menu is how you get around the app. Click “<b><strong>Fizzy</b></strong>” at the top of the screen or hit the “J” key on your keyboard to pop it open.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/open-menu.gif" alt="Demo of opening the main menu" caption="Open the Fizzy menu" content-type="image/*" filename="open-menu.gif" presentation="gallery"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Next, assign this card to yourself", status: "published", description: <<~HTML
        <p>Click the little head with the + next to it, pick yourself.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/assign-to-self.gif" alt="Demo of assigning a card" caption="Assign this to yourself" content-type="image/*" filename="assign-to-self.gif" presentation="gallery"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Now, tag this card “Design” then move it to YES", status: "published", description: <<~HTML
        <p>Click the little Tag icon, type “design”, then “<b><strong>Create tag</b></strong>”. Then, move the card to the new “YES” column you created in the previous step.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/tag-design.gif" alt="Demo of tagging a card" caption="Tag this #design" content-type="image/*" filename="tag-design.gif" presentation="gallery"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Next, make two more columns", status: "published", description: <<~HTML
        <ol>
          <li>Make one called "Yes"</li>
          <li>Make another called "Working on"</li>
        </ol>
        <p><br></p>
        <p>Go back to the Board view, click the little “+” to the right of the DONE column, name the column, pick a color, then do it again.</p>
        <p><br></p>
        <p>After that, drag this card to “DONE” or select “DONE” in the sidebar.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/make-columns.gif" alt="Demo of adding columns" caption="Make two more columns" content-type="image/*" filename="make-columns.gif" presentation="gallery"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "Second, move this card to NOT NOW", status: "published", description: <<~HTML
        <p>You can either select “NOT NOW” over in the sidebar, or you can go back out to the board view and drag this card into the “NOT NOW” column on the left side.</p>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/not-now.gif" alt="Demo of moving a card to Not Now" caption="Move to Not Now" content-type="image/*" filename="not-now.gif" presentation="gallery"></action-text-attachment>
      HTML

      playground.cards.create! creator: creator, title: "First, rename this card", status: "published", description: <<~HTML
        <ol>
          <li>Click the title and you can rename the card, change the description, or add more information to the card.</li>
          <li>Then, hit "Mark as Done" at the bottom of the card.</li>
          <li>Finally, hit “<b><strong>←Playground</strong></b>” in the top left of the screen to go back to the board.</li>
        </ol>
        <p><br></p>
        <action-text-attachment url="https://videos.37signals.com/fizzy/assets/images/rename.gif" alt="Demo of renaming a card" caption="Rename this card" content-type="image/*" filename="rename.gif" presentation="gallery"></action-text-attachment>
      HTML
    end

    def delete_everything
      Current.set session: session do
        Board.destroy_all
      end
    end
end
