# Uxie Marketplace functionality
# David "Mesp" Loewen

require_relative 'db.rb'

def get_marketplace_dir(id)
	return "/listingdb"
end

def get_listing_filename(id, offering, lvl)
	return "#{id}#{offering.downcase}+#{lvl}.listing"
end

def card_valid?(card)
	return @card_stats["#{card.capitalize}"] >= 0
end
@bot.command(:create_listing, description: "Create a listing for a marble. Level will be 0 if no level number provided.", usage: "!create_listing [offering] [level(0-10)] [asking]", min_args: 3, channels: ["test-channel", "marketplace-commands"]) do |event, offering, level, *asking|
	id = event.message.author.id
	db = opendb

	return "Don't use + or * symbols to set level. Instead, use the level parameter. E.g. `!create_listing Tumult 5 A Nice Cup of Hot Chocolate` to list a Tumult*." if (offering.include?('*') || offering.include?('+'))
	return "Unknown card #{offering}." unless card_valid?(offering)
	# special case if lvl not included
	unless (level =~ /\d/) == 0
		asking.unshift(level)
		level = "0"
	end
	rows = db.execute("SELECT * FROM listings WHERE offering=\"#{offering.downcase}\" AND seller=\"#{id}\" AND card_level=#{level.to_i}")
	unless rows.empty?
    event.respond "#{event.message.author.name}, you already have a listing up for #{offering} lvl #{level}!" 
  else
		db.execute("INSERT INTO listings (seller, offering, card_level, asking) VALUES (?, ?, ?, ?)", [id, offering.downcase, level, asking.join(" ")])
		event.respond "Listing created for #{offering}."
  end
end

@bot.command(:update_listing, description: "Update your listing for a marble, changing what you want for it.", usage: "!update_listing [offering] [level(0-10)] [asking]", min_args: 3, channels: ["test-channel", "marketplace-commands"], aliases: [:edit_listing]) do |event, offering, level, *asking|
  id = event.message.author.id
	db = opendb

	return "Unknown card #{offering}." unless card_valid?(offering)
	# special case if lvl not included
	unless (level =~ /\d/) == 0
		asking.unshift(level)
		level = "0"
	end
	rows = db.execute("SELECT * FROM listings WHERE offering=\"#{offering.downcase}\" AND seller=\"#{id}\" AND card_level=#{level.to_i}")
	if rows.empty?
		event.respond "#{event.message.author.name}, you don't have a listing up for #{offering} lvl #{level}!"
	else
		db.execute("UPDATE listings SET asking=\"#{asking.join(" ")}\" WHERE offering=\"#{offering.downcase}\" AND seller=\"#{id}\" AND card_level=#{level.to_i}")
		event.respond "Listing edited for #{offering}."
	end
end

@bot.command(:display_listing, description: "display your own listing for a marble", usage: "!display_listing [offering] [level(0-10)]", min_args: 2, channels: ["test-channel", "marketplace-commands"]) do |event, offering, level|
  id = event.message.author.id
	db = opendb

	return "Unknown card #{offering}." unless card_valid?(offering)
	rows = db.execute("SELECT * FROM listings WHERE seller=\"#{id}\" AND offering=\"#{offering.downcase}\" AND card_level=#{level}")

  if rows.empty?
		event.respond "#{event.message.author.name}, you don't have a listing up for #{offering} at level #{level}!"
	else
		event.respond "<@#{event.message.author.id}>'s listing:\n```\nOffering: #{offering}\nAsking for: #{rows[0][2]}\n```"
	end
end

@bot.command(:delete_listing, description: "remove your own listing from the listing database", usage: "!delete_listing [offering] [level(0-10)]", min_args: 2, channels: ["test-channel", "marketplace-commands"], aliases: [:remove_listing, :destroy_listing]) do |event, offering, level|
  id = event.message.author.id
	db = opendb
	return "Unknown card #{offering}." unless card_valid?(offering)
	rows = db.execute("SELECT * FROM listings WHERE seller=\"#{id}\" AND offering=\"#{offering.downcase}\" AND card_level=#{level}")

	if rows.empty?
		event.respond "#{event.message.author.name}, you don't have a listing up for #{offering} at level #{level}!"
	else
		rows = db.execute("DELETE FROM listings WHERE seller=\"#{id}\" AND offering=\"#{offering.downcase}\" AND card_level=#{level}")
		event.respond "Listing deleted."
	end
end

@bot.command(:search, description: "Search for a specific marble in the listing database", usage: "!search [wanting]", min_args: 1, channels: ["test-channel", "marketplace-commands"], aliases: [:search_listing, :search_listings]) do |event, wanting|
	id = event.message.author.id
	db = opendb
	return "Unknown card #{wanting}." unless card_valid?(wanting)

	rows = db.execute("SELECT * FROM listings WHERE offering=\"#{wanting.downcase}\"")
	if rows.empty?
		event.respond "No matches found for #{wanting}."
	else
		description = ""
		rows.each do |match|
			seller_id = match[0]
			seller_level = match[3]
			seller_asking = match[2]
			description << "<@#{seller_id}>: **(LEVEL #{seller_level})**\n**Wants:** #{seller_asking}\n"
		end
		event.send_embed do |embed|
			embed.title = "The following users are offering #{wanting}:"
			embed.colour = 15183055 # Pink Pearl
			embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://www.pinclipart.com/picdir/big/523-5232872_magnifying-glass-clipart.png')
			embed.description = description
		end
	end
end

@bot.command(:search_seller, description: "Search for all listings by a particular seller in the listing database", usage: "!search_seller [user id]", min_args: 1, channels: ["test-channel", "marketplace-commands"], aliases: [:search_user]) do |event, wanting|
	id = event.message.author.id
	db = opendb
	rows = db.execute("SELECT * FROM listings WHERE seller=\"#{wanting}\"")
	if rows.empty?
		event.respond "User id##{wanting} does not have any listings."
	else
		description = ""
		rows.each do |match|
			marble_name = match[1]
			marble_level = match[3]
			marble_asking = match[2]
			description << "**#{marble_name}**: (LEVEL #{marble_level})\n**Wants:** #{marble_asking}\n"
		end
		event.send_embed do |embed|
			embed.colour = 15183055 # Pink Pearl
			embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new(url: 'https://www.pinclipart.com/picdir/big/523-5232872_magnifying-glass-clipart.png')
			embed.description = "<@#{wanting}> **has the following listings:**\n\n" + description
		end
	end
end
