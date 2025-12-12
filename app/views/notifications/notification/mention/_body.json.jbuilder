mention = notification.source

json.title "#{mention.mentioner.first_name} @mentioned you"
json.body mention.source.mentionable_content.truncate(200)
